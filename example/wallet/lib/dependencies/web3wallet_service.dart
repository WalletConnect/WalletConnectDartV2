import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/bottom_sheet/i_bottom_sheet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/chain_services/evm_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/deep_link_handler.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/i_web3wallet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/chain_key.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/i_key_service.dart';
import 'package:walletconnect_flutter_v2_wallet/models/chain_data.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/dart_defines.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/eth_utils.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/methods_utils.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_connection_request/wc_connection_request_widget.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_request_widget.dart/wc_request_widget.dart';
import 'package:walletconnect_flutter_v2_wallet/widgets/wc_request_widget.dart/wc_session_auth_request_widget.dart';

class Web3WalletService extends IWeb3WalletService {
  final _bottomSheetHandler = GetIt.I<IBottomSheetService>();
  Web3Wallet? _web3Wallet;

  String get _flavor {
    String flavor = '-${const String.fromEnvironment('FLUTTER_APP_FLAVOR')}';
    return flavor.replaceAll('-production', '');
  }

  String _universalLink() {
    Uri link = Uri.parse('https://lab.web3modal.com/flutter_walletkit');
    if (_flavor.isNotEmpty) {
      return link
          .replace(path: '${link.path}_internal')
          .replace(host: 'dev.${link.host}')
          .toString();
    }
    return link.toString();
  }

  Redirect _constructRedirect() {
    return Redirect(
      native: 'wcflutterwallet$_flavor://',
      universal: _universalLink(),
      // enable linkMode on Wallet so Dapps can use relay-less connection
      // universal: value must be set on cloud config as well
      linkMode: true,
    );
  }

  @override
  Future<void> create() async {
    // Create the web3wallet
    _web3Wallet = Web3Wallet(
      core: Core(
        projectId: DartDefines.projectId,
        logLevel: LogLevel.error,
      ),
      metadata: PairingMetadata(
        name: 'Flutter Wallet Sample',
        description: 'WalletConnect\'s sample wallet with Flutter',
        url: _universalLink(),
        icons: [
          'https://docs.walletconnect.com/assets/images/web3walletLogo-54d3b546146931ceaf47a3500868a73a.png'
        ],
        redirect: _constructRedirect(),
      ),
    );

    _web3Wallet!.core.addLogListener(_logListener);

    // Setup our listeners
    debugPrint('[SampleWallet] create');
    _web3Wallet!.core.pairing.onPairingInvalid.subscribe(_onPairingInvalid);
    _web3Wallet!.core.pairing.onPairingCreate.subscribe(_onPairingCreate);
    _web3Wallet!.core.relayClient.onRelayClientError.subscribe(
      _onRelayClientError,
    );
    _web3Wallet!.core.relayClient.onRelayClientMessage.subscribe(
      _onRelayClientMessage,
    );

    _web3Wallet!.onSessionProposal.subscribe(_onSessionProposal);
    _web3Wallet!.onSessionProposalError.subscribe(_onSessionProposalError);
    _web3Wallet!.onSessionConnect.subscribe(_onSessionConnect);
    _web3Wallet!.onSessionAuthRequest.subscribe(_onSessionAuthRequest);

    _web3Wallet!.onAuthRequest.subscribe(_onAuthRequest);

    // Setup our accounts
    List<ChainKey> chainKeys = await GetIt.I<IKeyService>().loadKeys();
    if (chainKeys.isEmpty) {
      await GetIt.I<IKeyService>().loadDefaultWallet();
      chainKeys = await GetIt.I<IKeyService>().loadKeys();
    }
    for (final chainKey in chainKeys) {
      for (final chainId in chainKey.chains) {
        if (chainId.startsWith('kadena')) {
          final account = '$chainId:k**${chainKey.address}';
          debugPrint('[SampleWallet] registerAccount $account');
          _web3Wallet!.registerAccount(
            chainId: chainId,
            accountAddress: 'k**${chainKey.address}',
          );
        } else {
          final account = '$chainId:${chainKey.address}';
          debugPrint('[SampleWallet] registerAccount $account');
          _web3Wallet!.registerAccount(
            chainId: chainId,
            accountAddress: chainKey.address,
          );
        }
      }
    }
  }

  @override
  Future<void> init() async {
    // Await the initialization of the web3wallet
    await _web3Wallet!.init();
    await _emitEvent();
  }

  Future<void> _emitEvent() async {
    if (!_web3Wallet!.core.connectivity.isOnline.value) {
      await Future.delayed(const Duration(milliseconds: 500));
      _emitEvent();
      return;
    }

    final sessions = _web3Wallet!.sessions.getAll();
    for (var session in sessions) {
      try {
        final events = NamespaceUtils.getNamespacesEventsForChain(
          chainId: 'eip155:1',
          namespaces: session.namespaces,
        );
        if (events.contains('accountsChanged')) {
          final chainKeys = GetIt.I<IKeyService>().getKeysForChain('eip155');
          _web3Wallet!.emitSessionEvent(
            topic: session.topic,
            chainId: 'eip155:1',
            event: SessionEventParams(
              name: 'accountsChanged',
              data: [chainKeys.first.address],
            ),
          );
        }
      } catch (_) {}
    }
    _web3Wallet!.core.connectivity.isOnline.addListener(() {
      if (_web3Wallet!.core.connectivity.isOnline.value) {
        final sessions = _web3Wallet!.sessions.getAll();
        final chainKeys = GetIt.I<IKeyService>().getKeysForChain('eip155');
        for (var session in sessions) {
          try {
            final chainIds = NamespaceUtils.getChainIdsFromNamespaces(
              namespaces: session.namespaces,
            );
            _web3Wallet!.emitSessionEvent(
              topic: session.topic,
              chainId: chainIds.first,
              event: SessionEventParams(
                name: 'accountsChanged',
                data: ['${chainIds.first}:${chainKeys.first.address}'],
              ),
            );
          } catch (_) {}
        }
      }
    });
  }

  void _logListener(LogEvent event) {
    if (event.level == Level.debug) {
      // TODO send to mixpanel
      log('${event.message}');
    } else {
      debugPrint('${event.message}');
    }
  }

  @override
  FutureOr onDispose() {
    _web3Wallet!.core.removeLogListener(_logListener);
    _web3Wallet!.core.pairing.onPairingInvalid.unsubscribe(_onPairingInvalid);
    _web3Wallet!.core.pairing.onPairingCreate.unsubscribe(_onPairingCreate);
    _web3Wallet!.core.relayClient.onRelayClientError.unsubscribe(
      _onRelayClientError,
    );
    _web3Wallet!.core.relayClient.onRelayClientMessage.unsubscribe(
      _onRelayClientMessage,
    );

    _web3Wallet!.onSessionProposal.unsubscribe(_onSessionProposal);
    _web3Wallet!.onSessionProposalError.unsubscribe(_onSessionProposalError);
    _web3Wallet!.onSessionConnect.unsubscribe(_onSessionConnect);
    _web3Wallet!.onSessionAuthRequest.unsubscribe(_onSessionAuthRequest);

    _web3Wallet!.onAuthRequest.unsubscribe(_onAuthRequest);
  }

  @override
  Web3Wallet get web3wallet => _web3Wallet!;

  List<String> get _loaderMethods => [
        MethodConstants.WC_SESSION_PROPOSE,
        MethodConstants.WC_SESSION_REQUEST,
        MethodConstants.WC_SESSION_AUTHENTICATE,
      ];

  void _onRelayClientMessage(MessageEvent? event) async {
    if (event != null) {
      final jsonObject = await EthUtils.decodeMessageEvent(event);
      debugPrint('[SampleWallet] _onRelayClientMessage $jsonObject');
      if (jsonObject is JsonRpcRequest) {
        DeepLinkHandler.waiting.value = _loaderMethods.contains(
          jsonObject.method,
        );
      }
    }
  }

  void _onSessionProposal(SessionProposalEvent? args) async {
    debugPrint('[SampleWallet] _onSessionProposal ${jsonEncode(args?.params)}');
    if (args != null) {
      final proposer = args.params.proposer;
      final result = (await _bottomSheetHandler.queueBottomSheet(
            widget: WCRequestWidget(
              verifyContext: args.verifyContext,
              child: WCConnectionRequestWidget(
                proposalData: args.params,
                verifyContext: args.verifyContext,
                requester: proposer,
              ),
            ),
          )) ??
          WCBottomSheetResult.reject;

      if (result != WCBottomSheetResult.reject) {
        // generatedNamespaces is constructed based on registered methods handlers
        // so if you want to handle requests using onSessionRequest event then you would need to manually add that method in the approved namespaces
        try {
          final session = await _web3Wallet!.approveSession(
            id: args.id,
            namespaces: NamespaceUtils.regenerateNamespacesWithChains(
              args.params.generatedNamespaces!,
            ),
            sessionProperties: args.params.sessionProperties,
          );
          MethodsUtils.handleRedirect(
            session.topic,
            session.session!.peer.metadata.redirect,
          );
        } on WalletConnectError catch (error) {
          MethodsUtils.handleRedirect(
            '',
            proposer.metadata.redirect,
            error.message,
          );
        }
      } else {
        final error = Errors.getSdkError(Errors.USER_REJECTED);
        await _web3Wallet!.rejectSession(id: args.id, reason: error);
        await _web3Wallet!.core.pairing.disconnect(
          topic: args.params.pairingTopic,
        );
        MethodsUtils.handleRedirect(
          '',
          proposer.metadata.redirect,
          error.message,
        );
      }
    }
  }

  void _onSessionProposalError(SessionProposalErrorEvent? args) async {
    debugPrint('[SampleWallet] _onSessionProposalError $args');
    DeepLinkHandler.waiting.value = false;
    if (args != null) {
      String errorMessage = args.error.message;
      if (args.error.code == 5100) {
        errorMessage =
            errorMessage.replaceFirst('Requested:', '\n\nRequested:');
        errorMessage =
            errorMessage.replaceFirst('Supported:', '\n\nSupported:');
      }
      MethodsUtils.goBackModal(
        title: 'Error',
        message: errorMessage,
        success: false,
      );
    }
  }

  void _onSessionConnect(SessionConnect? args) {
    if (args != null) {
      final session = jsonEncode(args.session.toJson());
      debugPrint('[SampleWallet] _onSessionConnect $session');
    }
  }

  void _onRelayClientError(ErrorEvent? args) {
    debugPrint('[SampleWallet] _onRelayClientError ${args?.error}');
  }

  void _onPairingInvalid(PairingInvalidEvent? args) {
    debugPrint('[SampleWallet] _onPairingInvalid $args');
  }

  void _onPairingCreate(PairingEvent? args) {
    debugPrint('[SampleWallet] _onPairingCreate $args');
  }

  void _onSessionAuthRequest(SessionAuthRequest? args) async {
    if (args != null) {
      final SessionAuthPayload authPayload = args.authPayload;
      final jsonPyaload = jsonEncode(authPayload.toJson());
      debugPrint('[SampleWallet] _onSessionAuthRequest $jsonPyaload');
      final supportedChains = ChainData.eip155Chains.map((e) => e.chainId);
      final supportedMethods = SupportedEVMMethods.values.map((e) => e.name);
      final newAuthPayload = AuthSignature.populateAuthPayload(
        authPayload: authPayload,
        chains: supportedChains.toList(),
        methods: supportedMethods.toList(),
      );
      final cacaoRequestPayload = CacaoRequestPayload.fromSessionAuthPayload(
        newAuthPayload,
      );
      final List<Map<String, dynamic>> formattedMessages = [];
      for (var chain in newAuthPayload.chains) {
        final chainKeys = GetIt.I<IKeyService>().getKeysForChain(chain);
        final iss = 'did:pkh:$chain:${chainKeys.first.address}';
        final message = _web3Wallet!.formatAuthMessage(
          iss: iss,
          cacaoPayload: cacaoRequestPayload,
        );
        formattedMessages.add({iss: message});
      }

      final WCBottomSheetResult rs =
          (await _bottomSheetHandler.queueBottomSheet(
                widget: WCSessionAuthRequestWidget(
                  child: WCConnectionRequestWidget(
                    sessionAuthPayload: newAuthPayload,
                    verifyContext: args.verifyContext,
                    requester: args.requester,
                  ),
                ),
              )) ??
              WCBottomSheetResult.reject;

      if (rs != WCBottomSheetResult.reject) {
        final chainKeys = GetIt.I<IKeyService>().getKeysForChain('eip155');
        final privateKey = '0x${chainKeys.first.privateKey}';
        final credentials = EthPrivateKey.fromHex(privateKey);
        //
        final messageToSign = formattedMessages.length;
        final count = (rs == WCBottomSheetResult.one) ? 1 : messageToSign;
        //
        final List<Cacao> cacaos = [];
        for (var i = 0; i < count; i++) {
          final iss = formattedMessages[i].keys.first;
          final message = formattedMessages[i].values.first;
          final signature = credentials.signPersonalMessageToUint8List(
            Uint8List.fromList(message.codeUnits),
          );
          final hexSignature = bytesToHex(signature, include0x: true);
          cacaos.add(
            AuthSignature.buildAuthObject(
              requestPayload: cacaoRequestPayload,
              signature: CacaoSignature(
                t: CacaoSignature.EIP191,
                s: hexSignature,
              ),
              iss: iss,
            ),
          );
        }
        //
        try {
          final session = await _web3Wallet!.approveSessionAuthenticate(
            id: args.id,
            auths: cacaos,
          );
          MethodsUtils.handleRedirect(
            session.topic,
            session.session?.peer.metadata.redirect,
          );
        } on WalletConnectError catch (error) {
          MethodsUtils.handleRedirect(
            args.topic,
            args.requester.metadata.redirect,
            error.message,
          );
        }
      } else {
        final error = Errors.getSdkError(Errors.USER_REJECTED_AUTH);
        await _web3Wallet!.rejectSessionAuthenticate(
          id: args.id,
          reason: error,
        );
        MethodsUtils.handleRedirect(
          args.topic,
          args.requester.metadata.redirect,
          error.message,
        );
      }
    }
  }

  Future<void> _onAuthRequest(AuthRequest? args) async {
    if (args != null) {
      debugPrint('[SampleWallet] _onAuthRequest $args');
      final WCBottomSheetResult rs =
          (await _bottomSheetHandler.queueBottomSheet(
                widget: WCRequestWidget(
                  child: WCConnectionRequestWidget(
                    authPayloadParams: args.payloadParams,
                    requester: args.requester,
                  ),
                ),
              )) ??
              WCBottomSheetResult.reject;

      const chain = 'eip155:1';
      final chainKeys = GetIt.I<IKeyService>().getKeysForChain(chain);
      final privateKey = '0x${chainKeys[0].privateKey}';
      final credentials = EthPrivateKey.fromHex(privateKey);
      final iss = 'did:pkh:$chain:${credentials.address.hex}';

      if (rs != WCBottomSheetResult.reject) {
        //
        final message = _web3Wallet!.formatAuthMessage(
          iss: iss,
          cacaoPayload: CacaoRequestPayload.fromPayloadParams(
            args.payloadParams,
          ),
        );

        final signature = credentials.signPersonalMessageToUint8List(
          Uint8List.fromList(message.codeUnits),
        );
        final hexSignature = bytesToHex(signature, include0x: true);

        try {
          await _web3Wallet!.respondAuthRequest(
            id: args.id,
            iss: iss,
            signature: CacaoSignature(
              t: CacaoSignature.EIP191,
              s: hexSignature,
            ),
          );
          MethodsUtils.handleRedirect(
            args.topic,
            args.requester.metadata.redirect,
          );
        } on WalletConnectError catch (error) {
          MethodsUtils.handleRedirect(
            args.topic,
            args.requester.metadata.redirect,
            error.message,
          );
        }
      } else {
        final error = Errors.getSdkError(Errors.USER_REJECTED_AUTH);
        await _web3Wallet!.respondAuthRequest(
          id: args.id,
          iss: iss,
          error: error,
        );
        MethodsUtils.handleRedirect(
          args.topic,
          args.requester.metadata.redirect,
          error.message,
        );
      }
    }
  }
}

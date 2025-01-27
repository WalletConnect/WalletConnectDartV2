// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:fl_toast/fl_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:walletconnect_flutter_v2_dapp/models/chain_metadata.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/constants.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/bitcoin.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/chain_data.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/eip155.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/polkadot.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/solana.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/sample_wallets.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/string_constants.dart';
import 'package:walletconnect_flutter_v2_dapp/widgets/chain_button.dart';
import 'package:walletconnect_flutter_v2_dapp/imports.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({
    super.key,
    required this.web3App,
  });

  final Web3App web3App;

  @override
  ConnectPageState createState() => ConnectPageState();
}

class ConnectPageState extends State<ConnectPage> {
  bool _testnetOnly = false;
  final List<ChainMetadata> _selectedChains = [];
  bool _shouldDismissQrCode = true;
  bool _initialized = false;
  late IWalletConnectModalService _walletConnectModalService;

  @override
  void initState() {
    super.initState();
    _initializeWCM();
  }

  Future<void> _initializeWCM() async {
    _walletConnectModalService = WalletConnectModalService(
      web3App: widget.web3App,
    );

    await _walletConnectModalService.init();

    setState(() => _initialized = true);

    widget.web3App.onSessionConnect.subscribe(_onSessionConnect);
  }

  @override
  void dispose() {
    widget.web3App.onSessionConnect.unsubscribe(_onSessionConnect);
    super.dispose();
  }

  void _selectChain(ChainMetadata chain) {
    setState(() {
      if (_selectedChains.contains(chain)) {
        _selectedChains.remove(chain);
      } else {
        _selectedChains.add(chain);
      }
      _updateNamespaces();
    });
  }

  Map<String, RequiredNamespace> requiredNamespaces = {};
  Map<String, RequiredNamespace> optionalNamespaces = {};

  void _updateNamespaces() {
    optionalNamespaces = {};

    final evmChains =
        _selectedChains.where((e) => e.type == ChainType.eip155).toList();
    if (evmChains.isNotEmpty) {
      optionalNamespaces['eip155'] = RequiredNamespace(
        chains: evmChains.map((c) => c.chainId).toList(),
        methods: EIP155.methods.values.toList(),
        events: EIP155.events.values.toList(),
      );
    }

    final btcChains =
        _selectedChains.where((e) => e.type == ChainType.bip122).toList();
    if (btcChains.isNotEmpty) {
      optionalNamespaces['bip122'] = RequiredNamespace(
        chains: btcChains.map((c) => c.chainId).toList(),
        methods: Bitcoin.methods.values.toList(),
        events: Bitcoin.events.values.toList(),
      );
    }

    final solanaChains =
        _selectedChains.where((e) => e.type == ChainType.solana).toList();
    if (solanaChains.isNotEmpty) {
      optionalNamespaces['solana'] = RequiredNamespace(
        chains: solanaChains.map((c) => c.chainId).toList(),
        methods: Solana.methods.values.toList(),
        events: Solana.events.values.toList(),
      );
    }

    final polkadotChains =
        _selectedChains.where((e) => e.type == ChainType.polkadot).toList();
    if (polkadotChains.isNotEmpty) {
      optionalNamespaces['polkadot'] = RequiredNamespace(
        chains: polkadotChains.map((c) => c.chainId).toList(),
        methods: Polkadot.methods.values.toList(),
        events: Polkadot.events.values.toList(),
      );
    }

    if (optionalNamespaces.isEmpty) {
      requiredNamespaces = {};
    } else {
      // WalletConnectModal still requires to have requiredNamespaces
      // this has to be changed in that SDK
      requiredNamespaces = {
        'eip155': const RequiredNamespace(
          chains: ['eip155:1'],
          methods: ['personal_sign', 'eth_signTransaction'],
          events: ['chainChanged'],
        ),
      };
    }

    _walletConnectModalService.setRequiredNamespaces(
      requiredNamespaces: requiredNamespaces,
    );
    debugPrint(
        '[SampleDapp] requiredNamespaces ${jsonEncode(requiredNamespaces)}');
    _walletConnectModalService.setOptionalNamespaces(
      optionalNamespaces: optionalNamespaces,
    );
    debugPrint(
        '[SampleDapp] optionalNamespaces ${jsonEncode(optionalNamespaces)}');
  }

  @override
  Widget build(BuildContext context) {
    // Build the list of chain buttons, clear if the textnet changed
    final testChains = ChainData.allChains.where((e) => e.isTestnet).toList();
    final mainChains = ChainData.allChains.where((e) => !e.isTestnet).toList();
    final List<ChainMetadata> chains = _testnetOnly ? testChains : mainChains;

    final List<Widget> evmChainButtons = [];
    final List<Widget> nonEvmChainButtons = [];

    final evmChains = chains.where((e) => e.type == ChainType.eip155);
    final nonEvmChains = chains.where((e) => e.type != ChainType.eip155);

    for (final ChainMetadata chain in evmChains) {
      // Build the button
      evmChainButtons.add(
        ChainButton(
          chain: chain,
          onPressed: () => _selectChain(chain),
          selected: _selectedChains.contains(chain),
        ),
      );
    }

    for (final ChainMetadata chain in nonEvmChains) {
      // Build the button
      nonEvmChainButtons.add(
        ChainButton(
          chain: chain,
          onPressed: () => _selectChain(chain),
          selected: _selectedChains.contains(chain),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: StyleConstants.linear8),
      children: <Widget>[
        const Text(
          'Flutter Dapp',
          style: StyleConstants.subtitleText,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: StyleConstants.linear8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              StringConstants.testnetsOnly,
              style: StyleConstants.buttonText,
            ),
            Switch(
              value: _testnetOnly,
              onChanged: (value) {
                setState(() {
                  _selectedChains.clear();
                  _testnetOnly = value;
                });
              },
            ),
          ],
        ),
        const Text('EVM Chains:', style: StyleConstants.buttonText),
        const SizedBox(height: StyleConstants.linear8),
        Wrap(
          spacing: 10.0,
          children: evmChainButtons,
        ),
        const Divider(),
        const Text('Non EVM Chains:', style: StyleConstants.buttonText),
        Wrap(
          spacing: 10.0,
          children: nonEvmChainButtons,
        ),
        const Divider(),
        if (_initialized)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: StyleConstants.linear8),
              const Text(
                'Use WalletConnectModal:',
                style: StyleConstants.buttonText,
              ),
              const SizedBox(height: StyleConstants.linear8),
              WalletConnectModalConnect(
                service: _walletConnectModalService,
                width: double.infinity,
                height: 50.0,
              ),
            ],
          ),
        const SizedBox(height: StyleConstants.linear8),
        const Divider(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: StyleConstants.linear8),
            const Text(
              'Connect Session Propose:',
              style: StyleConstants.buttonText,
            ),
            const SizedBox(height: StyleConstants.linear8),
            Column(
              children: WCSampleWallets.getSampleWallets().map((wallet) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    style: _buttonStyle,
                    onPressed: _selectedChains.isEmpty
                        ? null
                        : () {
                            _onConnect(
                              nativeLink: '${wallet['schema']}',
                              closeModal: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.of(context).pop();
                                }
                              },
                              showToast: (m) async {
                                showPlatformToast(
                                  child: Text(m),
                                  context: context,
                                );
                              },
                            );
                          },
                    child: Text(
                      '${wallet['name']}',
                      style: StyleConstants.buttonText,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: StyleConstants.linear8),
            const Divider(),
            const Text(
              '1-Click Auth with LinkMode:',
              style: StyleConstants.buttonText,
            ),
            const SizedBox(height: StyleConstants.linear8),
            Column(
              children: WCSampleWallets.getSampleWallets().map((wallet) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    style: _buttonStyle,
                    onPressed: _selectedChains.isEmpty
                        ? null
                        : () {
                            _sessionAuthenticate(
                              nativeLink: '${wallet['schema']}',
                              universalLink: '${wallet['universal']}',
                              closeModal: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.of(context).pop();
                                }
                              },
                              showToast: (message) {
                                showPlatformToast(
                                  child: Text(message),
                                  context: context,
                                );
                              },
                            );
                          },
                    child: Text(
                      '${wallet['name']}',
                      style: StyleConstants.buttonText,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: StyleConstants.linear16),
        const Divider(height: 1.0),
        const SizedBox(height: StyleConstants.linear16),
        const Text(
          'Redirect:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Native: '),
            Expanded(
              child: Text(
                '${widget.web3App.metadata.redirect?.native}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Universal: '),
            Expanded(
              child: Text(
                '${widget.web3App.metadata.redirect?.universal}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Link Mode: '),
            Text(
              '${widget.web3App.metadata.redirect?.linkMode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: StyleConstants.linear8),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final v = snapshot.data!.version;
            final b = snapshot.data!.buildNumber;
            const f = String.fromEnvironment('FLUTTER_APP_FLAVOR');
            // return Text('App Version: $v-$f ($b) - SDK v$packageVersion');
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App Version: '),
                Expanded(
                  child: Text(
                    '$v-$f ($b) - SDK v$packageVersion',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: StyleConstants.linear16),
      ],
    );
  }

  Future<void> _onConnect({
    required String nativeLink,
    VoidCallback? closeModal,
    Function(String message)? showToast,
  }) async {
    debugPrint('[SampleDapp] Creating connection with $nativeLink');
    // It is currently safer to send chains approvals on optionalNamespaces
    // but depending on Wallet implementation you may need to send some (for innstance eip155:1) as required
    final connectResponse = await widget.web3App.connect(
      requiredNamespaces: requiredNamespaces,
      optionalNamespaces: optionalNamespaces,
    );

    try {
      final encodedUri = Uri.encodeComponent(connectResponse.uri.toString());
      final uri = '$nativeLink?uri=$encodedUri';
      await WalletConnectUtils.openURL(uri);
    } catch (e) {
      _showQrCode(connectResponse.uri.toString());
    }

    debugPrint('[SampleDapp] Awaiting session proposal settlement');
    try {
      await connectResponse.session.future;
      showToast?.call(StringConstants.connectionEstablished);
    } on JsonRpcError catch (e) {
      showToast?.call(e.message.toString());
    }
    closeModal?.call();
  }

  void _sessionAuthenticate({
    required String nativeLink,
    required String universalLink,
    VoidCallback? closeModal,
    Function(String message)? showToast,
  }) async {
    debugPrint(
        '[SampleDapp] Creating authenticate with $nativeLink, $universalLink');
    final methods1 = requiredNamespaces['eip155']?.methods ?? [];
    final methods2 = optionalNamespaces['eip155']?.methods ?? [];
    final authResponse = await widget.web3App.authenticate(
      params: SessionAuthRequestParams(
        chains: _selectedChains.map((e) => e.chainId).toList(),
        domain: Uri.parse(widget.web3App.metadata.url).authority,
        nonce: AuthUtils.generateNonce(),
        uri: widget.web3App.metadata.url,
        statement: 'Welcome to example flutter app',
        methods: <String>{...methods1, ...methods2}.toList(),
      ),
      walletUniversalLink: universalLink,
    );

    debugPrint('[SampleDapp] authResponse.uri ${authResponse.uri}');
    try {
      // If response uri is not universalLink show QR Code
      if (authResponse.uri?.authority != Uri.parse(universalLink).authority) {
        _showQrCode('${authResponse.uri}', walletScheme: nativeLink);
      } else {
        await WalletConnectUtils.openURL(authResponse.uri.toString());
      }
    } catch (e) {
      debugPrint('[SampleDapp] authResponse error $e');
      _showQrCode('${authResponse.uri}', walletScheme: nativeLink);
    }

    try {
      debugPrint('[SampleDapp] Awaiting 1-CA session');
      final response = await authResponse.completer.future;

      if (response.session != null) {
        showToast?.call(
          '${StringConstants.authSucceeded} and ${StringConstants.connectionEstablished}',
        );
      } else {
        final error = response.error ?? response.jsonRpcError;
        showToast?.call(error.toString());
      }
    } catch (e) {
      debugPrint('[SampleDapp] 1-CA $e');
      showToast?.call(StringConstants.connectionFailed);
    }
    closeModal?.call();
  }

  Future<void> _showQrCode(String uri, {String walletScheme = ''}) async {
    // Show the QR code
    debugPrint('[SampleDapp] Showing QR Code: $uri');
    _shouldDismissQrCode = true;
    if (kIsWeb) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            insetPadding: const EdgeInsets.all(0.0),
            contentPadding: const EdgeInsets.all(0.0),
            backgroundColor: Colors.white,
            content: SizedBox(
              width: 400.0,
              child: AspectRatio(
                aspectRatio: 0.8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _QRCodeView(
                    uri: uri,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              )
            ],
          );
        },
      );
      _shouldDismissQrCode = false;
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => QRCodeScreen(
          uri: uri,
          walletScheme: walletScheme,
        ),
      ),
    );
  }

  void _onSessionConnect(SessionConnect? event) async {
    if (event == null) return;

    setState(() => _selectedChains.clear());

    if (_shouldDismissQrCode && Navigator.canPop(context)) {
      _shouldDismissQrCode = false;
      Navigator.pop(context);
    }
  }

  ButtonStyle get _buttonStyle => ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(MaterialState.disabled)) {
              return StyleConstants.grayColor;
            }
            return StyleConstants.primaryColor;
          },
        ),
        minimumSize: MaterialStateProperty.all<Size>(const Size(
          1000.0,
          StyleConstants.linear48,
        )),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              StyleConstants.linear8,
            ),
          ),
        ),
      );
}

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({
    super.key,
    required this.uri,
    this.walletScheme = '',
  });
  final String uri;
  final String walletScheme;

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        appBar: AppBar(title: const Text(StringConstants.scanQrCode)),
        body: _QRCodeView(
          uri: widget.uri,
          walletScheme: widget.walletScheme,
        ),
      ),
    );
  }
}

class _QRCodeView extends StatelessWidget {
  const _QRCodeView({
    required this.uri,
    this.walletScheme = '',
  });
  final String uri;
  final String walletScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        QrImageView(data: uri),
        const SizedBox(
          height: StyleConstants.linear16,
        ),
        ElevatedButton(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: uri.toString()),
            ).then(
              (_) => showPlatformToast(
                child: const Text(StringConstants.copiedToClipboard),
                context: context,
              ),
            );
          },
          child: const Text('Copy URL to Clipboard'),
        ),
        Visibility(
          visible: walletScheme.isNotEmpty,
          child: ElevatedButton(
            onPressed: () async {
              final encodedUri = Uri.encodeComponent(uri);
              await WalletConnectUtils.openURL('$walletScheme?uri=$encodedUri');
            },
            child: const Text('Open Test Wallet'),
          ),
        ),
      ],
    );
  }
}

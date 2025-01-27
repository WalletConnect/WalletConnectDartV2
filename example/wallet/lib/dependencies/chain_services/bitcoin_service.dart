import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/i_web3wallet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/i_key_service.dart';
import 'package:walletconnect_flutter_v2_wallet/models/chain_metadata.dart';
import 'package:walletconnect_flutter_v2_wallet/utils/methods_utils.dart';

import 'package:bitcoin_base/bitcoin_base.dart';
// import 'package:bitcoin_message_signer/bitcoin_message_signer.dart';

class BitcoinService {
  Map<String, dynamic Function(String, dynamic)> get bitcoinRequestHandlers => {
        'btc_signMessage': bitcoinSignMessage,
        'btc_sendTransaction': bitcoinSendTransaction,
      };

  final _web3wallet = GetIt.I<IWeb3WalletService>().web3wallet;
  final ChainMetadata chainSupported;

  BitcoinService({required this.chainSupported}) {
    for (var handler in bitcoinRequestHandlers.entries) {
      _web3wallet.registerRequestHandler(
        chainId: chainSupported.chainId,
        method: handler.key,
        handler: handler.value,
      );
    }
  }

  Future<void> bitcoinSignMessage(String topic, dynamic parameters) async {
    debugPrint('[SampleWallet] bitcoinSignMessage request: $parameters');
    final pRequest = _web3wallet.pendingRequests.getAll().last;
    var response = JsonRpcResponse(id: pRequest.id, jsonrpc: '2.0');

    try {
      final params = parameters as List;
      final message = params.first.toString();

      final keys = GetIt.I<IKeyService>().getKeysForChain(
        chainSupported.chainId,
      );

      final privateKey = ECPrivate.fromWif(
        keys.first.privateKey,
        netVersion: BitcoinNetwork.mainnet.wifNetVer,
      );

      if (await MethodsUtils.requestApproval(
        message,
        method: pRequest.method,
        chainId: pRequest.chainId,
        address: keys.first.address,
        transportType: pRequest.transportType.name,
      )) {
        // final messageSigner = BitcoinMessageSigner(
        //   privateKey: Uint8List.fromList(privateKey.toBytes()),
        //   scriptType: P2WPKH(),
        // );

        final messageBytes = utf8.encode(message);

        final signature = privateKey.signMessage(
          messageBytes,
          messagePrefix: '\x18Bitcoin Signed Message:\n',
        );
        debugPrint('[$runtimeType] signature: $signature');

        // final signature2 = messageSigner.signMessage(
        //   message: message,
        //   messagePrefix: '\x18Bitcoin Signed Message:\n',
        // );

        // debugPrint('[$runtimeType] signature2: $signature2');

        final publicKey = privateKey.getPublic();

        final isValid = publicKey.verify(
          messageBytes,
          base64.decode(signature).sublist(0, 64),
          messagePrefix: '\x18Bitcoin Signed Message:\n',
        );

        debugPrint('[$runtimeType] signature: $signature, valid: $isValid');

        response = response.copyWith(
          result: {
            'signature': '0x$signature',
            // 'segwitType': 'p2wsh',
          },
        );
      } else {
        response = response.copyWith(
          error: const JsonRpcError(code: 5001, message: 'User rejected'),
        );
      }
      //
    } catch (e) {
      debugPrint('[SampleWallet] bitcoinSignMessage error $e');
      response = response.copyWith(
        error: JsonRpcError(code: 0, message: e.toString()),
      );
    }

    _handleResponseForTopic(topic, response);
  }

  Future<void> bitcoinSendTransaction(String topic, dynamic parameters) async {
    debugPrint(
        '[SampleWallet] bitcoinSendTransaction: ${jsonEncode(parameters)}');
    final pRequest = _web3wallet.pendingRequests.getAll().last;
    var response = JsonRpcResponse(id: pRequest.id, jsonrpc: '2.0');

    try {
      final params = parameters as Map<String, dynamic>;
      final beautifiedTrx = const JsonEncoder.withIndent('  ').convert(params);

      final keys = GetIt.I<IKeyService>().getKeysForChain(
        chainSupported.chainId,
      );

      final privateKey = ECPrivate.fromWif(
        keys.first.privateKey,
        netVersion: BitcoinNetwork.mainnet.wifNetVer,
      );

      if (await MethodsUtils.requestApproval(
        // Show Approval Modal
        beautifiedTrx,
        method: pRequest.method,
        chainId: pRequest.chainId,
        address: keys.first.address,
        transportType: pRequest.transportType.name,
      )) {
        // Sign the transaction.
        // else we parse the other key/values, see https://docs.walletconnect.com/advanced/multichain/rpc-reference/solana-rpc#solana_signtransaction
        final address = params['address'].toString();
        final value = params['value'] as num;
        final transactionType = params['transactionType'].toString();

        final List<UtxoWithAddress> utxos =
            []; //await this.getUtXOs(this.address);

        final List<BitcoinBaseOutput> outPuts = [];

        BitcoinTransactionBuilder(
          outPuts: outPuts,
          fee: BigInt.zero,
          network: BitcoinNetwork.mainnet,
          utxos: utxos,
        );

        // response = response.copyWith(
        //   result: {
        //     'signature': signature.toBase58(),
        //   },
        // );
      } else {
        response = response.copyWith(
          error: const JsonRpcError(code: 5001, message: 'User rejected'),
        );
      }
    } catch (e, s) {
      debugPrint('[SampleWallet] bitcoinSendTransaction error $e, $s');
      response = response.copyWith(
        error: JsonRpcError(code: 0, message: e.toString()),
      );
    }

    _handleResponseForTopic(topic, response);
  }

  void _handleResponseForTopic(String topic, JsonRpcResponse response) async {
    final session = _web3wallet.sessions.get(topic);

    try {
      await _web3wallet.respondSessionRequest(
        topic: topic,
        response: response,
      );
      MethodsUtils.handleRedirect(
        topic,
        session!.peer.metadata.redirect,
        response.error?.message,
      );
    } on WalletConnectError catch (error) {
      MethodsUtils.handleRedirect(
        topic,
        session!.peer.metadata.redirect,
        error.message,
      );
    }
  }
}

// String _padEncodeIfNeeded(String encoded) {
//   final padding = encoded.length % 4;
//   if (padding > 0) {
//     encoded += '=' * (4 - padding);
//   }
//   return encoded;
// }

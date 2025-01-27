import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/i_web3wallet_service.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/i_key_service.dart';
import 'package:walletconnect_flutter_v2_wallet/models/chain_metadata.dart';

import 'package:solana_web3/solana_web3.dart' as solana;
// ignore: implementation_imports
import 'package:solana_web3/src/crypto/nacl.dart' as nacl;
// ignore: depend_on_referenced_packages
import 'package:bs58/bs58.dart';

import 'package:walletconnect_flutter_v2_wallet/utils/methods_utils.dart';

///
/// Uses solana_web3: ^0.1.3
///
class SolanaService2 {
  Map<String, dynamic Function(String, dynamic)> get solanaRequestHandlers => {
        'solana_signMessage': solanaSignMessage,
        'solana_signTransaction': solanaSignTransaction,
      };

  final _web3wallet = GetIt.I<IWeb3WalletService>().web3wallet;
  final ChainMetadata chainSupported;

  SolanaService2({required this.chainSupported}) {
    for (var handler in solanaRequestHandlers.entries) {
      _web3wallet.registerRequestHandler(
        chainId: chainSupported.chainId,
        method: handler.key,
        handler: handler.value,
      );
    }
  }

  Future<void> solanaSignMessage(String topic, dynamic parameters) async {
    debugPrint('[SampleWallet] solanaSignMessage request: $parameters');
    final pRequest = _web3wallet.pendingRequests.getAll().last;
    var response = JsonRpcResponse(id: pRequest.id, jsonrpc: '2.0');

    try {
      final params = parameters as Map<String, dynamic>;
      final message = params['message'].toString();

      final keyPair = await _getKeyPair();

      // it's being sent encoded from dapp
      final base58Decoded = base58.decode(message);
      final decodedMessage = utf8.decode(base58Decoded);
      if (await MethodsUtils.requestApproval(
        decodedMessage,
        method: pRequest.method,
        chainId: pRequest.chainId,
        address: keyPair.pubkey.toBase58(),
        transportType: pRequest.transportType.name,
      )) {
        final signature = await nacl.sign.detached(
          base58Decoded,
          keyPair.seckey,
        );

        response = response.copyWith(
          result: {
            'signature': signature.toBase58(),
          },
        );
      } else {
        response = response.copyWith(
          error: const JsonRpcError(code: 5001, message: 'User rejected'),
        );
      }
      //
    } catch (e) {
      debugPrint('[SampleWallet] polkadotSignMessage error $e');
      response = response.copyWith(
        error: JsonRpcError(code: 0, message: e.toString()),
      );
    }

    _handleResponseForTopic(topic, response);
  }

  Future<void> solanaSignTransaction(String topic, dynamic parameters) async {
    debugPrint(
        '[SampleWallet] solanaSignTransaction: ${jsonEncode(parameters)}');
    final pRequest = _web3wallet.pendingRequests.getAll().last;
    var response = JsonRpcResponse(id: pRequest.id, jsonrpc: '2.0');

    try {
      final params = parameters as Map<String, dynamic>;
      final beautifiedTrx = const JsonEncoder.withIndent('  ').convert(params);

      final keyPair = await _getKeyPair();

      if (await MethodsUtils.requestApproval(
        // Show Approval Modal
        beautifiedTrx,
        method: pRequest.method,
        chainId: pRequest.chainId,
        address: keyPair.pubkey.toBase58(),
        transportType: pRequest.transportType.name,
      )) {
        // Sign the transaction.
        // if params contains `transaction` key we should parse that one and disregard the rest, see https://docs.walletconnect.com/advanced/multichain/rpc-reference/solana-rpc#solana_signtransaction
        if (params.containsKey('transaction')) {
          final encodedTx = params['transaction'] as String;
          final decodedTx = solana.Transaction.fromBase64(encodedTx);

          // Sign the transaction.
          decodedTx.sign([keyPair]);

          response = response.copyWith(
            result: {
              'signature': decodedTx.signatures.first.toBase58(),
            },
          );
        } else {
          // else we parse the other key/values, see https://docs.walletconnect.com/advanced/multichain/rpc-reference/solana-rpc#solana_signtransaction
          final feePayer = params['feePayer'].toString();
          final recentBlockHash = params['recentBlockhash'].toString();
          final instructionsList = params['instructions'] as List<dynamic>;

          final instructions = instructionsList.map((json) {
            return (json as Map<String, dynamic>).toInstruction();
          }).toList();

          final decodedTx = solana.Transaction.v0(
            payer: solana.Pubkey.fromBase58(feePayer),
            instructions: instructions,
            recentBlockhash: recentBlockHash,
          );

          // Sign the transaction.
          decodedTx.sign([keyPair]);

          response = response.copyWith(
            result: {
              'signature': decodedTx.signatures.first.toBase58(),
            },
          );
        }
      } else {
        response = response.copyWith(
          error: const JsonRpcError(code: 5001, message: 'User rejected'),
        );
      }
    } catch (e, s) {
      debugPrint('[SampleWallet] solanaSignTransaction error $e, $s');
      response = response.copyWith(
        error: JsonRpcError(code: 0, message: e.toString()),
      );
    }

    _handleResponseForTopic(topic, response);
  }

  Future<solana.Keypair> _getKeyPair() async {
    final keys = GetIt.I<IKeyService>().getKeysForChain(
      chainSupported.chainId,
    );
    try {
      final secKeyBytes = keys[0].privateKey.parse32Bytes();
      return solana.Keypair.fromSeedSync(secKeyBytes);
    } catch (e) {
      final secKeyBytes = base58.decode(keys[0].privateKey);
      // final bytes = Uint8List.fromList(secKeyBytes.sublist(0, 32));
      return solana.Keypair.fromSeckeySync(secKeyBytes);
    }
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

extension on Map<String, dynamic> {
  solana.TransactionInstruction toInstruction() {
    final programId = this['programId'] as String;

    final data = (this['data'] as String);
    final dataBytes = base64.decode(data);

    final keys = this['keys'] as List;
    return solana.TransactionInstruction(
      programId: solana.Pubkey.fromBase58(programId),
      data: dataBytes,
      keys: keys.map((k) {
        final kParams = (k as Map<String, dynamic>);
        return solana.AccountMeta(
          solana.Pubkey.fromBase58(kParams['pubkey']),
          isSigner: kParams['isSigner'] as bool,
          isWritable: kParams['isWritable'] as bool,
        );
      }).toList(),
    );
  }
}

extension on String {
  // SigningKey used by solana package requires a 32 bytes key
  Uint8List parse32Bytes() {
    final List<int> secBytes = split(',').map((e) => int.parse(e)).toList();
    return Uint8List.fromList(secBytes.sublist(0, 32));
  }
}

extension on Uint8List {
  String toBase58() => base58.encode(this);
}

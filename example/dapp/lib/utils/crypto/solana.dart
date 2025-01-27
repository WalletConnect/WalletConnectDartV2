import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:bs58/bs58.dart';

import 'package:solana_web3/solana_web3.dart' as solana;
// import 'package:solana_web3/programs.dart';
// import 'package:solana_web3/src/encodings/lamports.dart';
// import 'package:solana_web3/src/rpc/models/blockhash_with_expiry_block_height.dart';

import 'package:walletconnect_flutter_v2_dapp/models/chain_metadata.dart';
import 'package:walletconnect_flutter_v2_dapp/imports.dart';

enum SolanaMethods {
  solanaSignTransaction,
  solanaSignMessage,
}

enum SolanaEvents {
  none,
}

class Solana {
  static final Map<SolanaMethods, String> methods = {
    SolanaMethods.solanaSignTransaction: 'solana_signTransaction',
    SolanaMethods.solanaSignMessage: 'solana_signMessage'
  };

  static final Map<SolanaEvents, String> events = {};

  static Future<dynamic> callMethod({
    required Web3App web3App,
    required String topic,
    required String method,
    required ChainMetadata chainData,
    required String address,
    bool isV0 = false,
  }) async {
    switch (method) {
      case 'solana_signMessage':
        final bytes = utf8.encode(
          'This is an example message to be signed - ${DateTime.now()}',
        );
        final message = base58.encode(bytes);
        return web3App.request(
          topic: topic,
          chainId: chainData.chainId,
          request: SessionRequestParams(
            method: method,
            params: {
              'pubkey': address,
              'message': message,
            },
          ),
        );
      case 'solana_signTransaction':
        // Create a connection to the devnet cluster.
        final cluster = solana.Cluster.https(
          Uri.parse(chainData.rpc.first).authority,
        );
        // final cluster = solana.Cluster.devnet;
        final connection = solana.Connection(cluster);

        // Fetch the latest blockhash.
        final blockhash = await connection.getLatestBlockhash();

        // Create a System Program instruction to transfer 0.5 SOL from [address1] to [address2].
        final transactionv0 = solana.Transaction.v0(
          payer: solana.Pubkey.fromBase58(address),
          recentBlockhash: blockhash.blockhash,
          instructions: [
            solana.TransactionInstruction.fromJson({
              "programId": "11111111111111111111111111111111",
              "data": [2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
              "keys": [
                {
                  "isSigner": true,
                  "isWritable": true,
                  "pubkey": address,
                },
                {
                  "isSigner": false,
                  "isWritable": true,
                  "pubkey": "8vCyX7oB6Pc3pbWMGYYZF5pbSnAdQ7Gyr32JqxqCy8ZR"
                }
              ]
            }),
            // SystemProgram.transfer(
            //   fromPubkey: solana.Pubkey.fromBase58(address),
            //   toPubkey: solana.Pubkey.fromBase58(
            //     '8vCyX7oB6Pc3pbWMGYYZF5pbSnAdQ7Gyr32JqxqCy8ZR',
            //   ),
            //   lamports: solana.solToLamports(0.5),
            // ),
          ],
        );

        const config = solana.TransactionSerializableConfig(
          verifySignatures: false,
        );
        final bytes = transactionv0.serialize(config).asUint8List();
        final encodedV0Trx = base64.encode(bytes);

        return web3App.signEngine.request(
          topic: topic,
          chainId: chainData.chainId,
          request: SessionRequestParams(
            method: method,
            params: {
              'transaction': encodedV0Trx,
              'pubkey': address,
              'feePayer': address,
              ...transactionv0.message.toJson(),
            },
          ),
        );
      default:
        throw 'Method unimplemented';
    }
  }
}

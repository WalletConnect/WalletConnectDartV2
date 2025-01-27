import 'package:walletconnect_flutter_v2_dapp/models/chain_metadata.dart';
import 'package:walletconnect_flutter_v2_dapp/imports.dart';

enum BitcoinMethods {
  bitcoinSignTransaction,
  bitcoinSignMessage,
}

enum BitcoinEvents {
  none,
}

class Bitcoin {
  static final Map<BitcoinMethods, String> methods = {
    BitcoinMethods.bitcoinSignTransaction: 'btc_sendTransaction',
    BitcoinMethods.bitcoinSignMessage: 'btc_signMessage'
  };

  static final Map<BitcoinEvents, String> events = {};

  static Future<dynamic> callMethod({
    required Web3App web3App,
    required String topic,
    required String method,
    required ChainMetadata chainData,
    required String address,
    bool isV0 = false,
  }) async {
    switch (method) {
      case 'btc_signMessage':
        const message = "This is a message to be signed for BIP122";
        final result = await web3App.request(
          topic: topic,
          chainId: chainData.chainId,
          request: SessionRequestParams(
            method: method,
            params: [message, address],
          ),
        );
        // final checkSegwitAlways = (result.segwitType == "p2wpkh") ||
        //     (result.segwitType == 'p2sh(p2wpkh)');
        return {
          'method': method,
          'address': address,
          // 'valid': verifyBitcoinMessage(
          //   message,
          //   result.signature,
          //   address,
          //   // undefined,
          //   // checkSegwitAlways
          // ),
          'result': ''
              'signature: ${result["signature"]}\n'
              'segwitType: ${result["segwitType"]}',
        };
      case 'btc_sendTransaction':
        // final utxos = await apiGetAddressUtxos(address, chainId);
        // final availableBalance = getAvailableBalanceFromUtxos(utxos); // in satoshis
        return web3App.request(
          topic: topic,
          chainId: chainData.chainId,
          request: SessionRequestParams(
            method: method,
            params: {
              'address': address,
              'value': 0.0000001, // availableBalance,
              'transactionType': 'p2wpkh',
            },
          ),
        );
      default:
        throw 'Method unimplemented';
    }
  }
}

// Future<void> apiGetAddressUtxos(String address, String chainId) {
//    return await (await fetch(`https://mempool.space/signet/api/address/${address}/utxo`)).json();
// }

// int getAvailableBalanceFromUtxos(List utxos) {
//   if (!utxos || !utxos.length) {
//     return 0;
//   }
//   return utxos.reduce((acc, { value }) => acc + value, 0);
// }

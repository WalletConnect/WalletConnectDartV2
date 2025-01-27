import 'dart:math';

import 'package:solana_web3/solana_web3.dart' show hex;
import 'package:flutter_test/flutter_test.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

//https://www.wizardsarena.net/me
//https://dao.swarms.finance/intro
// The WC Modal should disappear, and you can test signing a message.
// The signing will fail, but it will print out the raw TX for you.

void main() async {
  test('Generate eth private key', () {
    EthPrivateKey credentials = EthPrivateKey.createRandom(Random.secure());
    print(hex.encode(credentials.privateKey));
    print(credentials.address);
  });
  // test('Kadena Handler Works', () async {
  //   // For a wallet, setup the proposal handler that will display the proposal to the user after the URI has been scanned.
  //   late int id;
  //   wcClient.onSessionProposal.subscribe((args) async {
  //     // Handle UI updates using the args.params
  //     // Keep track of the args.id for the approval response
  //     id = args!.id;
  //     // print(
  //     //   'args!.params.requiredNamespaces = ${args.params.requiredNamespaces}',
  //     // );

  //     // approve session
  //     // // Present the UI to the user, and allow them to reject or approve the proposal
  //     final walletNamespaces = {
  //       'kadena': const Namespace(
  //         accounts: [
  //           'kadena:mainnet01:k**cf415c73edb4666a967933bddc2e6c4a6e13b8ec0566e612b9f3cbe4a4d8506e',
  //           // yes this is correct. They (Wizards) replace ** with - on their end
  //           'kadena:testnet04:k**cf415c73edb4666a967933bddc2e6c4a6e13b8ec0566e612b9f3cbe4a4d8506e'
  //         ],
  //         methods: [
  //           'kadena_sign',
  //         ],
  //         events: [],
  //       ),
  //     };
  //     // await wcClient.approveSession(
  //     //   id: id,
  //     //   namespaces: walletNamespaces,
  //     // ); // This will have the accounts requested in params

  //     // Or to reject...
  //     // Error codes and reasons can be found here: https://docs.walletconnect.com/2.0/specs/clients/sign/error-codes
  //     // await wcClient.rejectSession(
  //     //   id: id,
  //     //   reason: Errors.getSdkError(Errors.USER_REJECTED_SIGN),
  //     // );
  //   });

  //   // Also setup the namespaces and methods that your wallet supports
  //   Future<dynamic> kadenaSignHandler(
  //     String topic,
  //     dynamic parameters,
  //   ) async {
  //     // params is the transaction data that needs to be constructed and signed
  //     // It is a JSON object, with the format of a Signing Request
  //     // Please read over my supplied documentation for more information
  //     // on Signing Requests and capabilities.
  //     // print('received kadena_sign request');
  //     // print(string);
  //     // print(dynamic);

  //     // Returns an example transaction that says "Test hello"
  //     // No signers, but it doesn't require any.
  //     return {
  //       'hash': 'vVmd6hDD2z8n7Uw_d0YeKky5wa12FVBfQJRC6szFIzY',
  //       'sigs': [],
  //       'cmd':
  //           '{"networkId": "testnet04", "payload": {"exec": {"data": {}, "code": "(format \\"Test {}\\" [\\"hello\\"])"}}, "signers": [], "meta": {"gasLimit": 2500, "chainId": "0", "gasPrice": 1e-05, "sender": "", "ttl": 28000, "creationTime": 1675138667}, "nonce": "20230130211801"}',
  //     };
  //   }

  //   // Looks like kaddex has additional methods that should never be used.
  //   // I have no idea what they do or why they are there.
  //   // They were present in swarms.finance
  //   final methods = <String>[
  //     'kadena_sign',
  //   ];
  //   for (final method in methods) {
  //     wcClient
  //       ..registerRequestHandler(
  //         chainId: 'kadena:mainnet01',
  //         method: method,
  //         handler: kadenaSignHandler,
  //       )
  //       ..registerRequestHandler(
  //         chainId: 'kadena:testnet04',
  //         method: method,
  //         handler: kadenaSignHandler,
  //       );
  //   }

  //   Future<dynamic> kadenaQuicksignHandler(
  //     String topic,
  //     dynamic parameters,
  //   ) async {
  //     // TODO implement quick signing
  //     // print('received kadena_quicksign request');
  //     // print(topic);
  //     // print(parameters);
  //     // return 'quicksigned!';
  //   }

  //   wcClient.registerRequestHandler(
  //     chainId: 'kadena',
  //     method: 'kadena_quicksign',
  //     handler: kadenaQuicksignHandler,
  //   );

  //   // final pairingInfo = await wcClient.pair(uri: uri);
  //   // print('pairingInfo.topic = ${pairingInfo.topic}');
  //   // print('pairingInfo.relay.protocol = ${pairingInfo.relay.protocol}');
  //   // print('pairingInfo.peerMetadata = ${pairingInfo.peerMetadata}');

  //   await Future.delayed(const Duration(seconds: 10000));
  // }, timeout: const Timeout(Duration(seconds: 10000)));
}

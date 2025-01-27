import 'package:flutter/material.dart';
import 'package:walletconnect_flutter_v2_dapp/models/chain_metadata.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/bitcoin.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/chain_data.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/eip155.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/polkadot.dart';
import 'package:walletconnect_flutter_v2_dapp/utils/crypto/solana.dart';

String getChainName(String chain) {
  try {
    return ChainData.allChains
        .where((element) => element.chainId == chain)
        .first
        .name;
  } catch (e) {
    debugPrint('[SampleDapp] Invalid chain');
  }
  return 'Unknown';
}

ChainMetadata getChainMetadataFromChain(String chain) {
  try {
    return ChainData.allChains
        .where((element) => element.chainId == chain)
        .first;
  } catch (e) {
    debugPrint('[SampleDapp] Invalid chain');
  }
  return ChainData.eip155Chains[0];
}

List<String> getChainMethods(ChainType value) {
  switch (value) {
    case ChainType.eip155:
      return EIP155.methods.values.toList();
    case ChainType.solana:
      return Solana.methods.values.toList();
    case ChainType.polkadot:
      return Polkadot.methods.values.toList();
    case ChainType.bip122:
      return Bitcoin.methods.values.toList();
    default:
      return [];
  }
}

List<String> getChainEvents(ChainType value) {
  switch (value) {
    case ChainType.eip155:
      return EIP155.events.values.toList();
    case ChainType.solana:
      return Solana.events.values.toList();
    case ChainType.polkadot:
      return Polkadot.events.values.toList();
    default:
      return [];
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ChainType {
  eip155,
  solana,
  kadena,
  cosmos,
  polkadot,
  bip122,
}

class ChainMetadata {
  final String chainId;
  final String name;
  final String logo;
  final bool isTestnet;
  final Color color;
  final ChainType type;
  final List<String> rpc;

  const ChainMetadata({
    required this.chainId,
    required this.name,
    required this.logo,
    this.isTestnet = false,
    required this.color,
    required this.type,
    required this.rpc,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChainMetadata &&
        other.chainId == chainId &&
        other.name == name &&
        other.logo == logo &&
        other.isTestnet == isTestnet &&
        listEquals(other.rpc, rpc);
  }

  @override
  int get hashCode {
    return chainId.hashCode ^
        name.hashCode ^
        logo.hashCode ^
        rpc.hashCode ^
        isTestnet.hashCode;
  }
}

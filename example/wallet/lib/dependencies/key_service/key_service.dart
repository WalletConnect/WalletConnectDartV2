import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:solana_web3/solana_web3.dart' show hex;
import 'package:flutter/foundation.dart';
import 'package:walletconnect_flutter_v2/apis/core/crypto/crypto_models.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/chain_key.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/key_service/i_key_service.dart';
import 'package:walletconnect_flutter_v2_wallet/models/chain_data.dart';
import 'package:walletconnect_flutter_v2_wallet/dependencies/bip39/bip39_base.dart'
    as bip39;
import 'package:walletconnect_flutter_v2_wallet/dependencies/bip32/bip32_base.dart'
    as bip32;
import 'package:walletconnect_flutter_v2_wallet/utils/dart_defines.dart';

class KeyService extends IKeyService {
  List<ChainKey> _keys = [];

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('w3w_')) {
        await prefs.remove(key);
      }
    }
  }

  @override
  Future<List<ChainKey>> loadKeys() async {
    // ⚠️ WARNING: SharedPreferences is not the best way to store your keys! This is just for example purposes!
    final prefs = await SharedPreferences.getInstance();
    try {
      final savedKeys = prefs.getStringList('w3w_chain_keys')!;
      final chainKeys = savedKeys.map((e) => ChainKey.fromJson(jsonDecode(e)));
      _keys = List<ChainKey>.from(chainKeys.toList());
      //
      final extraKeys = await _extraChainKeys();
      _keys.addAll(extraKeys);
    } catch (_) {}

    debugPrint('[$runtimeType] _keys $_keys');
    return _keys;
  }

  @override
  List<String> getChains() {
    final List<String> chainIds = [];
    for (final ChainKey key in _keys) {
      chainIds.addAll(key.chains);
    }
    return chainIds;
  }

  @override
  List<ChainKey> getKeysForChain(String value) {
    String namespace = value;
    if (value.contains(':')) {
      namespace = NamespaceUtils.getNamespaceFromChain(value);
    }
    return _keys.where((e) => e.namespace == namespace).toList();
  }

  @override
  List<String> getAllAccounts() {
    final List<String> accounts = [];
    for (final ChainKey key in _keys) {
      for (final String chain in key.chains) {
        accounts.add('$chain:${key.address}');
      }
    }
    return accounts;
  }

  @override
  Future<String> getMnemonic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('w3w_mnemonic') ?? '';
  }

  // ** bip39/bip32 - EIP155 **

  @override
  Future<void> loadDefaultWallet() async {
    const mnemonic = DartDefines.ethereumSecretKey;
    await restoreWalletFromSeed(mnemonic: mnemonic);
  }

  @override
  Future<void> createAddressFromSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final mnemonic = prefs.getString('w3w_mnemonic')!;

    final chainKeys = getKeysForChain('eip155');
    final index = chainKeys.length;

    final keyPair = _keyPairFromMnemonic(mnemonic, index: index);
    final chainKey = _eip155ChainKey(keyPair);

    _keys.add(chainKey);

    await _saveKeys();
  }

  @override
  Future<void> restoreWalletFromSeed({required String mnemonic}) async {
    // ⚠️ WARNING: SharedPreferences is not the best way to store your keys! This is just for example purposes!
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('w3w_chain_keys');
    await prefs.setString('w3w_mnemonic', mnemonic);

    final keyPair = _keyPairFromMnemonic(mnemonic);
    final chainKey = _eip155ChainKey(keyPair);

    _keys = List<ChainKey>.from([chainKey]);

    await _saveKeys();
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    // Store only eip155 keys
    final chainKeys = _keys
        .where((k) => k.namespace == 'eip155')
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('w3w_chain_keys', chainKeys);
  }

  CryptoKeyPair _keyPairFromMnemonic(String mnemonic, {int index = 0}) {
    final isValidMnemonic = bip39.validateMnemonic(mnemonic);
    if (!isValidMnemonic) {
      throw 'Invalid mnemonic';
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    final node = bip32.BIP32.fromSeed(seed);
    final child = node.derivePath("m/44'/60'/0'/0/$index");

    final private = hex.encode(child.privateKey!);
    final public = hex.encode(child.publicKey);
    return CryptoKeyPair(private, public);
  }

  ChainKey _eip155ChainKey(CryptoKeyPair keyPair) {
    final private = EthPrivateKey.fromHex(keyPair.privateKey);
    final address = private.address.hex;
    final evmChainKey = ChainKey(
      chains: ChainData.eip155Chains.map((e) => e.chainId).toList(),
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      address: address,
    );
    debugPrint('[SampleWallet] evmChainKey ${evmChainKey.toString()}');
    return evmChainKey;
  }

  // ** extra derivations **

  Future<List<ChainKey>> _extraChainKeys() async {
    // HARDCODED VALUES
    final kadenaChainKey = _kadenaChainKey();
    final polkadotChainKey = _polkadotChainKey();
    final solanaChainKeys = _solanaChainKey();
    final bitcoinChainKeys = await _bitcoinChainKey();
    //
    return [
      kadenaChainKey,
      polkadotChainKey,
      solanaChainKeys,
      bitcoinChainKeys,
    ];
  }

  ChainKey _kadenaChainKey() {
    return ChainKey(
      chains: ChainData.kadenaChains.map((e) => e.chainId).toList(),
      privateKey: DartDefines.kadenaSecretKey,
      publicKey: DartDefines.kadenaAddress,
      address: DartDefines.kadenaAddress,
    );
  }

  ChainKey _polkadotChainKey() {
    return ChainKey(
      chains: ChainData.polkadotChains.map((e) => e.chainId).toList(),
      privateKey: DartDefines.polkadotMnemonic,
      publicKey: '',
      address: DartDefines.polkadotAddress,
    );
  }

  ChainKey _solanaChainKey() {
    return ChainKey(
      chains: ChainData.solanaChains.map((e) => e.chainId).toList(),
      privateKey: DartDefines.solanaSecretKey,
      publicKey: DartDefines.solanaAddress,
      address: DartDefines.solanaAddress,
    );
  }

  Future<ChainKey> _bitcoinChainKey() async {
    final mnemonic = await getMnemonic();
    final seed = bip39.mnemonicToSeed(mnemonic);
    final node = bip32.BIP32.fromSeed(seed);
    final child = node.derivePath("m/84'/0'/0'/0/0");
    final strng = child.toBase58();
    final restored = bip32.BIP32.fromBase58(strng);
    final privateKey = ECPrivate.fromBytes(restored.privateKey!.toList());

    const network = BitcoinNetwork.mainnet;
    final wif = privateKey.toWif(network: network);
    final publicKey = privateKey.getPublic();

    // Generate a Pay-to-Public-Key-Hash (P2PKH) address from the public key.
    final p2pkh = publicKey.toAddress();
    debugPrint('[$runtimeType] p2pkh ${p2pkh.toAddress(network)}');
    // Generate a Pay-to-Witness-Public-Key-Hash (P2WPKH) Segregated Witness (SegWit) address from the public key.
    final p2wpkh = publicKey.toSegwitAddress();
    debugPrint('[$runtimeType] p2wpkh ${p2wpkh.toAddress(network)}');
    // // Generate a Pay-to-Witness-Script-Hash (P2WSH) Segregated Witness (SegWit) address from the public key.
    // final p2wsh = publicKey.toP2wshAddress();
    // debugPrint('[$runtimeType] p2wsh ${p2wsh.toAddress(network)}');
    // // Generate a Taproot address from the public key.
    // final p2tr = publicKey.toTaprootAddress();
    // debugPrint('[$runtimeType] p2tr ${p2tr.toAddress(network)}');
    // // Generate a Pay-to-Public-Key-Hash (P2PKH) inside Pay-to-Script-Hash (P2SH) address from the public key.
    // final p2pkhInP2sh = publicKey.toP2pkhInP2sh();
    // debugPrint('[$runtimeType] p2pkhInP2sh ${p2pkhInP2sh.toAddress(network)}');
    // // Generate a Pay-to-Witness-Public-Key-Hash (P2WPKH) inside Pay-to-Script-Hash (P2SH) address from the public key.
    // final p2wpkhInP2sh = publicKey.toP2wpkhInP2sh();
    // debugPrint(
    //     '[$runtimeType] p2wpkhInP2sh ${p2wpkhInP2sh.toAddress(network)}');
    // // Generate a Pay-to-Witness-Script-Hash (P2WSH) inside Pay-to-Script-Hash (P2SH) address from the public key.
    // final p2wshInP2sh = publicKey.toP2wshInP2sh();
    // debugPrint('[$runtimeType] p2wshInP2sh ${p2wshInP2sh.toAddress(network)}');
    // // Generate a Pay-to-Public-Key (P2PK) inside Pay-to-Script-Hash (P2SH) address from the public key.
    // final p2pkInP2sh = publicKey.toP2pkInP2sh();
    // debugPrint('[$runtimeType] p2pkInP2sh ${p2pkInP2sh.toAddress(network)}');

    //
    return ChainKey(
      chains: ChainData.bitcoinChains.map((e) => e.chainId).toList(),
      privateKey: wif,
      publicKey: p2pkh.toAddress(network),
      address: p2wpkh.toAddress(network),
    );
  }
}

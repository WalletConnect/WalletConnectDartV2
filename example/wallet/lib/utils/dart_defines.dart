class DartDefines {
  static const projectId = String.fromEnvironment('PROJECT_ID');
  // HARDCODED TEST KEYS
  // ETHEREUM
  static const ethereumSecretKey = String.fromEnvironment(
    'ETH_SECRET_KEY',
    defaultValue:
        'spoil video deputy round immense setup wasp secret maze slight bag what',
  );
  // KADENA
  static const kadenaSecretKey = String.fromEnvironment(
    'KADENA_SECRET_KEY',
    defaultValue:
        '6576379e67666438c8a8e637b101d343153fed0f96c1cfa07aa45e4ccb8e5a4f',
  );
  static const kadenaAddress = String.fromEnvironment(
    'KADENA_ADDRESS',
    defaultValue:
        '3a527a1af7713cde04a4ce8b6c95b3806b7582f2423d740fc16eaa5b7a235d42',
  );
  // SOLANA
  static const solanaSecretKey = String.fromEnvironment(
    'SOLANA_SECRET_KEY',
    defaultValue:
        '131,20,187,127,47,75,38,64,75,207,232,11,76,181,166,166,222,165,180,209,240,41,18,94,141,56,106,154,178,179,142,70,202,6,166,179,56,40,83,93,128,50,92,94,242,45,153,178,30,4,157,189,157,159,152,246,221,138,106,213,155,193,247,233',
  );
  static const solanaAddress = String.fromEnvironment(
    'SOLANA_ADDRESS',
    defaultValue: 'EbdEmCpKGvEwfwV4ACmVYHFRkwvXdogJhMZeEekDFVVJ',
  );
  // POLKADOT
  static const polkadotMnemonic = String.fromEnvironment(
    'POLKADOT_MNEMONIC',
    defaultValue:
        'spoil video deputy round immense setup wasp secret maze slight bag what',
  );
  static const polkadotAddress = String.fromEnvironment(
    'POLKADOT_ADDRESS',
    defaultValue: '7UUBfttjb1P1m4KSCxC5UTS8xui6EszQsaJNQ6qztLLnNTz',
  );
}

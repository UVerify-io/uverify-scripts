use aiken/crypto.{VerificationKeyHash, sha2_256}
use aiken/primitive/bytearray
use cardano/address.{from_script, from_verification_key}
use cardano/assets.{PolicyId, from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use common.{certificates_to_bytearray}
use mocktail/virgin_address.{mock_script_credential}
use mocktail/virgin_key_hash.{mock_policy_id, mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use mocktail/virgin_validity_range.{mock_interval}
use types.{
  BURN_BOOTSTRAP, BURN_STATE, BootstrapDatum, MINT_BOOTSTRAP, MINT_STATE,
  StateDatum, UPDATE_STATE, UVerifyCertificate, UVerifyStateRedeemer,
}
use uverify_v1

const admin_account: VerificationKeyHash =
  #"11bcb8e4a79304e23bcd5e2bf628907f9b998f43902f41d1db439981"

test should_mint_bootstrap_token() {
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let transaction =
    Transaction {
      ..placeholder,
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
          datum: InlineDatum(bootstrap_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
      extra_signatories: [admin_account],
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_BOOTSTRAP, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_mint_bootstrap_token() fail {
  let admin_account: VerificationKeyHash =
    #"00bcb8e4a79304e23bcd5e2bf628907f9b998f43902f41d1db439981"
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let transaction =
    Transaction {
      ..placeholder,
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
          datum: InlineDatum(bootstrap_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
      extra_signatories: [admin_account],
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_BOOTSTRAP, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_mint_a_state_token() {
  let user_credential = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      batch_size: 1,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_id, 1),
      extra_signatories: [user_credential],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer {
      purpose: MINT_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_mint_more_tokens() fail {
  let user_credential = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      batch_size: 1,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: merge(
            from_asset(policy_id, state_id, 1),
            from_asset(policy_id, "malicious", 2),
          ),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
      ],
      mint: merge(
        from_asset(policy_id, state_id, 1),
        from_asset(policy_id, "malicious", 2),
      ),
      extra_signatories: [user_credential],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer {
      purpose: MINT_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_allow_minting_state_token() fail {
  let user_credential = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [mock_pub_key_hash(5)],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      batch_size: 1,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_id, 1),
      extra_signatories: [user_credential],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer {
      purpose: MINT_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test mint_a_state_token_from_fake_input() fail {
  let user_credential = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_id, 1),
      extra_signatories: [user_credential],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(
              mock_policy_id(2),
              #"6461746166726f73745f76305f305f32",
              1,
            ),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer {
      purpose: MINT_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test burn_bootstrap_token() {
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(policy_id),
            value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(1, 0),
        },
      ],
      mint: from_asset(policy_id, #"6461746166726f73745f76305f305f32", -1),
      extra_signatories: [admin_account],
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: BURN_BOOTSTRAP, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test burn_state_token() {
  let policy_id: PolicyId = mock_policy_id(1)
  let user_credential = mock_policy_id(3)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      mint: from_asset(policy_id, state_id, -1),
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(state_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(1, 0),
        },
      ],
      extra_signatories: [user_credential],
    }
  let redeemer = UVerifyStateRedeemer { purpose: BURN_STATE, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test burn_state_token_mint_new() fail {
  let policy_id: PolicyId = mock_policy_id(1)
  let user_credential = mock_policy_id(3)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      mint: merge(
        from_asset(policy_id, state_id, -1),
        from_asset(policy_id, "malicious", 2),
      ),
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(state_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(1, 0),
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(4)),
          value: from_asset(policy_id, "malicious", 2),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      extra_signatories: [user_credential],
    }
  let redeemer = UVerifyStateRedeemer { purpose: BURN_STATE, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_burn_oracle() fail {
  let policy_id: PolicyId = mock_policy_id(1)
  let user_credential = mock_policy_id(3)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: True,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      mint: from_asset(policy_id, state_id, -1),
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(state_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(1, 0),
        },
      ],
      extra_signatories: [user_credential],
    }
  let redeemer = UVerifyStateRedeemer { purpose: BURN_STATE, certificates: [] }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_update_state_token() {
  let user_credential = mock_policy_id(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let current_uverify_datum: StateDatum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let next_uverify_datum: StateDatum =
    StateDatum { ..current_uverify_datum, countdown: 998 }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_uverify_datum),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_uverify_datum),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
      ],
      extra_signatories: [user_credential],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer {
      purpose: UPDATE_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_update_state_token_actual_data() {
  let user_credential =
    #"e0c4f6ab8033b332883095342cd20434ae99a71dd300a7c34a9387a5"
  let policy_id: PolicyId =
    #"5ae4d563a0a6b5e27b75020b83bdda44064f50f36cee9fcbf694c5f1"

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a601a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e",
      algorithm: @"SHA-256",
      issuer: user_credential,
      extra: [@"{\"hello\":\"world3\"}"],
    }

  let state_id =
    #"30cf9040140601980c2007b30a3da2d986ca2284e4fc8575cb8edf6bdd1b949a"

  let current_uverify_datum: StateDatum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 2000000,
      fee_interval: 10,
      fee_receivers: [
        #"11bcb8e4a79304e23bcd5e2bf628907f9b998f43902f41d1db439981",
      ],
      ttl: 2526955802000,
      countdown: 99,
      keep_as_oracle: False,
      certificate_data_hash: #"329b02fede037fba9a7b83643abab52e7078245c3b2e89459f879e112f2ff380",
      batch_size: 1,
      bootstrap_datum_name: "uverify",
    }

  let next_uverify_datum: StateDatum =
    StateDatum {
      ..current_uverify_datum,
      countdown: 98,
      certificate_data_hash: #"da0fda9563c35150cda315572b8f26dfe1ad41254d575146620abfc5598b2c79",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          OutputReference {
            transaction_id: #"520b828e80acdb35fd50c4e3a016b3f8a908d65ea860833969052f26f1081cf9",
            output_index: 0,
          },
          Output {
            address: from_script(policy_id),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_uverify_datum),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_uverify_datum),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(policy_id),
          reference_script: None,
        },
      ],
      extra_signatories: [user_credential],
      validity_range: mock_interval(Some(115064602), Some(115065212)),
    }

  let redeemer =
    UVerifyStateRedeemer {
      purpose: UPDATE_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_update_state_token_without_fee() fail {
  let user_credential = mock_policy_id(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let current_uverify_datum: StateDatum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 2000000,
      fee_interval: 10,
      fee_receivers: [mock_pub_key_hash(4)],
      ttl: 1833689900000,
      countdown: 900,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let next_uverify_datum: StateDatum =
    StateDatum { ..current_uverify_datum, countdown: 899 }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_uverify_datum),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_uverify_datum),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
      ],
      extra_signatories: [user_credential],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer {
      purpose: UPDATE_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_update_state_token_with_fee() {
  let user_credential = mock_policy_id(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let current_uverify_datum: StateDatum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 2000000,
      fee_interval: 10,
      fee_receivers: [mock_pub_key_hash(4)],
      ttl: 1833689900000,
      countdown: 900,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let next_uverify_datum: StateDatum =
    StateDatum { ..current_uverify_datum, countdown: 899 }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_uverify_datum),
            reference_script: None,
          },
        ),
        Input(
          mock_utxo_ref(4, 0),
          Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_uverify_datum),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
        Output {
          address: from_verification_key(mock_pub_key_hash(4)),
          value: from_lovelace(2000000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      extra_signatories: [user_credential],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer {
      purpose: UPDATE_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test should_not_mint_two_state_token() fail {
  let user_credential = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum: BootstrapDatum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: #"6461746166726f73745f76305f305f32",
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let uverify_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user_credential,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user_credential,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let another_utxo = mock_utxo_ref(6, 0)
  let expired_state_id =
    sha2_256(
      bytearray.concat(
        left: another_utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )

  let expired_state_datum =
    StateDatum {
      id: expired_state_id,
      owner: user_credential,
      fee: 0,
      countdown: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([uverify_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: #"6461746166726f73745f76305f305f32",
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user_credential),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, expired_state_id, 1),
            datum: InlineDatum(expired_state_datum),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
      ],
      mint: merge(
        merge(
          from_asset(policy_id, state_id, 1),
          from_asset(policy_id, state_id, 1),
        ),
        from_asset(policy_id, expired_state_id, -1),
      ),
      extra_signatories: [user_credential],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, #"6461746166726f73745f76305f305f32", 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer {
      purpose: MINT_STATE,
      certificates: [uverify_certificate],
    }

  uverify_v1.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

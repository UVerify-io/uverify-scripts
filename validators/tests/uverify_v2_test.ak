use aiken/crypto.{VerificationKeyHash, sha2_256}
use aiken/primitive/bytearray
use cardano/address.{from_script, from_verification_key}
use cardano/assets.{PolicyId, from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, Transaction, placeholder,
}
use common.{certificates_to_bytearray}
use mocktail/virgin_address.{mock_script_credential}
use mocktail/virgin_key_hash.{mock_policy_id, mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use mocktail/virgin_validity_range.{mock_interval}
use types.{
  BootstrapDatum, MINT_BOOTSTRAP, MINT_STATE, StateDatum, UPDATE_STATE,
  UVerifyCertificate, UVerifyStateRedeemer,
}
use uverify_v2

const admin_account: VerificationKeyHash =
  #"11bcb8e4a79304e23bcd5e2bf628907f9b998f43902f41d1db439981"

const bootstrap_name = #"6461746166726f73745f76305f305f32"

// --------------------------------------------------------------------------
// Positive flows: v2 must still accept valid transactions
// --------------------------------------------------------------------------

test v2_should_mint_bootstrap_token() {
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: bootstrap_name,
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
          value: from_asset(policy_id, bootstrap_name, 1),
          datum: InlineDatum(bootstrap_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, bootstrap_name, 1),
      extra_signatories: [admin_account],
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_BOOTSTRAP, certificates: [] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test v2_should_mint_a_state_token() {
  let user = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: bootstrap_name,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user,
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
      owner: user,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      batch_size: 1,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(certificates_to_bytearray([certificate])),
      bootstrap_datum_name: bootstrap_name,
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user),
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
      extra_signatories: [user],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, bootstrap_name, 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_STATE, certificates: [certificate] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

test v2_should_update_state_token() {
  let user = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user,
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

  let current_state =
    StateDatum {
      id: state_id,
      owner: user,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(certificates_to_bytearray([certificate])),
      batch_size: 1,
      bootstrap_datum_name: bootstrap_name,
    }
  let next_state = StateDatum { ..current_state, countdown: 998 }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_state),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_state),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
      ],
      extra_signatories: [user],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer { purpose: UPDATE_STATE, certificates: [certificate] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

// --------------------------------------------------------------------------
// High: only the first script input was validated. v2 must reject a second.
// --------------------------------------------------------------------------

test v2_should_not_update_two_state_tokens() fail {
  let attacker = mock_pub_key_hash(3)
  let victim = mock_pub_key_hash(7)
  let policy_id: PolicyId = mock_policy_id(1)

  let attacker_certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: attacker,
      extra: [],
    }

  let utxo = mock_utxo_ref(1, 0)
  let attacker_state_id =
    sha2_256(
      bytearray.concat(
        left: utxo.transaction_id,
        right: bytearray.from_int_little_endian(0, 2),
      ),
    )
  let victim_state_id =
    #"1111111111111111111111111111111111111111111111111111111111111111"

  let attacker_current =
    StateDatum {
      id: attacker_state_id,
      owner: attacker,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(
        certificates_to_bytearray([attacker_certificate]),
      ),
      batch_size: 1,
      bootstrap_datum_name: bootstrap_name,
    }
  let attacker_next = StateDatum { ..attacker_current, countdown: 998 }

  let victim_state =
    StateDatum { ..attacker_current, id: victim_state_id, owner: victim }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, attacker_state_id, 1),
            datum: InlineDatum(attacker_current),
            reference_script: None,
          },
        ),
        Input(
          mock_utxo_ref(3, 0),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, victim_state_id, 1),
            datum: InlineDatum(victim_state),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(attacker_next),
          value: from_asset(policy_id, attacker_state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
        Output {
          datum: NoDatum,
          value: from_asset(policy_id, victim_state_id, 1),
          address: from_verification_key(attacker),
          reference_script: None,
        },
      ],
      extra_signatories: [attacker],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer {
      purpose: UPDATE_STATE,
      certificates: [attacker_certificate],
    }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

// --------------------------------------------------------------------------
// Medium: the minted state token must be locked in the script output.
// --------------------------------------------------------------------------

test v2_should_not_mint_state_token_without_locking_it() fail {
  let user = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: bootstrap_name,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      transaction_limit: 1000,
      batch_size: 1,
    }

  let certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user,
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
  let stray_token =
    #"2222222222222222222222222222222222222222222222222222222222222222"

  let state_datum =
    StateDatum {
      id: state_id,
      owner: user,
      fee: 0,
      fee_interval: 0,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 999,
      batch_size: 1,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(certificates_to_bytearray([certificate])),
      bootstrap_datum_name: bootstrap_name,
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_verification_key(user),
            value: merge(
              from_lovelace(2000000),
              from_asset(policy_id, stray_token, 1),
            ),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, stray_token, 1),
          datum: InlineDatum(state_datum),
          reference_script: None,
        },
        Output {
          address: from_verification_key(user),
          value: from_asset(policy_id, state_id, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_id, 1),
      extra_signatories: [user],
      reference_inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, bootstrap_name, 1),
            datum: InlineDatum(bootstrap_datum),
            reference_script: None,
          },
          output_reference: mock_utxo_ref(2, 0),
        },
      ],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_STATE, certificates: [certificate] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

// --------------------------------------------------------------------------
// Low: a due fee with an empty receiver list must not pass.
// --------------------------------------------------------------------------

test v2_should_not_update_state_token_with_empty_fee_receivers() fail {
  let user = mock_pub_key_hash(3)
  let policy_id: PolicyId = mock_policy_id(1)

  let certificate =
    UVerifyCertificate {
      hash: #"a9ae46f8a3ac5d89bafd1b06b0109a2c5e0ff708f83fc102452fc2a6",
      algorithm: @"SHA256",
      issuer: user,
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

  let current_state =
    StateDatum {
      id: state_id,
      owner: user,
      fee: 2000000,
      fee_interval: 10,
      fee_receivers: [],
      ttl: 1833689900000,
      countdown: 900,
      keep_as_oracle: False,
      certificate_data_hash: sha2_256(certificates_to_bytearray([certificate])),
      batch_size: 1,
      bootstrap_datum_name: bootstrap_name,
    }
  let next_state = StateDatum { ..current_state, countdown: 899 }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input(
          mock_utxo_ref(2, 1),
          Output {
            address: from_script(mock_policy_id(1)),
            value: from_asset(policy_id, state_id, 1),
            datum: InlineDatum(current_state),
            reference_script: None,
          },
        ),
      ],
      outputs: [
        Output {
          datum: InlineDatum(next_state),
          value: from_asset(policy_id, state_id, 1),
          address: from_script(mock_policy_id(1)),
          reference_script: None,
        },
      ],
      extra_signatories: [user],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let redeemer =
    UVerifyStateRedeemer { purpose: UPDATE_STATE, certificates: [certificate] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

// --------------------------------------------------------------------------
// Low: a bootstrap mint must create exactly one NFT of quantity one.
// --------------------------------------------------------------------------

test v2_should_not_mint_multiple_bootstrap_tokens() fail {
  let policy_id: PolicyId = mock_policy_id(1)

  let bootstrap_datum =
    BootstrapDatum {
      allowed_credentials: [],
      token_name: bootstrap_name,
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
          value: from_asset(policy_id, bootstrap_name, 1),
          datum: InlineDatum(bootstrap_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, bootstrap_name, 2),
      extra_signatories: [admin_account],
    }
  let redeemer =
    UVerifyStateRedeemer { purpose: MINT_BOOTSTRAP, certificates: [] }

  uverify_v2.uverify_state.withdraw(
    policy_id,
    "test_proxy_token",
    redeemer,
    mock_script_credential(0),
    transaction,
  )
}

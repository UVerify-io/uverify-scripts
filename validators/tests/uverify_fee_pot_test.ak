use aiken/crypto.{blake2b_224}
use aiken/primitive/bytearray
use aiken/primitive/int.{to_string}
use aiken/primitive/string.{concat}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{Input, NoDatum, Output, Transaction, placeholder}
use mocktail/virgin_key_hash.{mock_policy_id, mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use mocktail/virgin_validity_range.{mock_interval}
use types.{Intent}
use uverify_fee_pot

// This test tries to spend a UTXO with an admin signature
// The output goes to a non-whitelisted script
// The admin should be able to spend the UTXO, while the users should not
test unlock_utxo_as_admin() {
  let admins = [mock_pub_key_hash(1)]
  let users = [mock_pub_key_hash(3), mock_pub_key_hash(2)]
  let script_whitelist = [mock_policy_id(3)]

  let utxo = mock_utxo_ref(1, 0)

  let test_transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_lovelace(3000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(2)),
          value: from_lovelace(2786000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      fee: 214000,
      extra_signatories: [mock_pub_key_hash(1)],
    }

  uverify_fee_pot.fee_pot.spend(
    admins,
    users,
    script_whitelist,
    None,
    Intent.RELEASE,
    utxo,
    test_transaction,
  )
}

// This test tries to spend a UTXO with a user signature
// The output goes to a non-whitelisted script
// The user should not be able to spend the UTXO
test unlock_utxo_as_user_should_fail() fail {
  let admins = [mock_pub_key_hash(1)]
  let users = [mock_pub_key_hash(3), mock_pub_key_hash(2)]
  let script_whitelist = [mock_policy_id(3)]

  let utxo = mock_utxo_ref(1, 0)

  let test_transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_lovelace(3000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(2)),
          value: from_lovelace(2786000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      fee: 214000,
      extra_signatories: [mock_pub_key_hash(3)],
    }

  uverify_fee_pot.fee_pot.spend(
    admins,
    users,
    script_whitelist,
    None,
    Intent.RELEASE,
    utxo,
    test_transaction,
  )
}

// This test tries to spend a UTXO with a user signature
// The output goes to a whitelisted script
// The user should be able to spend the UTXO
test unlock_utxo_as_user() {
  let admins = [mock_pub_key_hash(1)]
  let users = [mock_pub_key_hash(3), mock_pub_key_hash(2)]
  let script_whitelist = [mock_policy_id(3)]

  let utxo = mock_utxo_ref(1, 0)

  let test_transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_lovelace(3000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(3)),
          value: from_lovelace(2786000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      fee: 214000,
      extra_signatories: [mock_pub_key_hash(3)],
    }

  uverify_fee_pot.fee_pot.spend(
    admins,
    users,
    script_whitelist,
    None,
    Intent.RELEASE,
    utxo,
    test_transaction,
  )
}

// This test tries to spend a UTXO without a user nor admin signature
// The output goes to a whitelisted script
// The signer should not be able to spend the UTXO
test unlock_utxo_as_anonymous() fail {
  let admins = [mock_pub_key_hash(1)]
  let users = [mock_pub_key_hash(3), mock_pub_key_hash(2)]
  let script_whitelist = [mock_policy_id(3)]

  let utxo = mock_utxo_ref(1, 0)

  let test_transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_lovelace(3000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(3)),
          value: from_lovelace(2786000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      fee: 214000,
      extra_signatories: [mock_pub_key_hash(4)],
    }

  uverify_fee_pot.fee_pot.spend(
    admins,
    users,
    script_whitelist,
    None,
    Intent.RELEASE,
    utxo,
    test_transaction,
  )
}

// This test tries to spend a UTXO with a user signature on behalf of another user
// The output goes to a whitelisted script
// The user should be able to spend the UTXO
//
// Use case: A backend should submit a transaction on behalf of a user
//           and care about retransmission and transaction building.
test unlock_utxo_as_user_on_behalf_of_another_user() {
  let signer_public_key =
    #"72fc8ca25da7ad898fa539b336da51d11793391bc6d8de19fafb69c18a1f128e"
  let signer_public_key_hash = blake2b_224(signer_public_key)

  let admins = [mock_pub_key_hash(1)]
  let users =
    [mock_pub_key_hash(3), mock_pub_key_hash(2), signer_public_key_hash]
  let script_whitelist = [mock_policy_id(3)]
  let utxo = mock_utxo_ref(1, 0)

  let test_transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: from_script(mock_policy_id(1)),
            value: from_lovelace(3000000),
            datum: NoDatum,
            reference_script: None,
          },
          output_reference: utxo,
        },
      ],
      outputs: [
        Output {
          address: from_script(mock_policy_id(3)),
          value: from_lovelace(2786000),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      fee: 214000,
      extra_signatories: [mock_pub_key_hash(2)],
      validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
    }

  let unix_time = 1756203805000
  let message =
    concat(
      concat(
        concat(bytearray.to_hex(signer_public_key_hash), @":"),
        concat(bytearray.to_hex(mock_pub_key_hash(2)), @":"),
      ),
      to_string(unix_time),
    )

  let redeemer =
    Intent.ON_BEHALF {
      message,
      signature: #"3c0ac0bcb02f95ab37a233e4444839dbad9161b2a13a708366bf9b1b5a0410f11bbc3f877720515bfdbaad40bd6d708037a097114e31486d3fa3696c8752500e",
      signer_public_key,
      submitter_key_hash: mock_pub_key_hash(2),
      ttl: unix_time,
    }

  uverify_fee_pot.fee_pot.spend(
    admins,
    users,
    script_whitelist,
    None,
    redeemer,
    utxo,
    test_transaction,
  )
}

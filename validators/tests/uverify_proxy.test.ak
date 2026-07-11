use aiken/crypto.{sha3_256}
use aiken/primitive/bytearray.{concat}
use aiken/primitive/int
use aiken/primitive/string
use cardano/address.{from_script}
use cardano/assets.{from_asset, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, Transaction, placeholder,
}
use mocktail/virgin_address.{mock_pub_key_address}
use mocktail/virgin_key_hash.{
  mock_policy_id, mock_pub_key_hash, mock_script_hash,
}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use uverify_proxy.{ADMIN, ProxyDatum}

test should_init_a_proxy_contract() {
  let policy_id = mock_policy_id(1)
  let redeemer = ADMIN
  let utxo_ref = mock_utxo_ref(0, 0)

  let state_token_name =
    sha3_256(
      concat(
        utxo_ref.transaction_id,
        string.to_bytearray(int.to_string(utxo_ref.output_index)),
      ),
    )

  let datum =
    ProxyDatum {
      script_pointer: mock_script_hash(1),
      script_owner: mock_pub_key_hash(0),
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: utxo_ref,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(1293000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: from_script(policy_id),
          value: from_asset(policy_id, state_token_name, 1),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_token_name, 1),
      extra_signatories: [mock_pub_key_hash(0)],
    }

  uverify_proxy.proxy.mint(utxo_ref, redeemer, policy_id, transaction)
}

test should_not_init_wrong_token_name() fail {
  let policy_id = mock_policy_id(1)
  let redeemer = ADMIN
  let utxo_ref = mock_utxo_ref(0, 0)

  let state_token_name = #"c4006600e66008008004805100a1819801"

  let datum =
    ProxyDatum {
      script_pointer: mock_script_hash(1),
      script_owner: mock_pub_key_hash(0),
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: utxo_ref,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(1293000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: from_script(policy_id),
          value: from_asset(policy_id, state_token_name, 1),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_token_name, 1),
      extra_signatories: [mock_pub_key_hash(0)],
    }

  uverify_proxy.proxy.mint(utxo_ref, redeemer, policy_id, transaction)
}

test should_not_init_with_wrong_signature() fail {
  let policy_id = mock_policy_id(1)
  let redeemer = ADMIN
  let utxo_ref = mock_utxo_ref(0, 0)

  let state_token_name =
    sha3_256(
      concat(
        utxo_ref.transaction_id,
        string.to_bytearray(int.to_string(utxo_ref.output_index)),
      ),
    )

  let datum =
    ProxyDatum {
      script_pointer: mock_script_hash(1),
      script_owner: mock_pub_key_hash(0),
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: utxo_ref,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(1293000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: from_script(policy_id),
          value: from_asset(policy_id, state_token_name, 1),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, state_token_name, 1),
      extra_signatories: [mock_pub_key_hash(1)],
    }

  uverify_proxy.proxy.mint(utxo_ref, redeemer, policy_id, transaction)
}

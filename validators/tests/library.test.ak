use cardano/address.{from_verification_key}
use cardano/assets.{from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use library

test should_spend_library_utxos() {
  let admin_vkey_hash =
    #"81c0d7f845fb2cf5d23453dc63997595688973c860786503c4d47b11"
  let admin_address = from_verification_key(admin_vkey_hash)
  let script_address =
    from_verification_key(
      #"622900741f55c19276071136f9fb95365ec1eb6c64051a60e67094db",
    )
  let utxo =
    OutputReference {
      transaction_id: #"aaf266c4d221675a08215a84021bf7196e9df532a02ed21119c06c7711384cb9",
      output_index: 1,
    }
  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output: Output {
            address: script_address,
            value: from_lovelace(12249020),
            datum: InlineDatum(#"d87980"),
            reference_script: Some(
              #"bebd37fdabf4f8411bda166994bf5cc74b68b08028da51bbeff47a04",
            ),
          },
          output_reference: utxo,
        },
        Input {
          output: Output {
            address: script_address,
            value: from_lovelace(21769810),
            datum: InlineDatum(#"d87980"),
            reference_script: Some(
              #"d9aeb1f8d5ed5164943cbf75149cf6f8a2c65b3a21eefa00bd57f7b7",
            ),
          },
          output_reference: OutputReference {
            transaction_id: #"aaf266c4d221675a08215a84021bf7196e9df532a02ed21119c06c7711384cb9",
            output_index: 2,
          },
        },
      ],
      outputs: [
        Output {
          address: admin_address,
          value: from_lovelace(55788640),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      extra_signatories: [admin_vkey_hash],
    }

  library.library.spend(admin_vkey_hash, None, NoDatum, utxo, transaction)
}

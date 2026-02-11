use aiken/collection/dict
use aiken/collection/list.{length}
use aiken/crypto.{sha3_256}
use aiken/primitive/bytearray.{concat}
use aiken/primitive/int.{to_string}
use aiken/primitive/string.{to_bytearray}
use cardano/address.{Script}
use cardano/assets.{PolicyId, policies}
use cardano/transaction.{
  InlineDatum, OutputReference, Redeemer, Transaction, find_input,
}
use extensions/connected_goods/common.{ConnectedGood, ConnectedGoodsDatum}

pub type ConnectedGoodsRedeemer {
  token_name: ByteArray,
  password: ByteArray,
}

validator connected_goods {
  mint(_redeemer: Redeemer, policy_id: PolicyId, self: Transaction) {
    let issuer = #"3f9ff01fd67fcf42cb64f004f13306bd4bfd651154aedcb0dd68dd87"
    let Transaction { inputs, outputs, extra_signatories, mint, .. } = self
    expect Some(owner_credential) = list.head(extra_signatories)
    expect Some(script_output) =
      list.find(
        outputs,
        fn(output) { output.address.payment_credential == Script(policy_id) },
      )

    expect [Pair(_asset_name, amount)] =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()

    expect InlineDatum(datum) = script_output.datum
    expect datum: ConnectedGoodsDatum = datum

    expect Some(_unique_id_input) =
      list.find(
        inputs,
        fn(input) {
          let batch_id =
            sha3_256(
              concat(
                input.output_reference.transaction_id,
                to_bytearray(to_string(input.output_reference.output_index)),
              ),
            )

          trace @"input.output_reference.transaction_id": input.output_reference.transaction_id
          trace @"input.output_reference.output_index": input.output_reference.output_index

          trace @"Expected batch_id": batch_id
          trace @"Provided batch_id": datum.id
          batch_id == datum.id
        },
      )

    and {
      amount == 1,
      list.has(policies(script_output.value), policy_id),
      length(extra_signatories) == 1,
      owner_credential == issuer,
    }
  }

  spend(
    datum: Option<ConnectedGoodsDatum>,
    redeemer: ConnectedGoodsRedeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction { inputs, outputs, .. } = self
    expect Some(input) = find_input(inputs, utxo)
    expect Script(policy_id) = input.output.address.payment_credential
    let script_inputs =
      list.filter(
        inputs,
        fn(input) {
          input.output.address.payment_credential == Script(policy_id)
        },
      )

    let script_outputs =
      list.filter(
        outputs,
        fn(output) { output.address.payment_credential == Script(policy_id) },
      )

    expect Some(script_output) = list.head(script_outputs)
    expect Some(target_item) =
      list.find(
        datum.items,
        fn(item) { item.token_name == redeemer.token_name },
      )

    let expected_datum =
      ConnectedGoodsDatum {
        id: "a102",
        items: list.delete(datum.items, target_item),
      }

    expect InlineDatum(output_datum) = script_output.datum
    expect output_datum: ConnectedGoodsDatum = output_datum

    and {
      (length(script_inputs) == 1)?,
      (length(script_outputs) == 1)?,
      list.all(
        policies(script_output.value),
        fn(policy) {
          or {
            policy == policy_id,
            policy == "lovelace",
            policy == "",
          }
        },
      )?,
      list.has(policies(script_output.value), policy_id)?,
      list.has(policies(input.output.value), policy_id)?,
      (target_item.password == sha3_256(redeemer.password))?,
      (list.difference(expected_datum.items, output_datum.items) == [])?,
      (list.length(expected_datum.items) == list.length(output_datum.items))?,
    }
  }

  else(_) {
    fail
  }
}

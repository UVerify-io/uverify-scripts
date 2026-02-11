use aiken/collection/dict
use aiken/collection/list.{length}
use aiken/collection/pairs
use cardano/address.{Script}
use cardano/assets.{PolicyId, policies}
use cardano/transaction.{
  InlineDatum, OutputReference, Redeemer, Spend, Transaction, find_input,
}
use extensions/connected_goods/common.{
  ConnectedGoodsDatum, SocialHubDatum, datum_is_valid,
}
use extensions/connected_goods/connected_goods.{ConnectedGoodsRedeemer}

pub type SocialHubRedeemer {
  Update
  Transfer
}

validator social_hub {
  mint(_redeemer: Redeemer, policy_id: PolicyId, self: Transaction) {
    let connected_goods_policy_id =
      #"2be4b4dccb1e87fbb81f5e3ec518646792b1909c7add563bc162f97b"
    let Transaction { inputs, outputs, extra_signatories, mint, redeemers, .. } =
      self

    expect Some(script_output) =
      list.find(
        outputs,
        fn(output) { output.address.payment_credential == Script(policy_id) },
      )

    let connected_goods_inputs =
      list.filter(
        inputs,
        fn(input) {
          input.output.address.payment_credential == Script(
            connected_goods_policy_id,
          )
        },
      )

    expect Some(connected_goods_input) = list.head(connected_goods_inputs)
    expect InlineDatum(connected_goods_datum) =
      connected_goods_input.output.datum

    expect connected_goods_datum: ConnectedGoodsDatum = connected_goods_datum
    expect Some(connected_good_redeemer) =
      pairs.get_first(redeemers, Spend(connected_goods_input.output_reference))

    expect connected_good_redeemer: ConnectedGoodsRedeemer =
      connected_good_redeemer

    expect [Pair(asset_name, amount)] =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()

    expect asset_name == connected_good_redeemer.token_name
    expect InlineDatum(datum) = script_output.datum
    expect datum: SocialHubDatum = datum

    and {
      datum.batch_id == connected_goods_datum.id,
      (length(connected_goods_inputs) == 1)?,
      (amount == 1)?,
      datum_is_valid(datum)?,
      list.has(policies(script_output.value), policy_id)?,
      (list.length(extra_signatories) == 1)?,
      list.has(extra_signatories, datum.owner)?,
    }
  }

  spend(
    datum: Option<SocialHubDatum>,
    redeemer: SocialHubRedeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction { inputs, outputs, extra_signatories, .. } = self
    expect Some(input) = find_input(inputs, utxo)
    expect Script(policy_id) = input.output.address.payment_credential

    let script_outputs =
      list.filter(
        outputs,
        fn(output) { output.address.payment_credential == Script(policy_id) },
      )

    expect Some(script_output) = list.head(script_outputs)
    expect InlineDatum(updated_datum) = script_output.datum
    expect updated_datum: SocialHubDatum = updated_datum

    let common_checks = and {
        updated_datum.batch_id == datum.batch_id,
        (length(script_outputs) == 1)?,
        (length(policies(script_output.value)) == 2)?,
        list.has(policies(script_output.value), policy_id)?,
        list.has(policies(input.output.value), policy_id)?,
        datum_is_valid(datum)?,
        list.has(extra_signatories, datum.owner)?,
      }

    when redeemer is {
      Update -> and {
          common_checks,
          datum_is_valid(updated_datum),
          updated_datum.owner == datum.owner,
        }

      Transfer -> and {
          common_checks,
          datum_is_valid(updated_datum),
        }
    }
  }

  else(_) {
    fail
  }
}

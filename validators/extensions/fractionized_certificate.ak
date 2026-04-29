use aiken/collection/list
use aiken/collection/pairs
use aiken/primitive/bytearray
use cardano/address.{Script, VerificationKey}
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptPurpose, Transaction,
  Withdraw, find_input,
}
use cocktail/vodka_extra_signatories.{key_signed}
use types.{
  CertificateHead, CertificateInit, CertificateInsert, CertificateNode, Claim,
  FractionizedConfig, FractionizedDatum, FractionizedRedeemer, TokensAvailable,
  TokensExhausted, UVerifyStateRedeemer,
}

const node_prefix: ByteArray = #"46524e"

fn node_token_name(key: ByteArray) -> ByteArray {
  bytearray.concat(node_prefix, bytearray.take(key, 29))
}

fn find_fractionized_node_input(
  inputs: List<Input>,
  policy_id: PolicyId,
  key: ByteArray,
) -> Option<Input> {
  list.find(
    inputs,
    fn(input) {
      quantity_of(input.output.value, policy_id, node_token_name(key)) == 1 && input.output.address.payment_credential == Script(
        policy_id,
      )
    },
  )
}

fn find_fractionized_node_output(
  outputs: List<Output>,
  policy_id: PolicyId,
  key: ByteArray,
) -> Option<Output> {
  list.find(
    outputs,
    fn(output) {
      quantity_of(output.value, policy_id, node_token_name(key)) == 1 && output.address.payment_credential == Script(
        policy_id,
      )
    },
  )
}

fn read_fractionized_head_config(
  reference_inputs: List<Input>,
  policy_id: PolicyId,
) -> FractionizedConfig {
  expect Some(head_ref) =
    list.find(
      reference_inputs,
      fn(ref) {
        quantity_of(ref.output.value, policy_id, node_prefix) == 1 && ref.output.address.payment_credential == Script(
          policy_id,
        )
      },
    )
  expect InlineDatum(raw) = head_ref.output.datum
  expect CertificateHead { config, .. }: FractionizedDatum = raw
  config
}

fn verify_uverify_update(
  redeemers: Pairs<ScriptPurpose, Data>,
  uverify_validator_hash: ByteArray,
  expected_cert_hash: ByteArray,
) -> Bool {
  let purpose: ScriptPurpose = Withdraw(Script(uverify_validator_hash))
  expect Some(raw_redeemer) = pairs.get_first(redeemers, purpose)
  expect uverify_redeemer: UVerifyStateRedeemer = raw_redeemer

  list.any(
    uverify_redeemer.certificates,
    fn(cert) { cert.hash == expected_cert_hash },
  )
}

validator fractionized_certificate(init_utxo: OutputReference) {
  mint(redeemer: FractionizedRedeemer, policy_id: PolicyId, tx: Transaction) {
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      redeemers,
      extra_signatories,
      ..
    } = tx

    when redeemer is {
      CertificateInit { key } -> {
        let init_consumed =
          list.any(inputs, fn(input) { input.output_reference == init_utxo })

        let head_minted = quantity_of(mint, policy_id, node_prefix) == 1
        let node_minted =
          quantity_of(mint, policy_id, node_token_name(key)) == 1

        expect Some(head_output) =
          list.find(
            outputs,
            fn(output) {
              quantity_of(output.value, policy_id, node_prefix) == 1 && output.address.payment_credential == Script(
                policy_id,
              )
            },
          )
        expect InlineDatum(head_raw) = head_output.datum
        expect CertificateHead { next: head_next, config }: FractionizedDatum =
          head_raw

        expect Some(new_node_output) =
          find_fractionized_node_output(outputs, policy_id, key)
        expect InlineDatum(node_raw) = new_node_output.datum
        expect CertificateNode {
          key: node_key,
          next: node_next,
          total_amount,
          remaining_amount,
          status: node_status,
          ..
        }: FractionizedDatum = node_raw

        let uverify_valid =
          verify_uverify_update(redeemers, config.uverify_validator_hash, key)

        and {
          init_consumed?,
          head_minted?,
          node_minted?,
          (bytearray.length(key) > 0)?,
          (!list.is_empty(config.allowed_inserters))?,
          key_signed(extra_signatories, config.deployer)?,
          (head_next == Some(key))?,
          (node_key == key)?,
          (node_next == None)?,
          (total_amount > 0)?,
          (remaining_amount == total_amount)?,
          (node_status == TokensAvailable)?,
          uverify_valid?,
        }
      }

      CertificateInsert { key } -> {
        let config = read_fractionized_head_config(reference_inputs, policy_id)

        let inserter_allowed =
          list.any(
            config.allowed_inserters,
            fn(allowed) { key_signed(extra_signatories, allowed) },
          )

        let uverify_valid =
          verify_uverify_update(redeemers, config.uverify_validator_hash, key)

        let node_minted =
          quantity_of(mint, policy_id, node_token_name(key)) == 1

        expect Some(new_node_output) =
          find_fractionized_node_output(outputs, policy_id, key)
        expect InlineDatum(raw) = new_node_output.datum
        expect CertificateNode {
          key: node_key,
          total_amount,
          remaining_amount,
          status: node_status,
          ..
        }: FractionizedDatum = raw

        and {
          (bytearray.length(key) > 0)?,
          inserter_allowed?,
          uverify_valid?,
          node_minted?,
          (node_key == key)?,
          (total_amount > 0)?,
          (remaining_amount == total_amount)?,
          (node_status == TokensAvailable)?,
        }
      }

      Claim { key, claimer: _, amount } -> {
        expect Some(node_input) =
          find_fractionized_node_input(inputs, policy_id, key)
        expect InlineDatum(raw) = node_input.output.datum
        expect CertificateNode { asset_name, remaining_amount, .. }: FractionizedDatum =
          raw

        and {
          (amount > 0)?,
          (amount <= remaining_amount)?,
          (quantity_of(mint, policy_id, asset_name) == amount)?,
        }
      }
    }
  }

  spend(
    datum: Option<FractionizedDatum>,
    redeemer: FractionizedRedeemer,
    utxo: OutputReference,
    tx: Transaction,
  ) {
    let Transaction { inputs, outputs, extra_signatories, .. } = tx

    expect Some(own_input) = find_input(inputs, utxo)
    expect Script(policy_id) = own_input.output.address.payment_credential

    when redeemer is {
      CertificateInit { .. } -> fail

      CertificateInsert { key } -> {
        expect Some(node_datum) = datum

        let mint_running =
          quantity_of(tx.mint, policy_id, node_token_name(key)) == 1

        when node_datum is {
          CertificateHead { next: pred_next, config } -> {
            expect Some(head_output) =
              find_fractionized_node_output(outputs, policy_id, #"")
            expect InlineDatum(raw) = head_output.datum
            expect CertificateHead { next: new_next, config: new_config }: FractionizedDatum =
              raw

            expect Some(new_node_output) =
              find_fractionized_node_output(outputs, policy_id, key)
            expect InlineDatum(node_raw) = new_node_output.datum
            expect CertificateNode { next: new_node_next, .. }: FractionizedDatum =
              node_raw

            let key_fits =
              when pred_next is {
                None -> True
                Some(next_key) -> bytearray.compare(key, next_key) == Less
              }

            and {
              key_fits?,
              mint_running?,
              (new_next == Some(key))?,
              (new_config == config)?,
              (new_node_next == pred_next)?,
            }
          }

          CertificateNode {
            key: pred_key,
            next: pred_next,
            total_amount,
            remaining_amount,
            claimants,
            asset_name,
            status,
          } -> {
            expect Some(pred_output) =
              find_fractionized_node_output(outputs, policy_id, pred_key)
            expect InlineDatum(raw) = pred_output.datum
            expect CertificateNode {
              key: out_key,
              next: new_next,
              total_amount: out_total,
              remaining_amount: out_remaining,
              claimants: out_claimants,
              asset_name: out_asset_name,
              status: out_status,
            }: FractionizedDatum = raw

            expect Some(new_node_output) =
              find_fractionized_node_output(outputs, policy_id, key)
            expect InlineDatum(node_raw) = new_node_output.datum
            expect CertificateNode { next: new_node_next, .. }: FractionizedDatum =
              node_raw

            let key_fits =
              bytearray.compare(pred_key, key) == Less && when pred_next is {
                None -> True
                Some(next_key) -> bytearray.compare(key, next_key) == Less
              }

            and {
              key_fits?,
              mint_running?,
              (out_key == pred_key)?,
              (new_next == Some(key))?,
              (out_total == total_amount)?,
              (out_remaining == remaining_amount)?,
              (out_claimants == claimants)?,
              (out_asset_name == asset_name)?,
              (out_status == status)?,
              (new_node_next == pred_next)?,
            }
          }
        }
      }

      Claim { key, claimer, amount } -> {
        expect Some(CertificateNode {
          key: node_key,
          next,
          total_amount,
          remaining_amount,
          claimants,
          asset_name,
          status,
        }): Option<FractionizedDatum> = datum

        let new_remaining = remaining_amount - amount
        let new_status =
          if new_remaining == 0 {
            TokensExhausted
          } else {
            TokensAvailable
          }

        expect Some(node_output) =
          find_fractionized_node_output(outputs, policy_id, key)
        expect InlineDatum(raw) = node_output.datum
        expect CertificateNode {
          key: out_key,
          next: out_next,
          total_amount: out_total,
          remaining_amount: out_remaining,
          claimants: out_claimants,
          asset_name: out_asset_name,
          status: out_status,
        }: FractionizedDatum = raw

        let claimer_allowed =
          list.is_empty(claimants) || list.any(
            claimants,
            fn(c) { c == claimer },
          )

        let tokens_sent_to_claimer =
          list.any(
            outputs,
            fn(output) {
              output.address.payment_credential == VerificationKey(claimer) && quantity_of(
                output.value,
                policy_id,
                asset_name,
              ) == amount
            },
          )

        and {
          (node_key == key)?,
          (status == TokensAvailable)?,
          (bytearray.length(key) > 0)?,
          (amount > 0)?,
          (amount <= remaining_amount)?,
          claimer_allowed?,
          key_signed(extra_signatories, claimer)?,
          tokens_sent_to_claimer?,
          (out_key == node_key)?,
          (out_next == next)?,
          (out_total == total_amount)?,
          (out_remaining == new_remaining)?,
          (out_claimants == claimants)?,
          (out_asset_name == asset_name)?,
          (out_status == new_status)?,
        }
      }
    }
  }

  else(_) {
    fail
  }
}

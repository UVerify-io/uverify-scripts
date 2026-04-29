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
  Available, Head, Init, Insert, Node, Redeem, Redeemed, TokenizableConfig,
  TokenizableDatum, TokenizableRedeemer, UVerifyStateRedeemer,
}

const node_prefix: ByteArray = #"54434e"

const cip68_user_prefix: ByteArray = #"000de140"

const cip68_ref_prefix: ByteArray = #"000643b0"

fn node_token_name(key: ByteArray) -> ByteArray {
  bytearray.concat(node_prefix, bytearray.take(key, 29))
}

fn find_node_input(
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

fn find_node_output(
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

fn read_head_config(
  reference_inputs: List<Input>,
  policy_id: PolicyId,
) -> TokenizableConfig {
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
  expect Head { config, .. }: TokenizableDatum = raw
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

validator tokenizable_certificate(init_utxo: OutputReference) {
  mint(redeemer: TokenizableRedeemer, policy_id: PolicyId, tx: Transaction) {
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
      Init { key } -> {
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
        expect Head { next: head_next, config }: TokenizableDatum = head_raw

        expect Some(new_node_output) = find_node_output(outputs, policy_id, key)
        expect InlineDatum(node_raw) = new_node_output.datum
        expect Node {
          key: node_key,
          next: node_next,
          asset_name: node_asset_name,
          status: node_status,
          ..
        }: TokenizableDatum = node_raw

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
          (quantity_of(mint, policy_id, node_asset_name) == 0)?,
          (node_status == Available)?,
          uverify_valid?,
        }
      }

      Insert { key } -> {
        let config = read_head_config(reference_inputs, policy_id)

        let inserter_allowed =
          list.any(
            config.allowed_inserters,
            fn(allowed) { key_signed(extra_signatories, allowed) },
          )

        let uverify_valid =
          verify_uverify_update(redeemers, config.uverify_validator_hash, key)

        let node_minted =
          quantity_of(mint, policy_id, node_token_name(key)) == 1

        expect Some(new_node_output) = find_node_output(outputs, policy_id, key)
        expect InlineDatum(raw) = new_node_output.datum
        expect Node {
          key: node_key,
          asset_name: node_asset_name,
          status: node_status,
          ..
        }: TokenizableDatum = raw

        and {
          (bytearray.length(key) > 0)?,
          inserter_allowed?,
          uverify_valid?,
          node_minted?,
          (quantity_of(mint, policy_id, node_asset_name) == 0)?,
          (node_key == key)?,
          (node_status == Available)?,
        }
      }

      Redeem { key } -> {
        expect Some(node_input) = find_node_input(inputs, policy_id, key)
        expect InlineDatum(raw) = node_input.output.datum
        expect Node { asset_name, .. }: TokenizableDatum = raw

        let config = read_head_config(reference_inputs, policy_id)

        when config.cip68_script_address is {
          None -> quantity_of(mint, policy_id, asset_name) == 1

          Some(ref_script) -> {
            let user_tn = bytearray.concat(cip68_user_prefix, asset_name)
            let ref_tn = bytearray.concat(cip68_ref_prefix, asset_name)

            let ref_locked =
              list.any(
                outputs,
                fn(output) {
                  output.address.payment_credential == Script(ref_script) && quantity_of(
                    output.value,
                    policy_id,
                    ref_tn,
                  ) == 1
                },
              )

            and {
              (quantity_of(mint, policy_id, user_tn) == 1)?,
              (quantity_of(mint, policy_id, ref_tn) == 1)?,
              ref_locked?,
            }
          }
        }
      }
    }
  }

  spend(
    datum: Option<TokenizableDatum>,
    redeemer: TokenizableRedeemer,
    utxo: OutputReference,
    tx: Transaction,
  ) {
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      extra_signatories,
      ..
    } = tx

    expect Some(own_input) = find_input(inputs, utxo)
    expect Script(policy_id) = own_input.output.address.payment_credential

    when redeemer is {
      Init { .. } -> fail

      Insert { key } -> {
        expect Some(node_datum) = datum

        let mint_running =
          quantity_of(mint, policy_id, node_token_name(key)) == 1

        when node_datum is {
          Head { next: pred_next, config } -> {
            expect Some(head_output) = find_node_output(outputs, policy_id, #"")
            expect InlineDatum(raw) = head_output.datum
            expect Head { next: new_next, config: new_config }: TokenizableDatum =
              raw

            expect Some(new_node_output) =
              find_node_output(outputs, policy_id, key)
            expect InlineDatum(node_raw) = new_node_output.datum
            expect Node { next: new_node_next, .. }: TokenizableDatum = node_raw

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

          Node { key: pred_key, next: pred_next, owner, asset_name, status } -> {
            expect Some(pred_output) =
              find_node_output(outputs, policy_id, pred_key)
            expect InlineDatum(raw) = pred_output.datum
            expect Node {
              key: out_key,
              next: new_next,
              owner: out_owner,
              asset_name: out_asset_name,
              status: out_status,
            }: TokenizableDatum = raw

            expect Some(new_node_output) =
              find_node_output(outputs, policy_id, key)
            expect InlineDatum(node_raw) = new_node_output.datum
            expect Node { next: new_node_next, .. }: TokenizableDatum = node_raw

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
              (out_owner == owner)?,
              (out_asset_name == asset_name)?,
              (out_status == status)?,
              (new_node_next == pred_next)?,
            }
          }
        }
      }

      Redeem { key } -> {
        expect Some(Node { key: node_key, next, owner, asset_name, status }): Option<
          TokenizableDatum,
        > = datum

        expect Some(node_output) = find_node_output(outputs, policy_id, key)
        expect InlineDatum(raw) = node_output.datum
        expect Node {
          key: out_key,
          next: out_next,
          owner: out_owner,
          asset_name: out_asset_name,
          status: out_status,
        }: TokenizableDatum = raw

        let config = read_head_config(reference_inputs, policy_id)

        let user_tn =
          when config.cip68_script_address is {
            None -> asset_name
            Some(_) -> bytearray.concat(cip68_user_prefix, asset_name)
          }

        let mint_running = quantity_of(mint, policy_id, user_tn) == 1

        let token_sent_to_owner =
          list.any(
            outputs,
            fn(output) {
              output.address.payment_credential == VerificationKey(owner) && quantity_of(
                output.value,
                policy_id,
                user_tn,
              ) == 1
            },
          )

        and {
          (node_key == key)?,
          (status == Available)?,
          (bytearray.length(key) > 0)?,
          key_signed(extra_signatories, owner)?,
          mint_running?,
          token_sent_to_owner?,
          (out_key == node_key)?,
          (out_next == next)?,
          (out_owner == owner)?,
          (out_asset_name == asset_name)?,
          (out_status == Redeemed)?,
        }
      }
    }
  }

  else(_) {
    fail
  }
}

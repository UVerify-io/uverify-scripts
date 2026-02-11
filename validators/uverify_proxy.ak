use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash, VerificationKeyHash, sha3_256}
use aiken/primitive/bytearray.{concat}
use aiken/primitive/int
use aiken/primitive/string
use cardano/address.{Script}
use cardano/assets.{has_nft, has_nft_strict, tokens}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
  resolve_input,
}
use cocktail/vodka_extra_signatories.{key_signed}

pub type ProxActionRedeemer {
  ADMIN
  USER
}

pub type ProxyDatum {
  script_pointer: ScriptHash,
  script_owner: VerificationKeyHash,
}

fn resolve_proxy_datum(output: Output) {
  expect InlineDatum(datum) = output.datum
  expect proxy_datum: ProxyDatum = datum
  proxy_datum
}

fn get_state_token_name(utxo_ref: OutputReference) {
  sha3_256(
    concat(
      utxo_ref.transaction_id,
      string.to_bytearray(int.to_string(utxo_ref.output_index)),
    ),
  )
}

validator proxy(utxo_ref: OutputReference) {
  mint(
    redeemer: ProxActionRedeemer,
    policy_id: ByteArray,
    transaction: Transaction,
  ) {
    let Transaction {
      inputs,
      outputs,
      extra_signatories,
      mint,
      withdrawals,
      reference_inputs,
      ..
    } = transaction
    trace @"mint proxy contract"
    let state_token_name = get_state_token_name(utxo_ref)

    when redeemer is {
      ADMIN -> {
        // Initialization can only run once
        let required_utxo_spent =
          list.has(
            list.map(inputs, fn(input) { input.output_reference }),
            utxo_ref,
          )

        // Collect all outputs locked at this script and holding the policy token
        let script_outputs = find_script_outputs(outputs, policy_id)

        // There should be just one output going to this script
        expect Some(output) = list.head(script_outputs)
        let proxy_datum = resolve_proxy_datum(output)

        and {
          required_utxo_spent,
          (list.length(script_outputs) == 1)?,
          has_nft_strict(mint, policy_id, state_token_name),
          list.any(
            script_outputs,
            fn(output) { has_nft(output.value, policy_id, state_token_name) },
          ),
          key_signed(extra_signatories, proxy_datum.script_owner)?,
        }
      }
      USER -> {
        trace @"user action 1/2"
        // token name is not allowed to be state_token_name
        let minted_tokens =
          mint
            |> tokens(policy_id)
            |> dict.to_pairs()
            |> pairs.keys

        // reference input with pointer token should be around
        let maybe_script_pointer_ref =
          list.find(
            reference_inputs,
            fn(ref_in) {
              has_nft(ref_in.output.value, policy_id, state_token_name)
            },
          )

        expect Some(script_pointer_ref) = maybe_script_pointer_ref
        let proxy_datum = resolve_proxy_datum(script_pointer_ref.output)

        trace @"user action 2/2"
        and {
          (!list.has(minted_tokens, state_token_name))?,
          list.has(pairs.keys(withdrawals), Script(proxy_datum.script_pointer))?,
        }
      }
    }
  }

  spend(
    _datum: Option<Data>,
    redeemer: ProxActionRedeemer,
    spent_output_ref: OutputReference,
    transaction: Transaction,
  ) {
    trace @"spend proxy contract"
    let Transaction {
      inputs,
      outputs,
      extra_signatories,
      reference_inputs,
      withdrawals,
      ..
    } = transaction
    // Find the input being spent
    let spent_utxo = resolve_input(inputs, spent_output_ref)
    // Getting the policy of tokens produced by this script
    expect Script(policy_id) = spent_utxo.address.payment_credential

    let state_token_name = get_state_token_name(utxo_ref)

    when redeemer is {
      ADMIN -> {
        // There must be an output, that has the state token with an updated state
        expect Some(script_output) =
          list.find(
            outputs,
            fn(output) { has_nft(output.value, policy_id, state_token_name) },
          )

        let new_proxy_datum = resolve_proxy_datum(script_output)
        let old_proxy_datum = resolve_proxy_datum(spent_utxo)

        and {
          key_signed(extra_signatories, old_proxy_datum.script_owner),
          // if the script owner changed, both, old and new owner need to sign the transaction
          or {
            new_proxy_datum.script_owner == old_proxy_datum.script_owner,
            key_signed(extra_signatories, new_proxy_datum.script_owner),
          },
        }
      }
      USER -> {
        trace @"user action 1/2"
        // reference input with pointer token should be around
        let maybe_script_pointer_ref =
          list.find(
            reference_inputs,
            fn(ref_in) {
              has_nft(ref_in.output.value, policy_id, state_token_name)
            },
          )

        expect Some(script_pointer_ref) = maybe_script_pointer_ref
        let proxy_datum = resolve_proxy_datum(script_pointer_ref.output)

        // withdrawal from script with upgradeable logic must be part of the transaction
        let included_withdrawal_scripts = pairs.keys(withdrawals)
        let state_token_not_in_inputs =
          !has_nft(spent_utxo.value, policy_id, state_token_name)

        trace @"user action 2/2"
        and {
          state_token_not_in_inputs?,
          list.has(
            included_withdrawal_scripts,
            Script(proxy_datum.script_pointer),
          )?,
        }
      }
    }
  }

  else(_) {
    fail
  }
}

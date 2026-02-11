use aiken/collection/dict
use aiken/collection/list.{is_empty}
use aiken/collection/pairs
use aiken/crypto.{VerificationKeyHash}
use aiken/option.{is_none, is_some}
use cardano/address.{Address, Credential, Script, from_script}
use cardano/assets.{has_any_nft, has_nft, quantity_of, tokens}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{
  InlineDatum, Input, Output, Redeemer, Transaction, find_script_outputs,
}
use cocktail/vodka_extra_signatories.{key_signed}
use common.{
  certificates_are_valid, contains_service_fee, has_unique_id, is_state_alive,
  state_datum_is_valid, token_not_expired, verify_state_mutation,
}
use types.{
  BURN_BOOTSTRAP, BURN_STATE, BootstrapDatum, MINT_BOOTSTRAP, MINT_STATE,
  StateDatum, UPDATE_STATE, UVerifyStateRedeemer,
}

// Hardcoded admin key required for bootstrap and token burns
const admin_key: VerificationKeyHash =
  #"11bcb8e4a79304e23bcd5e2bf628907f9b998f43902f41d1db439981"

validator uverify_state(
  proxy_policy_id: ByteArray,
  state_token_name: ByteArray,
) {
  // Minting path of the validator
  withdraw(
    redeemer: UVerifyStateRedeemer,
    _account: Credential,
    tx: Transaction,
  ) {
    trace @"withdraw starts"
    let Transaction {
      extra_signatories,
      inputs,
      outputs,
      reference_inputs,
      mint,
      validity_range,
      ..
    } = tx

    let optional_state_update =
      list.find(
        inputs,
        fn(input) {
          input.output.address.payment_credential == Script(proxy_policy_id)
        },
      )
    // If there is a state mutation, there should be just one in a transaction
    let is_updating_state = is_some(optional_state_update)

    // Extract minted token info
    let minted_tokens =
      mint
        |> tokens(proxy_policy_id)
        |> dict.to_pairs()

    let is_minting_or_burning = !is_empty(minted_tokens)

    let pass_minting_logic = or {
        !is_minting_or_burning,
        and {
          is_minting_or_burning,
          // Collect all outputs locked at this script and holding the policy token
          {
            let maybe_script_output_with_policy =
              list.find(
                outputs,
                fn(output) {
                  and {
                    output.address == from_script(proxy_policy_id),
                    has_any_nft(output.value, proxy_policy_id),
                    !has_nft(output.value, proxy_policy_id, state_token_name),
                  }
                },
              )

            when redeemer.purpose is {
              MINT_BOOTSTRAP -> {
                // There must be exactly one script output with a datum
                expect Some(script_output) = maybe_script_output_with_policy
                let Output { datum, .. } = script_output
                expect InlineDatum(inline_datum) = datum

                expect BootstrapDatum { token_name, .. } = inline_datum

                let token_amount = list.length(minted_tokens)
                expect Some(minted_token) =
                  minted_tokens |> pairs.keys |> list.head

                and {
                  // One bootstrap token created
                  (token_amount == 1)?,
                  (token_name == minted_token)?,
                  // Admin must sign bootstrap
                  key_signed(extra_signatories, admin_key)?,
                }
              }
              MINT_STATE -> {
                expect Some(script_output) = maybe_script_output_with_policy
                let Output { datum, .. } = script_output
                expect InlineDatum(inline_datum) = datum

                expect state_datum: StateDatum = inline_datum

                // Reference input must point to an existing bootstrap datum locked at this script
                expect Some(bootstrap_ref) =
                  list.find(
                    reference_inputs,
                    fn(ref_in) {
                      and {
                        ref_in.output.address == from_script(proxy_policy_id),
                        has_nft(
                          ref_in.output.value,
                          proxy_policy_id,
                          state_datum.bootstrap_datum_name,
                        ),
                      }
                    },
                  )

                expect InlineDatum(boot_datum_any) = bootstrap_ref.output.datum
                expect bootstrap_datum: BootstrapDatum = boot_datum_any

                let unique_mints = pairs.find_all(minted_tokens, 1)
                expect Some(asset_name) = list.head(unique_mints)
                let tokens_created = list.length(unique_mints)
                let tokens_burned =
                  list.length(pairs.find_all(minted_tokens, -1))

                and {
                  (list.length(minted_tokens) == tokens_burned + tokens_created)?,
                  tokens_created == 1,
                  tokens_burned <= 1,
                  // Only mint one state token
                  asset_name == state_datum.id,
                  // Asset name matches unique state ID
                  has_unique_id(state_datum.id, inputs)?,
                  (list.length(redeemer.certificates) <= state_datum.batch_size)?,
                  certificates_are_valid(
                    state_datum.certificate_data_hash,
                    redeemer.certificates,
                    extra_signatories,
                  )?,
                  // Is the user credential allowed to fork from the bootstrap datum
                  or {
                    list.is_empty(bootstrap_datum.allowed_credentials)?,
                    list.has(
                      bootstrap_datum.allowed_credentials,
                      state_datum.owner,
                    )?,
                  },
                  // Validate the state token forked correctly from bootstrap
                  state_datum_is_valid(
                    state_datum,
                    state_datum.owner,
                    bootstrap_datum,
                  )?,
                  contains_service_fee(outputs, state_datum)?,
                  token_not_expired(tx.validity_range, state_datum.ttl)?,
                  key_signed(extra_signatories, state_datum.owner)?,
                }
              }
              BURN_BOOTSTRAP -> {
                let tokens_burned = pairs.find_all(minted_tokens, -1)
                expect Some(token_name) = list.head(tokens_burned)
                expect Some(state_input) =
                  list.find(
                    inputs,
                    fn(input) {
                      1 == quantity_of(
                        input.output.value,
                        proxy_policy_id,
                        token_name,
                      )
                    },
                  )

                expect InlineDatum(inline_datum) = state_input.output.datum
                expect bootstrap_datum: BootstrapDatum = inline_datum
                and {
                  (bootstrap_datum.token_name == token_name)?,
                  is_none(maybe_script_output_with_policy)?,
                  key_signed(extra_signatories, admin_key)?,
                }
              }
              // State burn requires no remaining script outputs
              BURN_STATE -> {
                let unique_burned_tokens = pairs.find_all(minted_tokens, -1)
                let tokens_burned = list.length(unique_burned_tokens)

                expect Some(token_name) = list.head(unique_burned_tokens)
                expect Some(state_input) =
                  list.find(
                    inputs,
                    fn(input) {
                      1 == quantity_of(
                        input.output.value,
                        proxy_policy_id,
                        token_name,
                      )
                    },
                  )

                expect InlineDatum(inline_datum) = state_input.output.datum
                expect state_datum: StateDatum = inline_datum

                and {
                  (list.length(minted_tokens) == tokens_burned)?,
                  key_signed(extra_signatories, state_datum.owner)?,
                  (token_name == state_datum.id)?,
                  (!state_datum.keep_as_oracle)?,
                  list.is_empty(redeemer.certificates)?,
                  (tokens_burned == 1)?,
                  is_none(maybe_script_output_with_policy)?,
                }
              }
              _ -> False
            }
          },
        },
      }

    let pass_spending_logic = or {
        !is_updating_state,
        and {
          is_updating_state,
          // Load the input being spent
          {
            expect Some(input) = optional_state_update
            expect InlineDatum(inline_datum) = input.output.datum

            when redeemer.purpose is {
              // --------------------------
              // NORMAL STATE TRANSITION
              // --------------------------
              BURN_BOOTSTRAP ->
                // Conditions already checked in minting burning branch
                is_minting_or_burning
              BURN_STATE ->
                // Conditions already checked in minting burning branch
                is_minting_or_burning
              UPDATE_STATE -> {
                trace @"update state"
                expect current_state: StateDatum = inline_datum

                let script_outputs =
                  find_script_outputs(outputs, proxy_policy_id)

                expect Some(script_output) = list.head(script_outputs)
                expect InlineDatum(next_inline) = script_output.datum
                expect next_state: StateDatum = next_inline

                and {
                  key_signed(extra_signatories, current_state.owner)?,
                  (list.length(script_outputs) == 1)?,
                  has_nft(
                    script_output.value,
                    proxy_policy_id,
                    current_state.id,
                  )?,
                  is_state_alive(current_state, validity_range)?,
                  verify_state_mutation(next_state, current_state)?,
                  contains_service_fee(outputs, next_state)?,
                  (list.length(redeemer.certificates) <= next_state.batch_size)?,
                  certificates_are_valid(
                    next_state.certificate_data_hash,
                    redeemer.certificates,
                    extra_signatories,
                  )?,
                }
              }
              // Any other purpose is invalid
              _ -> False
            }
          },
        },
      }

    and {
      pass_minting_logic?,
      pass_spending_logic?,
    }?
  }

  publish(_redeemer: Redeemer, certificate: Certificate, _self: Transaction) {
    when certificate is {
      RegisterCredential { credential: _credential, deposit: _deposit } -> True
      _ -> fail
    }
  }

  else(_) {
    fail
  }
}

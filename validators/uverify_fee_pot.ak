use aiken/collection/list
use aiken/crypto.{
  ScriptHash, VerificationKeyHash, blake2b_224, verify_ed25519_signature,
}
use aiken/primitive/bytearray
use aiken/primitive/int.{to_string}
use aiken/primitive/string.{concat}
use cardano/address.{from_script}
use cardano/assets.{lovelace_of}
use cardano/transaction.{OutputReference, Transaction, find_input}
use cocktail/vodka_extra_signatories.{one_of_keys_signed}
use cocktail/vodka_validity_range.{valid_before}
use types.{Intent}

validator fee_pot(
  admins: List<VerificationKeyHash>,
  users: List<VerificationKeyHash>,
  script_whitelist: List<ScriptHash>,
) {
  spend(
    _datum: Option<Data>,
    redeemer: Intent,
    utxo: OutputReference,
    self: Transaction,
  ) {
    let Transaction {
      extra_signatories,
      inputs,
      outputs,
      fee,
      validity_range,
      ..
    } = self
    let signed_by_admin = one_of_keys_signed(extra_signatories, admins)

    // If any admin has signed, they are allowed to spend everything
    if signed_by_admin {
      True
    } else {
      let signed_by_user = one_of_keys_signed(extra_signatories, users)

      // The user is only allowed to lock lovelace in the whitelisted scripts or use the utxo to cover fees
      if signed_by_user {
        expect Some(input) = find_input(inputs, utxo)
        let used_lovelace = lovelace_of(input.output.value)

        let script_outputs =
          list.filter(
            outputs,
            fn(output) { output.address == input.output.address },
          )

        let white_listed_script_outputs =
          list.filter(
            outputs,
            fn(output) {
              list.any(
                script_whitelist,
                fn(script) { from_script(script) == output.address },
              )
            },
          )

        let lovelace_guarding_utxo_of_whitelisted_scripts =
          list.reduce(
            white_listed_script_outputs,
            0,
            fn(acc, output) { acc + lovelace_of(output.value) },
          )

        let lovelace_in_change_outputs =
          list.reduce(
            script_outputs,
            0,
            fn(acc, output) { acc + lovelace_of(output.value) },
          )

        when redeemer is {
          Intent.ON_BEHALF {
            signer_public_key,
            submitter_key_hash,
            ttl,
            message,
            signature,
          } -> {
            let signer_public_key_hash = blake2b_224(signer_public_key)
            let expected_message =
              concat(
                concat(
                  concat(bytearray.to_hex(signer_public_key_hash), @":"),
                  concat(bytearray.to_hex(submitter_key_hash), @":"),
                ),
                to_string(ttl),
              )

            trace @"ttl": ttl
            trace @"validity_range": validity_range

            and {
              (used_lovelace <= lovelace_in_change_outputs + lovelace_guarding_utxo_of_whitelisted_scripts + fee)?,
              // signer is also either user or admin
              list.has(admins, signer_public_key_hash) || list.has(
                users,
                signer_public_key_hash,
              )?,
              (expected_message == message)?,
              verify_ed25519_signature(
                signer_public_key,
                string.to_bytearray(message),
                signature,
              )?,
              valid_before(validity_range, ttl)?,
            }
          }
          Intent.RELEASE ->
            used_lovelace <= lovelace_in_change_outputs + lovelace_guarding_utxo_of_whitelisted_scripts + fee
        }
      } else {
        // If no user nor admin has signed, spending is not allowed
        False
      }
    }
  }

  else(_) {
    fail
  }
}

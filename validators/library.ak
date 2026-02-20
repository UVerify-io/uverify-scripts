use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference, Redeemer, Transaction}
use cocktail/vodka_extra_signatories.{key_signed}

validator library(admin: VerificationKeyHash) {
  spend(
    _datum: Option<Data>,
    _redeemer: Redeemer,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    let Transaction { extra_signatories, .. } = self
    key_signed(extra_signatories, admin)?
  }

  else(_) {
    fail
  }
}

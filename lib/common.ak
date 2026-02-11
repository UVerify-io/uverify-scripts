use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, sha2_256}
use aiken/interval
use aiken/primitive/bytearray.{concat}
use aiken/primitive/string.{to_bytearray}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{from_lovelace}
use cardano/transaction.{Input, Output, OutputReference, ValidityRange}
use cocktail/vodka_extra_signatories.{key_signed}
use types.{BootstrapDatum, StateDatum, UVerifyCertificate}

fn byte_array_not_empty(value: ByteArray) -> Bool {
  bytearray.length(value) > 0
}

pub fn certificates_is_valid(
  certificate: UVerifyCertificate,
  extra_signatories: List<VerificationKeyHash>,
) -> Bool {
  and {
    byte_array_not_empty(certificate.hash)?,
    byte_array_not_empty(certificate.issuer)?,
    key_signed(extra_signatories, certificate.issuer)?,
  }
}

pub fn has_unique_id(id: ByteArray, inputs: List<Input>) -> Bool {
  list.any(
    inputs,
    fn(input: Input) {
      let OutputReference { transaction_id, output_index } =
        input.output_reference

      sha2_256(
        bytearray.concat(
          left: transaction_id,
          right: bytearray.from_int_little_endian(output_index, 2),
        ),
      ) == id
    },
  )
}

pub fn certificates_are_valid(
  certificate_data_hash: ByteArray,
  certificates: List<UVerifyCertificate>,
  extra_signatories: List<VerificationKeyHash>,
) {
  and {
    !list.is_empty(certificates),
    list.all(
      certificates,
      fn(certificate) { certificates_is_valid(certificate, extra_signatories) },
    ),
    certificate_data_hash == sha2_256(certificates_to_bytearray(certificates)),
  }
}

pub fn certificates_to_bytearray(certificates: List<UVerifyCertificate>) {
  list.reduce(
    certificates,
    #"",
    fn(bytes, certificate) {
      concat(bytes, certificate_to_bytearray(certificate))
    },
  )
}

pub fn certificate_to_bytearray(certificate: UVerifyCertificate) {
  let UVerifyCertificate { hash, algorithm, issuer, extra } = certificate
  let metadata =
    list.reduce(
      extra,
      #"",
      fn(bytes, part) { concat(bytes, to_bytearray(part)) },
    )
  concat(concat(concat(hash, to_bytearray(algorithm)), issuer), metadata)
}

pub fn state_datum_is_valid(
  state_datum: StateDatum,
  owner_credential: VerificationKeyHash,
  bootstrap_datum: BootstrapDatum,
) -> Bool {
  and {
    state_datum.owner == owner_credential,
    StateDatum {
      ..state_datum,
      fee: bootstrap_datum.fee,
      fee_interval: bootstrap_datum.fee_interval,
      fee_receivers: bootstrap_datum.fee_receivers,
      ttl: bootstrap_datum.ttl,
      batch_size: bootstrap_datum.batch_size,
      bootstrap_datum_name: bootstrap_datum.token_name,
      countdown: bootstrap_datum.transaction_limit - 1,
    } == state_datum,
  }
}

pub fn contains_service_fee(
  outputs: List<Output>,
  state_datum: StateDatum,
) -> Bool {
  state_datum.fee_interval == 0 || state_datum.fee == 0 || (
    state_datum.countdown + 1
  ) % state_datum.fee_interval != 0 || list.all(
    state_datum.fee_receivers,
    fn(receiver) {
      list.any(
        outputs,
        fn(output) {
          output.value == from_lovelace(
            state_datum.fee / list.length(state_datum.fee_receivers),
          ) && output.address.payment_credential == VerificationKey(receiver)
        },
      )
    },
  )
}

pub fn verify_state_mutation(
  next_state_datum: StateDatum,
  current_state_datum: StateDatum,
) -> Bool {
  and {
    !current_state_datum.keep_as_oracle,
    StateDatum {
      ..current_state_datum,
      certificate_data_hash: next_state_datum.certificate_data_hash,
      countdown: current_state_datum.countdown - 1,
    } == next_state_datum,
  }
}

pub fn token_not_expired(range: ValidityRange, ttl: Int) {
  interval.is_entirely_before(range, ttl)
}

pub fn is_state_alive(state_datum: StateDatum, range: ValidityRange) {
  and {
    state_datum.countdown > 0,
    token_not_expired(range, state_datum.ttl),
  }
}

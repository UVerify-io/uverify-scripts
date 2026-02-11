use aiken/crypto.{VerificationKey, VerificationKeyHash}
use cardano/assets.{AssetName}

pub type BootstrapDatum {
  allowed_credentials: List<VerificationKeyHash>,
  token_name: AssetName,
  fee: Int,
  fee_interval: Int,
  fee_receivers: List<VerificationKeyHash>,
  ttl: Int,
  transaction_limit: Int,
  batch_size: Int,
}

pub type UVerifyCertificate {
  hash: ByteArray,
  algorithm: String,
  issuer: ByteArray,
  extra: List<String>,
}

pub type StateDatum {
  id: ByteArray,
  owner: VerificationKeyHash,
  fee: Int,
  fee_interval: Int,
  fee_receivers: List<VerificationKeyHash>,
  ttl: Int,
  countdown: Int,
  certificate_data_hash: ByteArray,
  batch_size: Int,
  bootstrap_datum_name: AssetName,
  keep_as_oracle: Bool,
}

pub type Intent {
  RELEASE
  ON_BEHALF {
    message: String,
    signature: ByteArray,
    signer_public_key: VerificationKey,
    submitter_key_hash: VerificationKeyHash,
    ttl: Int,
  }
}

pub type StatePurpose {
  BURN_BOOTSTRAP
  BURN_STATE
  UPDATE_STATE
  MINT_STATE
  MINT_BOOTSTRAP
}

pub type UVerifyStateRedeemer {
  purpose: StatePurpose,
  certificates: List<UVerifyCertificate>,
}

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

pub type TokenizableNodeStatus {
  Available
  Redeemed
}

pub type TokenizableConfig {
  uverify_validator_hash: ByteArray,
  allowed_inserters: List<VerificationKeyHash>,
  deployer: VerificationKeyHash,
  cip68_script_address: Option<ByteArray>,
}

pub type TokenizableDatum {
  Head { next: Option<ByteArray>, config: TokenizableConfig }
  Node {
    key: ByteArray,
    next: Option<ByteArray>,
    owner: VerificationKeyHash,
    asset_name: AssetName,
    status: TokenizableNodeStatus,
  }
}

pub type TokenizableRedeemer {
  Init { key: ByteArray }
  Insert { key: ByteArray }
  Redeem { key: ByteArray }
}

pub type FractionizedNodeStatus {
  TokensAvailable
  TokensExhausted
}

pub type FractionizedConfig {
  uverify_validator_hash: ByteArray,
  allowed_inserters: List<VerificationKeyHash>,
  deployer: VerificationKeyHash,
}

pub type FractionizedDatum {
  CertificateHead { next: Option<ByteArray>, config: FractionizedConfig }
  CertificateNode {
    key: ByteArray,
    next: Option<ByteArray>,
    total_amount: Int,
    remaining_amount: Int,
    claimants: List<VerificationKeyHash>,
    asset_name: AssetName,
    status: FractionizedNodeStatus,
  }
}

pub type FractionizedRedeemer {
  CertificateInit { key: ByteArray }
  CertificateInsert { key: ByteArray }
  Claim { key: ByteArray, claimer: VerificationKeyHash, amount: Int }
}

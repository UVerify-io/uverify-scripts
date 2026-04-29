use aiken/primitive/bytearray
use cardano/address.{Address, Script}
use cardano/assets.{from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, Redeemer, Transaction, Withdraw,
  placeholder,
}
use extensions/fractionized_certificate
use mocktail/virgin_address.{mock_pub_key_address}
use mocktail/virgin_key_hash.{mock_pub_key_hash, mock_script_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use types.{
  CertificateHead, CertificateInit, CertificateInsert, CertificateNode, Claim,
  FractionizedConfig, TokensAvailable, TokensExhausted, UPDATE_STATE,
  UVerifyCertificate, UVerifyStateRedeemer,
}

// ── Constants ──────────────────────────────────────────────────────────────────

const node_prefix: ByteArray = #"46524e"

// 32-byte certificate keys; a < b lexicographically.
const cert_key_a: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const cert_key_b: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const fraction_asset_name: ByteArray = "FRAC_TOKEN"

fn node_tn(key: ByteArray) -> ByteArray {
  bytearray.concat(node_prefix, bytearray.take(key, 29))
}

fn make_config() -> FractionizedConfig {
  FractionizedConfig {
    uverify_validator_hash: mock_script_hash(10),
    allowed_inserters: [mock_pub_key_hash(1)],
    deployer: mock_pub_key_hash(0),
  }
}

fn make_uverify_redeemer(cert_key: ByteArray) -> UVerifyStateRedeemer {
  UVerifyStateRedeemer {
    purpose: UPDATE_STATE,
    certificates: [
      UVerifyCertificate {
        hash: cert_key,
        algorithm: @"sha256",
        issuer: #"",
        extra: [],
      },
    ],
  }
}

fn script_address(policy_id: ByteArray) -> Address {
  Address { payment_credential: Script(policy_id), stake_credential: None }
}

// ── Init ──────────────────────────────────────────────────────────────────────

test should_init_with_first_node() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: Some(cert_key_a), config }
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: init_utxo,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: merge(
        from_asset(policy_id, node_prefix, 1),
        from_asset(policy_id, node_tn(cert_key_a), 1),
      ),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(0)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInit { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_init_without_deployer_signature() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: Some(cert_key_a), config }
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: init_utxo,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: merge(
        from_asset(policy_id, node_prefix, 1),
        from_asset(policy_id, node_tn(cert_key_a), 1),
      ),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: // wrong signer — not the deployer
      [mock_pub_key_hash(99)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInit { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_init_without_consuming_init_utxo() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let different_utxo = mock_utxo_ref(1, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: Some(cert_key_a), config }
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          // wrong UTxO — not the one locked into the validator
          output_reference: different_utxo,
          output: Output {
            address: mock_pub_key_address(0, None),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: merge(
        from_asset(policy_id, node_prefix, 1),
        from_asset(policy_id, node_tn(cert_key_a), 1),
      ),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(0)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInit { key: cert_key_a },
    policy_id,
    tx,
  )
}

// ── Insert (mint path) ────────────────────────────────────────────────────────

test should_mint_insert_first_node() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: None, config }
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(1)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInsert { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_insert_with_unknown_inserter() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: None, config }
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: // no allowed inserter signs
      [mock_pub_key_hash(99)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInsert { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_insert_with_remaining_not_equal_to_total() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: None, config }
  // remaining_amount < total_amount — invalid on insertion
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 5,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(1)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInsert { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_insert_with_status_already_exhausted() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let uverify_redeemer: Redeemer = make_uverify_redeemer(cert_key_a)

  let head_datum = CertificateHead { next: None, config }
  // status is already TokensExhausted — must be TokensAvailable on insertion
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensExhausted,
    }

  let tx =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(1)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInsert { key: cert_key_a },
    policy_id,
    tx,
  )
}

test should_fail_insert_with_empty_key() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()
  let uverify_hash = config.uverify_validator_hash
  let empty_key: ByteArray = #""
  let uverify_redeemer: Redeemer = make_uverify_redeemer(empty_key)

  let head_datum = CertificateHead { next: None, config }
  let node_datum =
    CertificateNode {
      key: empty_key,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let tx =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(empty_key), 1),
          datum: InlineDatum(node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(empty_key), 1),
      redeemers: [Pair(Withdraw(Script(uverify_hash)), uverify_redeemer)],
      extra_signatories: [mock_pub_key_hash(1)],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    CertificateInsert { key: empty_key },
    policy_id,
    tx,
  )
}

// ── Insert spend — HEAD as predecessor ────────────────────────────────────────

test should_spend_head_on_insert_into_empty_list() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = CertificateHead { next: None, config }
  let updated_head_datum = CertificateHead { next: Some(cert_key_a), config }
  let new_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let head_utxo_ref = mock_utxo_ref(5, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: head_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(updated_head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(new_node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(head_datum),
    CertificateInsert { key: cert_key_a },
    head_utxo_ref,
    tx,
  )
}

// HEAD points to cert_key_b; insert cert_key_a before it.
// After: HEAD → cert_key_a → cert_key_b
test should_spend_head_on_insert_before_existing_node() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = CertificateHead { next: Some(cert_key_b), config }
  let updated_head_datum = CertificateHead { next: Some(cert_key_a), config }
  let new_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: Some(cert_key_b),
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let head_utxo_ref = mock_utxo_ref(5, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: head_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(updated_head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(new_node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_a), 1),
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(head_datum),
    CertificateInsert { key: cert_key_a },
    head_utxo_ref,
    tx,
  )
}

// cert_key_b > cert_key_a so inserting cert_key_b at HEAD (which already
// points to cert_key_a) violates sorted order.
test should_fail_spend_head_with_out_of_order_key() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = CertificateHead { next: Some(cert_key_a), config }
  let updated_head_datum = CertificateHead { next: Some(cert_key_b), config }
  let new_node_datum =
    CertificateNode {
      key: cert_key_b,
      next: Some(cert_key_a),
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let head_utxo_ref = mock_utxo_ref(5, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: head_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(head_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_prefix, 1),
          datum: InlineDatum(updated_head_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_b), 1),
          datum: InlineDatum(new_node_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_b), 1),
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(head_datum),
    CertificateInsert { key: cert_key_b },
    head_utxo_ref,
    tx,
  )
}

// ── Insert spend — Node as predecessor ────────────────────────────────────────

// List: HEAD → cert_key_a → (end). Insert cert_key_b after cert_key_a.
test should_spend_node_on_insert() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)

  let node_a_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_a_datum =
    CertificateNode {
      key: cert_key_a,
      next: Some(cert_key_b),
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let new_node_b_datum =
    CertificateNode {
      key: cert_key_b,
      next: None,
      total_amount: 5,
      remaining_amount: 5,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_a_utxo_ref = mock_utxo_ref(6, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_a_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_a_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_a_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_b), 1),
          datum: InlineDatum(new_node_b_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_b), 1),
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(node_a_datum),
    CertificateInsert { key: cert_key_b },
    node_a_utxo_ref,
    tx,
  )
}

// Predecessor node data is tampered in the output (remaining_amount changed).
test should_fail_spend_node_with_tampered_predecessor_data() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)

  let node_a_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  // attacker reduces remaining_amount on the predecessor output
  let tampered_node_a_datum =
    CertificateNode {
      key: cert_key_a,
      next: Some(cert_key_b),
      total_amount: 10,
      remaining_amount: 1,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let new_node_b_datum =
    CertificateNode {
      key: cert_key_b,
      next: None,
      total_amount: 5,
      remaining_amount: 5,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_a_utxo_ref = mock_utxo_ref(6, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_a_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_a_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(tampered_node_a_datum),
          reference_script: None,
        },
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_b), 1),
          datum: InlineDatum(new_node_b_datum),
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, node_tn(cert_key_b), 1),
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(node_a_datum),
    CertificateInsert { key: cert_key_b },
    node_a_utxo_ref,
    tx,
  )
}

// ── Claim ─────────────────────────────────────────────────────────────────────

// Happy path: open-access certificate, claim 3 out of 10 tokens.
test should_claim_partial_amount_open_access() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      // open access
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 7,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 3),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 3),
      extra_signatories: [claimer],
    }

  and {
    fractionized_certificate.fractionized_certificate.mint(
      init_utxo,
      Claim { key: cert_key_a, claimer, amount: 3 },
      policy_id,
      tx,
    ),
    fractionized_certificate.fractionized_certificate.spend(
      init_utxo,
      Some(node_datum),
      Claim { key: cert_key_a, claimer, amount: 3 },
      node_utxo_ref,
      tx,
    ),
  }
}

// Happy path: restricted-access certificate, claimer is on the allowlist.
test should_claim_when_claimer_is_on_allowlist() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let allowed_claimer = mock_pub_key_hash(5)
  let other_wallet = mock_pub_key_hash(6)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [allowed_claimer, other_wallet],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 8,
      claimants: [allowed_claimer, other_wallet],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 2),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 2),
      extra_signatories: [allowed_claimer],
    }

  and {
    fractionized_certificate.fractionized_certificate.mint(
      init_utxo,
      Claim { key: cert_key_a, claimer: allowed_claimer, amount: 2 },
      policy_id,
      tx,
    ),
    fractionized_certificate.fractionized_certificate.spend(
      init_utxo,
      Some(node_datum),
      Claim { key: cert_key_a, claimer: allowed_claimer, amount: 2 },
      node_utxo_ref,
      tx,
    ),
  }
}

// Claiming all remaining tokens sets status to TokensExhausted.
test should_exhaust_certificate_on_final_claim() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  // claiming all 10 → remaining=0, status=TokensExhausted
  let exhausted_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 0,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensExhausted,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(exhausted_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 10),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 10),
      extra_signatories: [claimer],
    }

  and {
    fractionized_certificate.fractionized_certificate.mint(
      init_utxo,
      Claim { key: cert_key_a, claimer, amount: 10 },
      policy_id,
      tx,
    ),
    fractionized_certificate.fractionized_certificate.spend(
      init_utxo,
      Some(node_datum),
      Claim { key: cert_key_a, claimer, amount: 10 },
      node_utxo_ref,
      tx,
    ),
  }
}

// Disallowed claimer (address not in the claimants list).
test should_fail_claim_by_disallowed_address() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let allowed_claimer = mock_pub_key_hash(5)
  let intruder = mock_pub_key_hash(99)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [allowed_claimer],
      // only allowed_claimer may claim
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 8,
      claimants: [allowed_claimer],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(99, None),
          value: from_asset(policy_id, fraction_asset_name, 2),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 2),
      extra_signatories: [intruder],
    }

  and {
    fractionized_certificate.fractionized_certificate.mint(
      init_utxo,
      Claim { key: cert_key_a, claimer: intruder, amount: 2 },
      policy_id,
      tx,
    ),
    fractionized_certificate.fractionized_certificate.spend(
      init_utxo,
      Some(node_datum),
      Claim { key: cert_key_a, claimer: intruder, amount: 2 },
      node_utxo_ref,
      tx,
    ),
  }
}

// Claiming more tokens than the remaining supply.
test should_fail_claim_exceeds_remaining_amount() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 3,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let output_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 0,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensExhausted,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  // amount=5 but only 3 remain
  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(output_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 5),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 5),
      extra_signatories: [claimer],
    }

  and {
    fractionized_certificate.fractionized_certificate.mint(
      init_utxo,
      Claim { key: cert_key_a, claimer, amount: 5 },
      policy_id,
      tx,
    ),
    fractionized_certificate.fractionized_certificate.spend(
      init_utxo,
      Some(node_datum),
      Claim { key: cert_key_a, claimer, amount: 5 },
      node_utxo_ref,
      tx,
    ),
  }
}

// Minting more tokens than the redeemer amount (the mint field and the
// redeemer amount must agree exactly).
test should_fail_claim_mint_amount_mismatch() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 7,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  // redeemer says amount=3 but tx actually mints 7
  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 7),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: // minting 7 but the redeemer amount is 3
      from_asset(policy_id, fraction_asset_name, 7),
      extra_signatories: [claimer],
    }

  fractionized_certificate.fractionized_certificate.mint(
    init_utxo,
    Claim { key: cert_key_a, claimer, amount: 3 },
    policy_id,
    tx,
  )
}

// Attempting to claim from a certificate that is already exhausted.
test should_fail_claim_from_exhausted_certificate() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  // status is already TokensExhausted — no further claims allowed
  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 0,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensExhausted,
    }
  let output_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 0,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensExhausted,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(output_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 1),
      extra_signatories: [claimer],
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(node_datum),
    Claim { key: cert_key_a, claimer, amount: 1 },
    node_utxo_ref,
    tx,
  )
}

// Tokens sent to a different address than the claimer in the redeemer.
test should_fail_claim_tokens_sent_to_wrong_address() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 7,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        // tokens go to attacker, not to claimer
        Output {
          address: mock_pub_key_address(99, None),
          value: from_asset(policy_id, fraction_asset_name, 3),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 3),
      extra_signatories: [claimer],
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(node_datum),
    Claim { key: cert_key_a, claimer, amount: 3 },
    node_utxo_ref,
    tx,
  )
}

// Claimer does not sign the transaction.
test should_fail_claim_without_claimer_signature() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let claimer = mock_pub_key_hash(5)

  let node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 10,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }
  let updated_node_datum =
    CertificateNode {
      key: cert_key_a,
      next: None,
      total_amount: 10,
      remaining_amount: 7,
      claimants: [],
      asset_name: fraction_asset_name,
      status: TokensAvailable,
    }

  let node_utxo_ref = mock_utxo_ref(7, 0)

  let tx =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: node_utxo_ref,
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_tn(cert_key_a), 1),
            datum: InlineDatum(node_datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: script_address(policy_id),
          value: from_asset(policy_id, node_tn(cert_key_a), 1),
          datum: InlineDatum(updated_node_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(5, None),
          value: from_asset(policy_id, fraction_asset_name, 3),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: from_asset(policy_id, fraction_asset_name, 3),
      extra_signatories: // claimer does not sign
      [],
    }

  fractionized_certificate.fractionized_certificate.spend(
    init_utxo,
    Some(node_datum),
    Claim { key: cert_key_a, claimer, amount: 3 },
    node_utxo_ref,
    tx,
  )
}

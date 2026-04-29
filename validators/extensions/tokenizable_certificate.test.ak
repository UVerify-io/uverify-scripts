use aiken/primitive/bytearray
use cardano/address.{Address, Script}
use cardano/assets.{from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, Redeemer, Transaction, Withdraw,
  placeholder,
}
use extensions/tokenizable_certificate
use mocktail/virgin_address.{mock_pub_key_address}
use mocktail/virgin_key_hash.{mock_pub_key_hash, mock_script_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use types.{
  Available, Head, Init, Insert, Node, Redeem, Redeemed, TokenizableConfig,
  UPDATE_STATE, UVerifyCertificate, UVerifyStateRedeemer,
}

// ── Constants ──────────────────────────────────────────────────────────────────

const node_prefix: ByteArray = #"54434e"

// 32-byte certificate keys; a < b lexicographically.
const cert_key_a: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const cert_key_b: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const token_asset_name: ByteArray = "CERT_TOKEN"

fn node_tn(key: ByteArray) -> ByteArray {
  bytearray.concat(node_prefix, bytearray.take(key, 29))
}

fn make_config() -> TokenizableConfig {
  TokenizableConfig {
    uverify_validator_hash: mock_script_hash(10),
    allowed_inserters: [mock_pub_key_hash(1)],
    deployer: mock_pub_key_hash(0),
    cip68_script_address: None,
  }
}

fn make_cip68_config() -> TokenizableConfig {
  TokenizableConfig {
    uverify_validator_hash: mock_script_hash(10),
    allowed_inserters: [mock_pub_key_hash(1)],
    deployer: mock_pub_key_hash(0),
    cip68_script_address: Some(mock_script_hash(20)),
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

  let head_datum = Head { next: Some(cert_key_a), config }
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Init { key: cert_key_a },
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

  let head_datum = Head { next: Some(cert_key_a), config }
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Init { key: cert_key_a },
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

  let head_datum = Head { next: Some(cert_key_a), config }
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Init { key: cert_key_a },
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

  let head_datum = Head { next: None, config }
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Insert { key: cert_key_a },
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

  let head_datum = Head { next: None, config }
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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
      extra_signatories: [mock_pub_key_hash(99)],
    }

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Insert { key: cert_key_a },
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

  let head_datum = Head { next: None, config }
  let node_datum =
    Node {
      key: empty_key,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.mint(
    init_utxo,
    Insert { key: empty_key },
    policy_id,
    tx,
  )
}

// ── Insert spend — HEAD as predecessor ────────────────────────────────────────

test should_spend_head_on_insert_into_empty_list() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = Head { next: None, config }
  let updated_head_datum = Head { next: Some(cert_key_a), config }
  let new_node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(head_datum),
    Insert { key: cert_key_a },
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

  let head_datum = Head { next: Some(cert_key_b), config }
  let updated_head_datum = Head { next: Some(cert_key_a), config }
  let new_node_datum =
    Node {
      key: cert_key_a,
      next: Some(cert_key_b),
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(head_datum),
    Insert { key: cert_key_a },
    head_utxo_ref,
    tx,
  )
}

// cert_key_b > cert_key_a so inserting cert_key_b at HEAD (which points to cert_key_a)
// violates sorted order.
test should_fail_spend_head_with_out_of_order_key() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = Head { next: Some(cert_key_a), config }
  let updated_head_datum = Head { next: Some(cert_key_b), config }
  let new_node_datum =
    Node {
      key: cert_key_b,
      next: Some(cert_key_a),
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(head_datum),
    Insert { key: cert_key_b },
    head_utxo_ref,
    tx,
  )
}

// HEAD points to cert_key_b; new node's `next` should be Some(cert_key_b)
// but is fabricated as None.
test should_fail_spend_head_with_wrong_new_node_next() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let config = make_config()

  let head_datum = Head { next: Some(cert_key_b), config }
  let updated_head_datum = Head { next: Some(cert_key_a), config }
  // new node's `next` is None instead of the required Some(cert_key_b)
  let new_node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(head_datum),
    Insert { key: cert_key_a },
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
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
    }
  let updated_node_a_datum =
    Node {
      key: cert_key_a,
      next: Some(cert_key_b),
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
    }
  let new_node_b_datum =
    Node {
      key: cert_key_b,
      next: None,
      owner: mock_pub_key_hash(3),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(node_a_datum),
    Insert { key: cert_key_b },
    node_a_utxo_ref,
    tx,
  )
}

// New node's `next` is fabricated instead of being the predecessor's old `next`.
test should_fail_spend_node_with_wrong_new_node_next() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)

  let node_a_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
    }
  let updated_node_a_datum =
    Node {
      key: cert_key_a,
      next: Some(cert_key_b),
      owner: mock_pub_key_hash(2),
      asset_name: token_asset_name,
      status: Available,
    }
  // fabricated next; should be None (= node_a's old next)
  let fabricated: ByteArray =
    #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let new_node_b_datum =
    Node {
      key: cert_key_b,
      next: Some(fabricated),
      owner: mock_pub_key_hash(3),
      asset_name: token_asset_name,
      status: Available,
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

  tokenizable_certificate.tokenizable_certificate.spend(
    init_utxo,
    Some(node_a_datum),
    Insert { key: cert_key_b },
    node_a_utxo_ref,
    tx,
  )
}

// ── Redeem ────────────────────────────────────────────────────────────────────

test should_redeem_available_node() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let owner = mock_pub_key_hash(2)

  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Available,
    }
  let redeemed_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
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
          datum: InlineDatum(redeemed_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(2, None),
          value: from_asset(policy_id, token_asset_name, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(Head { next: None, config: make_config() }),
            reference_script: None,
          },
        },
      ],
      mint: from_asset(policy_id, token_asset_name, 1),
      extra_signatories: [owner],
    }

  and {
    tokenizable_certificate.tokenizable_certificate.mint(
      init_utxo,
      Redeem { key: cert_key_a },
      policy_id,
      tx,
    ),
    tokenizable_certificate.tokenizable_certificate.spend(
      init_utxo,
      Some(node_datum),
      Redeem { key: cert_key_a },
      node_utxo_ref,
      tx,
    ),
  }
}

test should_fail_redeem_with_wrong_owner() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let owner = mock_pub_key_hash(2)

  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Available,
    }
  let redeemed_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
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
          datum: InlineDatum(redeemed_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(2, None),
          value: from_asset(policy_id, token_asset_name, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(Head { next: None, config: make_config() }),
            reference_script: None,
          },
        },
      ],
      mint: from_asset(policy_id, token_asset_name, 1),
      extra_signatories: [mock_pub_key_hash(99)],
    }

  and {
    tokenizable_certificate.tokenizable_certificate.mint(
      init_utxo,
      Redeem { key: cert_key_a },
      policy_id,
      tx,
    ),
    tokenizable_certificate.tokenizable_certificate.spend(
      init_utxo,
      Some(node_datum),
      Redeem { key: cert_key_a },
      node_utxo_ref,
      tx,
    ),
  }
}

test should_fail_redeem_already_redeemed_node() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let owner = mock_pub_key_hash(2)

  // Node is already Redeemed — transition should be rejected.
  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
    }
  let output_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
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
      ],
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(Head { next: None, config: make_config() }),
            reference_script: None,
          },
        },
      ],
      mint: from_asset(policy_id, token_asset_name, 1),
      extra_signatories: [owner],
    }

  and {
    tokenizable_certificate.tokenizable_certificate.mint(
      init_utxo,
      Redeem { key: cert_key_a },
      policy_id,
      tx,
    ),
    tokenizable_certificate.tokenizable_certificate.spend(
      init_utxo,
      Some(node_datum),
      Redeem { key: cert_key_a },
      node_utxo_ref,
      tx,
    ),
  }
}

test should_fail_redeem_token_sent_to_wrong_address() fail {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let owner = mock_pub_key_hash(2)

  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Available,
    }
  let redeemed_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
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
          datum: InlineDatum(redeemed_datum),
          reference_script: None,
        },
        Output {
          address: mock_pub_key_address(99, None),
          value: from_asset(policy_id, token_asset_name, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      reference_inputs: [
        Input {
          output_reference: mock_utxo_ref(10, 0),
          output: Output {
            address: script_address(policy_id),
            value: from_asset(policy_id, node_prefix, 1),
            datum: InlineDatum(Head { next: None, config: make_config() }),
            reference_script: None,
          },
        },
      ],
      mint: from_asset(policy_id, token_asset_name, 1),
      extra_signatories: [owner],
    }

  and {
    tokenizable_certificate.tokenizable_certificate.mint(
      init_utxo,
      Redeem { key: cert_key_a },
      policy_id,
      tx,
    ),
    tokenizable_certificate.tokenizable_certificate.spend(
      init_utxo,
      Some(node_datum),
      Redeem { key: cert_key_a },
      node_utxo_ref,
      tx,
    ),
  }
}

// ── Redeem (CIP-68 mode) ──────────────────────────────────────────────────────

const cip68_user_prefix: ByteArray = #"000de140"

const cip68_ref_prefix: ByteArray = #"000643b0"

test should_redeem_with_cip68_pair() {
  let init_utxo = mock_utxo_ref(0, 0)
  let policy_id = mock_script_hash(1)
  let owner = mock_pub_key_hash(2)
  let config = make_cip68_config()
  let ref_script = mock_script_hash(20)

  let user_tn = bytearray.concat(cip68_user_prefix, token_asset_name)
  let ref_tn = bytearray.concat(cip68_ref_prefix, token_asset_name)

  let node_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Available,
    }
  let redeemed_datum =
    Node {
      key: cert_key_a,
      next: None,
      owner,
      asset_name: token_asset_name,
      status: Redeemed,
    }
  let head_datum = Head { next: Some(cert_key_a), config }
  let node_utxo_ref = mock_utxo_ref(7, 0)

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
          datum: InlineDatum(redeemed_datum),
          reference_script: None,
        },
        // Label-222 user token → owner's wallet.
        Output {
          address: mock_pub_key_address(2, None),
          value: from_asset(policy_id, user_tn, 1),
          datum: NoDatum,
          reference_script: None,
        },
        // Label-100 reference token → CIP-68 script.
        Output {
          address: script_address(ref_script),
          value: from_asset(policy_id, ref_tn, 1),
          datum: NoDatum,
          reference_script: None,
        },
      ],
      mint: merge(
        from_asset(policy_id, user_tn, 1),
        from_asset(policy_id, ref_tn, 1),
      ),
      extra_signatories: [owner],
    }

  and {
    tokenizable_certificate.tokenizable_certificate.mint(
      init_utxo,
      Redeem { key: cert_key_a },
      policy_id,
      tx,
    ),
    tokenizable_certificate.tokenizable_certificate.spend(
      init_utxo,
      Some(node_datum),
      Redeem { key: cert_key_a },
      node_utxo_ref,
      tx,
    ),
  }
}

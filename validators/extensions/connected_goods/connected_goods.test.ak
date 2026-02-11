use aiken/crypto.{sha3_256}
use aiken/primitive/bytearray.{concat}
use aiken/primitive/int.{to_string}
use aiken/primitive/string.{to_bytearray}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{from_asset, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use extensions/connected_goods/common.{ConnectedGood, ConnectedGoodsDatum}
use extensions/connected_goods/connected_goods.{ConnectedGoodsRedeemer}

test mint_connected_goods() {
  let issuer = #"3f9ff01fd67fcf42cb64f004f13306bd4bfd651154aedcb0dd68dd87"
  let policy_id = #"f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"
  let output_reference =
    OutputReference {
      transaction_id: #"7db60aba11635cfab24f735f60cdf06238a0ca7590eff8a410e33c107694e00a",
      output_index: 0,
    }

  let batch_id =
    sha3_256(
      concat(
        output_reference.transaction_id,
        to_bytearray(to_string(output_reference.output_index)),
      ),
    )
  let datum =
    ConnectedGoodsDatum {
      id: batch_id,
      items: [
        ConnectedGood {
          token_name: "SHIRT001",
          password: #"c048a9d0fb25ef56c88c6d566390238adecd08d98d2e77c6f1e39e06e4d475af",
        },
      ],
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference,
          output: Output {
            address: Address {
              payment_credential: VerificationKey(issuer),
              stake_credential: None,
            },
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: Address {
            payment_credential: Script(policy_id),
            stake_credential: None,
          },
          value: from_asset(policy_id, "BUIDLERS_FEST_2025", 1),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      extra_signatories: [issuer],
      mint: from_asset(policy_id, "BUIDLERS_FEST_2025", 1),
    }

  connected_goods.connected_goods.mint(None, policy_id, transaction)
}

test spend_connected_goods() {
  let issuer = #"ed31457d4143f5c95fd132e0bda6c4696d20a80e19b47fdfe9063ce2"
  let policy_id = #"f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"
  let datum =
    ConnectedGoodsDatum {
      id: #"01a2",
      items: [
        ConnectedGood {
          token_name: "SHIRT001",
          password: #"c048a9d0fb25ef56c88c6d566390238adecd08d98d2e77c6f1e39e06e4d475af",
        },
        ConnectedGood {
          token_name: "SHIRT002",
          password: #"99a3c3a17e6d881f0b1a70901be40f792e9edf679faa5e7d514b921bcd19d4c3",
        },
      ],
    }

  let redeemer =
    ConnectedGoodsRedeemer {
      token_name: "SHIRT001",
      password: "a01a01b02b0200bb",
    }
  let updated_datum: ConnectedGoodsDatum =
    ConnectedGoodsDatum {
      id: #"01a2",
      items: [
        ConnectedGood {
          token_name: "SHIRT002",
          password: #"99a3c3a17e6d881f0b1a70901be40f792e9edf679faa5e7d514b921bcd19d4c3",
        },
      ],
    }

  let output_reference =
    OutputReference {
      transaction_id: #"6fb60aba11635cfab24f735f60cdf06238a0ca7590eff8a410e33c107694eddd",
      output_index: 0,
    }

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference,
          output: Output {
            address: Address {
              payment_credential: Script(policy_id),
              stake_credential: None,
            },
            value: from_asset(policy_id, "BUIDLERS_FEST_2025", 1),
            datum: InlineDatum(datum),
            reference_script: None,
          },
        },
      ],
      outputs: [
        Output {
          address: Address {
            payment_credential: Script(policy_id),
            stake_credential: None,
          },
          value: from_asset(policy_id, "BUIDLERS_FEST_2025", 1),
          datum: InlineDatum(updated_datum),
          reference_script: None,
        },
      ],
      extra_signatories: [issuer],
      mint: from_asset(policy_id, "BUIDLERS_FEST_2025", 1),
    }

  connected_goods.connected_goods.spend(
    Some(datum),
    redeemer,
    output_reference,
    transaction,
  )
}

use cardano/address.{Address, Script}
use cardano/assets.{from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Redeemer, Spend, Transaction,
  placeholder,
}
use extensions/connected_goods/common.{
  ConnectedGood, ConnectedGoodsDatum, SocialHubDatum,
}
use extensions/connected_goods/connected_goods.{ConnectedGoodsRedeemer}
use extensions/connected_goods/social_hub.{Transfer, Update}

test mint_social_hub() {
  let connected_goods_policy_id =
    #"2be4b4dccb1e87fbb81f5e3ec518646792b1909c7add563bc162f97b"
  let policy_id = #"f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"

  let owner = #"68182d17a7d772dfb4a260b46fc29a63bfa2a061603ff128fe9a0680"

  let datum =
    SocialHubDatum {
      owner,
      batch_id: #"01a2",
      picture: Some("github"),
      name: Some("Jane Doe"),
      subtitle: Some("Software Engineer"),
      x: Some("long_hair"),
      telegram: Some("lOnG_hAiR1234"),
      instagram: Some("my_long_hair"),
      discord: Some("long_hair#1234"),
      reddit: Some("long_hair"),
      youtube: Some("long_hair_channel"),
      linkedin: Some("mr_serious_business"),
      github: Some("coding_with_long_hair"),
      website: Some("https://hairstyle-dev.com"),
      adahandle: Some("long_hair"),
      email: None,
    }

  let connected_goods_output_reference =
    OutputReference {
      transaction_id: #"6fb60aba11635cfab24f735f60cdf06238a0ca7590eff8a410e33c107694eddd",
      output_index: 0,
    }

  let connected_good_redeemer: Redeemer =
    ConnectedGoodsRedeemer {
      token_name: "SHIRT001",
      password: "a01a01b02b0200bb",
    }

  let connected_good_datum =
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

  let transaction =
    Transaction {
      ..placeholder,
      inputs: [
        Input {
          output_reference: connected_goods_output_reference,
          output: Output {
            address: Address {
              payment_credential: Script(connected_goods_policy_id),
              stake_credential: None,
            },
            value: from_asset(
              connected_goods_policy_id,
              "BUIDLERS_FEST_2025",
              1,
            ),
            datum: InlineDatum(connected_good_datum),
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
          value: from_asset(policy_id, "SHIRT001", 1),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      extra_signatories: [owner],
      mint: from_asset(policy_id, "SHIRT001", 1),
      redeemers: [
        Pair(Spend(connected_goods_output_reference), connected_good_redeemer),
      ],
    }

  social_hub.social_hub.mint(None, policy_id, transaction)
}

test update_social_hub() {
  let policy_id = #"f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"
  let owner = #"68182d17a7d772dfb4a260b46fc29a63bfa2a061603ff128fe9a0680"

  let redeemer = Update

  let output_reference =
    OutputReference {
      transaction_id: #"6fb60aba11635cfab24f735f60cdf06238a0ca7590eff8a410e33c107694eddd",
      output_index: 0,
    }

  let initial_datum =
    SocialHubDatum {
      owner,
      batch_id: #"01a2",
      picture: Some("github"),
      name: Some("Jane Doe"),
      subtitle: Some("Software Engineer"),
      x: Some("long_hair"),
      telegram: Some("lOnG_hAiR1234"),
      instagram: Some("my_long_hair"),
      discord: Some("long_hair#1234"),
      reddit: Some("long_hair"),
      youtube: Some("long_hair_channel"),
      linkedin: Some("mr_serious_business"),
      github: Some("coding_with_long_hair"),
      website: Some("https://hairstyle-dev.com"),
      adahandle: Some("long_hair"),
      email: None,
    }

  let datum =
    SocialHubDatum {
      ..initial_datum,
      website: Some("https://hairstyle-new-dev.io"),
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
            value: from_asset(policy_id, "buidlers_fest_shirt", 1),
            datum: InlineDatum(initial_datum),
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
          value: merge(
            from_asset(policy_id, "buidlers_fest_shirt", 1),
            from_lovelace(1000000),
          ),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      extra_signatories: [owner],
    }

  social_hub.social_hub.spend(
    Some(initial_datum),
    redeemer,
    output_reference,
    transaction,
  )
}

test transfer_social_hub() {
  let policy_id = #"f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"
  let owner = #"68182d17a7d772dfb4a260b46fc29a63bfa2a061603ff128fe9a0680"
  let new_owner = #"ed31457d4143f5c95fd132e0bda6c4696d20a80e19b47fdfe9063ce2"
  let redeemer = Transfer

  let output_reference =
    OutputReference {
      transaction_id: #"6fb60aba11635cfab24f735f60cdf06238a0ca7590eff8a410e33c107694eddd",
      output_index: 0,
    }

  let initial_datum =
    SocialHubDatum {
      owner,
      batch_id: #"01a2",
      picture: Some("github"),
      name: Some("Jane Doe"),
      subtitle: Some("Software Engineer"),
      x: Some("long_hair"),
      telegram: Some("lOnG_hAiR1234"),
      instagram: Some("my_long_hair"),
      discord: Some("long_hair#1234"),
      reddit: Some("long_hair"),
      youtube: Some("long_hair_channel"),
      linkedin: Some("mr_serious_business"),
      github: Some("coding_with_long_hair"),
      website: Some("https://hairstyle-dev.com"),
      adahandle: Some("long_hair"),
      email: None,
    }

  let datum = SocialHubDatum { ..initial_datum, owner: new_owner }

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
            value: from_asset(policy_id, "buidlers_fest_shirt", 1),
            datum: InlineDatum(initial_datum),
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
          value: merge(
            from_asset(policy_id, "buidlers_fest_shirt", 1),
            from_lovelace(1000000),
          ),
          datum: InlineDatum(datum),
          reference_script: None,
        },
      ],
      extra_signatories: [owner],
    }

  social_hub.social_hub.spend(
    Some(initial_datum),
    redeemer,
    output_reference,
    transaction,
  )
}

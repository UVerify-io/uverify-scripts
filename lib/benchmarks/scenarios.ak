use aiken/collection/list
use aiken/crypto.{sha2_256}
use aiken/primitive/bytearray
use aiken/primitive/string
use cardano/address.{from_script, from_verification_key}
use cardano/assets.{PolicyId, from_asset, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, Transaction, placeholder,
}
use common.{certificates_to_bytearray}
use mocktail/virgin_key_hash.{mock_policy_id, mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use mocktail/virgin_validity_range.{mock_interval}
use types.{
  BootstrapDatum, MINT_STATE, StateDatum, UPDATE_STATE, UVerifyCertificate,
  UVerifyStateRedeemer,
}

pub type BenchScenario {
  policy_id: PolicyId,
  redeemer: UVerifyStateRedeemer,
  transaction: Transaction,
}

const bootstrap_token_name = #"6461746166726f73745f76305f305f32"

const certificate_hash =
  #"a601a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"

// batch_size must stay above the largest sweep count (max-size 30 -> 31 certificates)
const bench_batch_size = 100

fn bench_user_credential() {
  mock_pub_key_hash(3)
}

pub fn standard_extra() -> List<String> {
  [
    @"{\"uverify_template_id\":\"default\",\"title\":\"Certificate of Completion\",\"issuer_name\":\"UVerify Benchmarks\",\"language\":\"en\"}",
  ]
}

pub fn rich_extra() -> List<String> {
  [
    @"{\"uverify_template_id\":\"digitalProductPassport\",\"product_name\":\"EcoCharge Pro Wireless Charging Station\",\"manufacturer\":\"GreenTech Solutions AG\",\"manufacturer_address\":\"Industriestrasse 42, 8304 Wallisellen, Switzerland\",\"gtin\":\"04012345678901\",\"serial_number\":\"EC200-2024-SN-0084731\",\"model\":\"EC200\",\"production_date\":\"2024-03-15\",\"production_site\":\"Plant 2, Rotkreuz, Switzerland\",\"weight_grams\":\"412\",\"dimensions_mm\":\"120x120x18\",\"color\":\"graphite\",\"warranty_months\":\"36\",",
    @"\"materials\":{\"aluminum_housing\":\"45 percent\",\"recycled_abs_plastic\":\"38 percent\",\"copper_coil\":\"9 percent\",\"neodymium_magnets\":\"3 percent\",\"silicone_pad\":\"2 percent\",\"other_components\":\"3 percent\"},\"recycled_content_total\":\"41 percent\",\"hazardous_substances\":\"none above regulatory threshold\",\"reach_svhc_declaration\":\"no substances of very high concern present\",\"rohs_status\":\"compliant\",\"battery_included\":\"false\",\"repairability_index\":\"8.1 of 10\",\"spare_parts_available_until\":\"2032-03-15\",",
    @"\"certifications\":{\"ce\":\"CE Marking 2014-30-EU\",\"fcc\":\"FCC Part 15 Class B\",\"qi\":\"Qi v2.0 Certified WPC-2024-8841\",\"energy_star\":\"not applicable\"},\"sustainability\":{\"carbon_footprint_kg_co2e\":\"14.2\",\"energy_efficiency_class\":\"A\",\"recyclability_rate\":\"87 percent\",\"packaging\":\"FSC certified cardboard, plastic free\"},\"end_of_life\":{\"disposal\":\"WEEE collection point\",\"disassembly_manual\":\"https://greentech.example/ec200/disassembly\"},\"notes\":\"Digital product passport issued under EU ESPR pilot program batch 7\"}",
  ]
}

pub fn make_certificates(
  count: Int,
  extra: List<String>,
) -> List<UVerifyCertificate> {
  list.map(
    list.range(1, count),
    fn(_index) {
      UVerifyCertificate {
        hash: certificate_hash,
        algorithm: @"SHA-256",
        issuer: bench_user_credential(),
        extra,
      }
    },
  )
}

pub fn mint_state_scenario(
  certificates: List<UVerifyCertificate>,
) -> BenchScenario {
  let user_credential = bench_user_credential()
  let policy_id = mock_policy_id(1)

  let bootstrap_datum = BootstrapDatum {
    allowed_credentials: [],
    token_name: bootstrap_token_name,
    fee: 0,
    fee_interval: 0,
    fee_receivers: [],
    ttl: 1833689900000,
    transaction_limit: 1000,
    batch_size: bench_batch_size,
  }

  let utxo = mock_utxo_ref(1, 0)
  let state_id = sha2_256(
    bytearray.concat(
      left: utxo.transaction_id,
      right: bytearray.from_int_little_endian(0, 2),
    ),
  )

  let state_datum = StateDatum {
    id: state_id,
    owner: user_credential,
    fee: 0,
    fee_interval: 0,
    fee_receivers: [],
    ttl: 1833689900000,
    countdown: 999,
    batch_size: bench_batch_size,
    keep_as_oracle: False,
    certificate_data_hash: sha2_256(certificates_to_bytearray(certificates)),
    bootstrap_datum_name: bootstrap_token_name,
  }

  let transaction = Transaction {
    ..placeholder,
    inputs: [
      Input {
        output: Output {
          address: from_verification_key(user_credential),
          value: from_lovelace(2000000),
          datum: NoDatum,
          reference_script: None,
        },
        output_reference: utxo,
      },
    ],
    outputs: [
      Output {
        address: from_script(mock_policy_id(1)),
        value: from_asset(policy_id, state_id, 1),
        datum: InlineDatum(state_datum),
        reference_script: None,
      },
    ],
    mint: from_asset(policy_id, state_id, 1),
    extra_signatories: [user_credential],
    reference_inputs: [
      Input {
        output: Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, bootstrap_token_name, 1),
          datum: InlineDatum(bootstrap_datum),
          reference_script: None,
        },
        output_reference: mock_utxo_ref(2, 0),
      },
    ],
    validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
  }

  BenchScenario {
    policy_id,
    redeemer: UVerifyStateRedeemer { purpose: MINT_STATE, certificates },
    transaction,
  }
}

pub fn update_state_scenario(
  certificates: List<UVerifyCertificate>,
) -> BenchScenario {
  let user_credential = bench_user_credential()
  let policy_id = mock_policy_id(1)

  let utxo = mock_utxo_ref(1, 0)
  let state_id = sha2_256(
    bytearray.concat(
      left: utxo.transaction_id,
      right: bytearray.from_int_little_endian(0, 2),
    ),
  )

  let current_state_datum = StateDatum {
    id: state_id,
    owner: user_credential,
    fee: 0,
    fee_interval: 0,
    fee_receivers: [],
    ttl: 1833689900000,
    countdown: 999,
    batch_size: bench_batch_size,
    keep_as_oracle: False,
    certificate_data_hash: #"0000000000000000000000000000000000000000000000000000000000000000",
    bootstrap_datum_name: bootstrap_token_name,
  }

  let next_state_datum = StateDatum {
    ..current_state_datum,
    countdown: 998,
    certificate_data_hash: sha2_256(certificates_to_bytearray(certificates)),
  }

  let transaction = Transaction {
    ..placeholder,
    inputs: [
      Input(
        mock_utxo_ref(2, 1),
        Output {
          address: from_script(mock_policy_id(1)),
          value: from_asset(policy_id, state_id, 1),
          datum: InlineDatum(current_state_datum),
          reference_script: None,
        },
      ),
    ],
    outputs: [
      Output {
        datum: InlineDatum(next_state_datum),
        value: from_asset(policy_id, state_id, 1),
        address: from_script(mock_policy_id(1)),
        reference_script: None,
      },
    ],
    extra_signatories: [user_credential],
    validity_range: mock_interval(Some(1756203803000), Some(1756203804000)),
  }

  BenchScenario {
    policy_id,
    redeemer: UVerifyStateRedeemer { purpose: UPDATE_STATE, certificates },
    transaction,
  }
}

fn extra_byte_length(extra: List<String>) -> Int {
  list.reduce(
    extra,
    0,
    fn(total, part) { total + bytearray.length(string.to_bytearray(part)) },
  )
}

test standard_extra_has_realistic_size() {
  let size = extra_byte_length(standard_extra())
  and {
    size >= 100,
    size <= 160,
  }
}

test rich_extra_has_realistic_size() {
  let size = extra_byte_length(rich_extra())
  and {
    size >= 1300,
    size <= 1700,
  }
}

test make_certificates_returns_requested_count() {
  list.length(make_certificates(5, standard_extra())) == 5
}

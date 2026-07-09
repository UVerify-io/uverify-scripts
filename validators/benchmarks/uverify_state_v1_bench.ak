use benchmarks/scenarios.{
  BenchScenario, make_certificates, mint_state_scenario, rich_extra,
  standard_extra, update_state_scenario,
}
use mocktail/virgin_address.{mock_script_credential}
use uverify_v1

fn run_v1(scenario: BenchScenario) -> Bool {
  uverify_v1.uverify_state.withdraw(
    scenario.policy_id,
    "test_proxy_token",
    scenario.redeemer,
    mock_script_credential(0),
    scenario.transaction,
  )
}

// Maps bench size n to n + 1 certificates, so size 0 measures a single certificate
fn certificate_count_sampler() -> Sampler<Int> {
  fn(n: Int) { fn(prng: PRNG) { Some((prng, n + 1)) } }
}

test bench_v1_mint_standard_single() {
  run_v1(mint_state_scenario(make_certificates(1, standard_extra())))
}

test bench_v1_mint_standard_batch_5() {
  run_v1(mint_state_scenario(make_certificates(5, standard_extra())))
}

test bench_v1_mint_standard_batch_10() {
  run_v1(mint_state_scenario(make_certificates(10, standard_extra())))
}

test bench_v1_mint_rich_single() {
  run_v1(mint_state_scenario(make_certificates(1, rich_extra())))
}

test bench_v1_mint_rich_batch_5() {
  run_v1(mint_state_scenario(make_certificates(5, rich_extra())))
}

test bench_v1_mint_rich_batch_10() {
  run_v1(mint_state_scenario(make_certificates(10, rich_extra())))
}

test bench_v1_update_standard_single() {
  run_v1(update_state_scenario(make_certificates(1, standard_extra())))
}

test bench_v1_update_standard_batch_5() {
  run_v1(update_state_scenario(make_certificates(5, standard_extra())))
}

test bench_v1_update_standard_batch_10() {
  run_v1(update_state_scenario(make_certificates(10, standard_extra())))
}

test bench_v1_update_rich_single() {
  run_v1(update_state_scenario(make_certificates(1, rich_extra())))
}

test bench_v1_update_rich_batch_5() {
  run_v1(update_state_scenario(make_certificates(5, rich_extra())))
}

test bench_v1_update_rich_batch_10() {
  run_v1(update_state_scenario(make_certificates(10, rich_extra())))
}

bench bench_v1_mint_standard_sweep(count via certificate_count_sampler()) {
  run_v1(mint_state_scenario(make_certificates(count, standard_extra())))
}

bench bench_v1_mint_rich_sweep(count via certificate_count_sampler()) {
  run_v1(mint_state_scenario(make_certificates(count, rich_extra())))
}

bench bench_v1_update_standard_sweep(count via certificate_count_sampler()) {
  run_v1(update_state_scenario(make_certificates(count, standard_extra())))
}

bench bench_v1_update_rich_sweep(count via certificate_count_sampler()) {
  run_v1(update_state_scenario(make_certificates(count, rich_extra())))
}

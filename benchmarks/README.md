# Validator Benchmarks

Measures mem units, cpu steps, and a rough fee estimate for the `uverify_state`
validator across representative certificate workloads. Guards against cost
regressions when upgrading Aiken or changing validator rules.

## Usage

Requires [Deno](https://deno.land) and the Aiken version pinned in
`.github/workflows/test.yml`.

    deno run -A benchmarks/run.ts                    # measure and print the table
    deno run -A benchmarks/run.ts --check            # compare against baseline.json, exit 1 on regression
    deno run -A benchmarks/run.ts --update-baseline  # rewrite the baseline for the versions that ran
    deno run -A benchmarks/run.ts --version v1       # restrict to one validator version
    deno test -A benchmarks/                         # runner unit tests

## Scenarios

Two payload presets frozen in `lib/benchmarks/scenarios.ak`:

| Preset | Extra metadata | Modeled after |
|---|---|---|
| standard | 120 bytes | default template payload |
| rich | 1479 bytes | digital product passport payload |

Fixed scenarios run 1, 5, and 10 certificates per transaction on the
MINT_STATE and UPDATE_STATE paths. Sweeps sample 1 through 31 certificates
and report the batch ceiling, the largest batch that fits the mainnet
budget (14M mem, 10G cpu steps, 16384 bytes tx size).

## What the numbers mean

The measurements run the validator against an in-script mock transaction.
They exclude ScriptContext deserialization, which a real node pays, so
absolute values sit below on-chain ExUnits. Treat them as a consistent
regression signal, not ground truth.

The fee column is an estimate:
`txFeeFixed + txFeePerByte * estimatedTxSize + priceMem * mem + priceStep * cpu`
with an assumed fixed transaction overhead (`txSize.overheadBytes` in
`config.json`). It tracks relative change well and absolute cost roughly.

## Updating the baseline

`baseline.json` is committed. CI fails when mem or cpu regresses more than
`tolerancePercent` (default 5) or a batch ceiling drops. For an intentional
change (new validator rule, Aiken upgrade):

1. Run `deno run -A benchmarks/run.ts --check` and review the delta table.
2. Run `deno run -A benchmarks/run.ts --update-baseline`.
3. Commit `baseline.json` in the same pull request as the change, so the
   cost delta is visible in review.

## Adding a validator version

1. Create `validators/benchmarks/uverify_state_v2_bench.ak` mirroring the
   v1 module, importing the shared scenarios and calling the v2 handler.
   Name every block with the `bench_v2_` prefix.
2. Run `deno run -A benchmarks/run.ts --update-baseline --version v2`.
3. Commit the new module and the baseline.

The runner discovers versions from the `bench_v<n>_` prefix. No runner
changes are needed.

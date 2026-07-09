import { dirname, fromFileUrl, join } from "jsr:@std/path@1";
import { parseBenchOutput, parseCheckOutput } from "./lib/parse.ts";
import {
  estimateFeeLovelace,
  estimateTxSizeBytes,
  type FeeParams,
  type TxSizeModel,
} from "./lib/fee.ts";
import { type Budget, computeCeiling } from "./lib/ceiling.ts";
import {
  type BenchmarkResults,
  compareResults,
  renderSummaryTable,
  type VersionResults,
} from "./lib/compare.ts";

interface Config {
  tolerancePercent: number;
  maxSweepSize: number;
  budget: Budget;
  feeParams: FeeParams;
  txSize: TxSizeModel;
}

const benchmarksDir = dirname(fromFileUrl(import.meta.url));
const repoRoot = dirname(benchmarksDir);
const baselinePath = join(benchmarksDir, "baseline.json");
const resultsPath = join(benchmarksDir, "results.json");

function exitWith(message: string): never {
  console.error(message);
  Deno.exit(1);
}

function parseArgs(args: string[]): {
  mode: "measure" | "check" | "update-baseline";
  versions: string[];
} {
  const versions: string[] = [];
  let mode: "measure" | "check" | "update-baseline" = "measure";
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--check") mode = "check";
    else if (arg === "--update-baseline") mode = "update-baseline";
    else if (arg === "--version") {
      const value = args[++i];
      if (!value || !/^v\d+$/.test(value)) {
        exitWith(
          `--version expects a value like v1, got: ${value ?? "nothing"}`,
        );
      }
      versions.push(value);
    } else exitWith(`Unknown argument: ${arg}`);
  }
  return { mode, versions };
}

async function runAiken(args: string[]): Promise<string> {
  const command = new Deno.Command("aiken", {
    args,
    cwd: repoRoot,
    stdout: "piped",
    stderr: "piped",
  });
  const output = await command.output();
  const stdout = new TextDecoder().decode(output.stdout);
  const stderr = new TextDecoder().decode(output.stderr);
  if (output.code !== 0) {
    exitWith(`aiken ${args.join(" ")} failed:\n${stderr}\n${stdout}`);
  }
  return stdout;
}

async function readBaseline(): Promise<BenchmarkResults | null> {
  try {
    return JSON.parse(await Deno.readTextFile(baselinePath));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return null;
    throw error;
  }
}

const config: Config = JSON.parse(
  await Deno.readTextFile(join(benchmarksDir, "config.json")),
);
const { mode, versions } = parseArgs(Deno.args);

const matchPrefix = versions.length === 1 ? `bench_${versions[0]}` : "bench_";
const checkRaw = await runAiken(["check", "-m", matchPrefix]);
const benchRaw = await runAiken([
  "bench",
  "-m",
  matchPrefix,
  "--max-size",
  String(config.maxSweepSize),
]);
const aikenVersion = (await runAiken(["--version"])).trim();

let scenarioMeasurements = parseCheckOutput(checkRaw);
let sweeps = parseBenchOutput(benchRaw);
if (versions.length > 0) {
  scenarioMeasurements = scenarioMeasurements.filter((m) =>
    versions.includes(m.version)
  );
  sweeps = sweeps.filter((s) => versions.includes(s.version));
}

const results: BenchmarkResults = { aikenVersion, versions: {} };

for (const measurement of scenarioMeasurements) {
  const versionResults: VersionResults = results.versions[
    measurement.version
  ] ??= { scenarios: {}, sweeps: {} };
  const preset = measurement.scenario.split("_")[0];
  const batchMatch = /batch_(\d+)$/.exec(measurement.scenario);
  const count = batchMatch ? Number(batchMatch[1]) : 1;
  const txSizeBytes = estimateTxSizeBytes(config.txSize, preset, count);
  const feeLovelace = estimateFeeLovelace(
    config.feeParams,
    txSizeBytes,
    measurement.mem,
    measurement.cpu,
  );
  versionResults.scenarios[`${measurement.path}_${measurement.scenario}`] = {
    mem: measurement.mem,
    cpu: measurement.cpu,
    estimatedTxSizeBytes: txSizeBytes,
    estimatedFeeLovelace: feeLovelace,
    estimatedFeeAda: feeLovelace / 1_000_000,
  };
}

for (const sweep of sweeps) {
  const versionResults: VersionResults = results.versions[sweep.version] ??= {
    scenarios: {},
    sweeps: {},
  };
  versionResults.sweeps[`${sweep.path}_${sweep.preset}`] = {
    points: sweep.points,
    ceiling: computeCeiling(
      sweep.points,
      config.budget,
      (count) => estimateTxSizeBytes(config.txSize, sweep.preset, count),
    ),
  };
}

await Deno.writeTextFile(resultsPath, JSON.stringify(results, null, 2) + "\n");

if (mode === "update-baseline") {
  const baseline = await readBaseline() ?? { aikenVersion, versions: {} };
  baseline.aikenVersion = aikenVersion;
  for (const [version, versionResults] of Object.entries(results.versions)) {
    baseline.versions[version] = versionResults;
  }
  await Deno.writeTextFile(
    baselinePath,
    JSON.stringify(baseline, null, 2) + "\n",
  );
  console.log(
    `Baseline updated for: ${Object.keys(results.versions).join(", ")}`,
  );
} else if (mode === "check") {
  const baseline = await readBaseline();
  if (!baseline) {
    exitWith("No baseline.json found. Run with --update-baseline first.");
  }
  const errors = compareResults(
    baseline,
    results,
    config.tolerancePercent,
    versions,
  );
  const summary = renderSummaryTable(baseline, results);
  console.log(summary);
  const summaryFile = Deno.env.get("GITHUB_STEP_SUMMARY");
  if (summaryFile) {
    await Deno.writeTextFile(summaryFile, summary + "\n", { append: true });
  }
  if (errors.length > 0) {
    console.error("\nRegression check failed:");
    for (const error of errors) console.error(`  - ${error}`);
    Deno.exit(1);
  }
  console.log("\nRegression check passed.");
} else {
  console.log(renderSummaryTable(await readBaseline(), results));
}

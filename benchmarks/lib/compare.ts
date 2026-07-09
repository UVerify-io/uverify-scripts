import type { SweepPoint } from "./parse.ts";
import type { Ceiling } from "./ceiling.ts";

export interface ScenarioResult {
  mem: number;
  cpu: number;
  estimatedTxSizeBytes: number;
  estimatedFeeLovelace: number;
  estimatedFeeAda: number;
}

export interface SweepResult {
  points: SweepPoint[];
  ceiling: Ceiling;
}

export interface VersionResults {
  scenarios: Record<string, ScenarioResult>;
  sweeps: Record<string, SweepResult>;
}

export interface BenchmarkResults {
  aikenVersion: string;
  versions: Record<string, VersionResults>;
}

export function compareResults(
  baseline: BenchmarkResults,
  current: BenchmarkResults,
  tolerancePercent: number,
  versionFilter: string[],
): string[] {
  const errors: string[] = [];
  const versions = Object.keys(baseline.versions).filter(
    (version) => versionFilter.length === 0 || versionFilter.includes(version),
  );
  for (const version of versions) {
    const baselineVersion = baseline.versions[version];
    const currentVersion = current.versions[version];
    if (!currentVersion) {
      errors.push(
        `${version}: present in the baseline but produced no results.`,
      );
      continue;
    }
    for (const [name, base] of Object.entries(baselineVersion.scenarios)) {
      const now = currentVersion.scenarios[name];
      if (!now) {
        errors.push(
          `${version}/${name}: scenario missing from results (renamed or deleted test?).`,
        );
        continue;
      }
      for (const metric of ["mem", "cpu"] as const) {
        const limit = base[metric] * (1 + tolerancePercent / 100);
        if (now[metric] > limit) {
          const delta = ((now[metric] - base[metric]) / base[metric] * 100)
            .toFixed(1);
          errors.push(
            `${version}/${name}: ${metric} regressed ${delta}% ` +
              `(${base[metric]} -> ${now[metric]}, tolerance ${tolerancePercent}%).`,
          );
        }
      }
    }
    for (const [name, base] of Object.entries(baselineVersion.sweeps)) {
      const now = currentVersion.sweeps[name];
      if (!now) {
        errors.push(`${version}/${name}: sweep missing from results.`);
        continue;
      }
      const baseFloor = base.ceiling.saturated ? Infinity : base.ceiling.value;
      const nowFloor = now.ceiling.saturated ? Infinity : now.ceiling.value;
      if (nowFloor < baseFloor) {
        errors.push(
          `${version}/${name}: batch ceiling dropped ` +
            `(${describeCeiling(base.ceiling)} -> ${
              describeCeiling(now.ceiling)
            }).`,
        );
      }
    }
  }
  return errors;
}

export function describeCeiling(ceiling: Ceiling): string {
  return ceiling.saturated ? `>=${ceiling.value}` : `${ceiling.value}`;
}

export function renderSummaryTable(
  baseline: BenchmarkResults | null,
  current: BenchmarkResults,
): string {
  const lines: string[] = [];
  for (const [version, results] of Object.entries(current.versions)) {
    lines.push(`### ${version} (aiken ${current.aikenVersion})`, "");
    lines.push("| Scenario | Mem | Δ Mem | CPU | Δ CPU | Fee est. (ADA) |");
    lines.push("|---|---|---|---|---|---|");
    for (const [name, scenario] of Object.entries(results.scenarios)) {
      const base = baseline?.versions[version]?.scenarios[name];
      lines.push(
        `| ${name} | ${scenario.mem} | ${delta(base?.mem, scenario.mem)} ` +
          `| ${scenario.cpu} | ${delta(base?.cpu, scenario.cpu)} ` +
          `| ${scenario.estimatedFeeAda.toFixed(6)} |`,
      );
    }
    lines.push("", "| Sweep | Batch ceiling |", "|---|---|");
    for (const [name, sweep] of Object.entries(results.sweeps)) {
      lines.push(`| ${name} | ${describeCeiling(sweep.ceiling)} |`);
    }
    lines.push("");
  }
  return lines.join("\n");
}

function delta(base: number | undefined, current: number): string {
  if (base === undefined || base === 0) return "n/a";
  const percent = (current - base) / base * 100;
  return `${percent >= 0 ? "+" : ""}${percent.toFixed(1)}%`;
}

export interface ScenarioMeasurement {
  version: string;
  path: string;
  scenario: string;
  mem: number;
  cpu: number;
}

export interface SweepPoint {
  count: number;
  mem: number;
  cpu: number;
}

export interface Sweep {
  version: string;
  path: string;
  preset: string;
  points: SweepPoint[];
}

const TEST_NAME = /^bench_(v\d+)_(mint|update)_(.+)$/;
const BENCH_NAME = /^bench_(v\d+)_(mint|update)_([a-z0-9]+)_sweep$/;

export function parseCheckOutput(raw: string): ScenarioMeasurement[] {
  const data = parseJson(raw, "aiken check");
  const measurements: ScenarioMeasurement[] = [];
  for (const module of data.modules ?? []) {
    for (const test of module.tests ?? []) {
      const match = TEST_NAME.exec(test.title);
      if (!match) continue;
      if (test.status !== "pass") {
        throw new Error(
          `Benchmark test ${test.title} failed. Fix the scenario before measuring.`,
        );
      }
      measurements.push({
        version: match[1],
        path: match[2],
        scenario: match[3],
        mem: test.execution_units.mem,
        cpu: test.execution_units.cpu,
      });
    }
  }
  if (measurements.length === 0) {
    throw new Error(
      `No bench_ tests found in aiken check output:\n${raw.slice(0, 2000)}`,
    );
  }
  return measurements;
}

export function parseBenchOutput(raw: string): Sweep[] {
  const data = parseJson(raw, "aiken bench");
  const sweeps: Sweep[] = [];
  for (const benchmark of data.benchmarks ?? []) {
    const match = BENCH_NAME.exec(benchmark.name);
    if (!match) continue;
    sweeps.push({
      version: match[1],
      path: match[2],
      preset: match[3],
      points: benchmark.measures.map(
        (measure: { size: number; memory: number; cpu: number }) => ({
          count: measure.size + 1,
          mem: measure.memory,
          cpu: measure.cpu,
        }),
      ),
    });
  }
  if (sweeps.length === 0) {
    throw new Error(
      `No bench_ sweeps found in aiken bench output:\n${raw.slice(0, 2000)}`,
    );
  }
  return sweeps;
}

// deno-lint-ignore no-explicit-any
function parseJson(raw: string, source: string): any {
  try {
    return JSON.parse(raw);
  } catch {
    throw new Error(
      `${source} did not produce JSON output:\n${raw.slice(0, 2000)}`,
    );
  }
}

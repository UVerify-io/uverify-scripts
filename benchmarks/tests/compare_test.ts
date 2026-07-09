import { assertEquals } from "jsr:@std/assert@1";
import {
  type BenchmarkResults,
  compareResults,
  describeCeiling,
  renderSummaryTable,
} from "../lib/compare.ts";

function makeResults(
  mem: number,
  cpu: number,
  ceiling: { value: number; saturated: boolean },
): BenchmarkResults {
  return {
    aikenVersion: "v1.1.17+c3a7fba",
    versions: {
      v1: {
        scenarios: {
          mint_standard_single: {
            mem,
            cpu,
            estimatedTxSizeBytes: 1700,
            estimatedFeeLovelace: 250000,
            estimatedFeeAda: 0.25,
          },
        },
        sweeps: {
          mint_standard: { points: [], ceiling },
        },
      },
    },
  };
}

const baseline = makeResults(100000, 1000000, { value: 30, saturated: true });

Deno.test("compareResults passes within tolerance", () => {
  const current = makeResults(104000, 1040000, { value: 30, saturated: true });
  assertEquals(compareResults(baseline, current, 5, []), []);
});

Deno.test("compareResults flags mem regression beyond tolerance", () => {
  const current = makeResults(106000, 1000000, { value: 30, saturated: true });
  const errors = compareResults(baseline, current, 5, []);
  assertEquals(errors.length, 1);
  if (!errors[0].includes("mem regressed")) {
    throw new Error(`unexpected message: ${errors[0]}`);
  }
});

Deno.test("compareResults flags a batch ceiling drop", () => {
  const current = makeResults(100000, 1000000, { value: 25, saturated: false });
  const errors = compareResults(baseline, current, 5, []);
  assertEquals(errors.length, 1);
  if (!errors[0].includes("ceiling dropped")) {
    throw new Error(`unexpected message: ${errors[0]}`);
  }
});

Deno.test("compareResults flags a missing scenario", () => {
  const current = makeResults(100000, 1000000, { value: 30, saturated: true });
  current.versions.v1.scenarios = {};
  const errors = compareResults(baseline, current, 5, []);
  assertEquals(errors.length, 1);
  if (!errors[0].includes("missing")) {
    throw new Error(`unexpected message: ${errors[0]}`);
  }
});

Deno.test("compareResults flags a missing version", () => {
  const current = makeResults(100000, 1000000, { value: 30, saturated: true });
  current.versions = {};
  const errors = compareResults(baseline, current, 5, []);
  assertEquals(errors.length, 1);
});

Deno.test("compareResults respects the version filter", () => {
  const current = makeResults(999999999, 999999999, {
    value: 1,
    saturated: false,
  });
  assertEquals(compareResults(baseline, current, 5, ["v2"]), []);
});

Deno.test("describeCeiling marks saturated ceilings as lower bounds", () => {
  assertEquals(describeCeiling({ value: 31, saturated: true }), ">=31");
  assertEquals(describeCeiling({ value: 12, saturated: false }), "12");
});

Deno.test("renderSummaryTable includes scenarios, deltas, and ceilings", () => {
  const current = makeResults(110000, 1000000, { value: 30, saturated: true });
  const table = renderSummaryTable(baseline, current);
  if (!table.includes("mint_standard_single")) {
    throw new Error("scenario row missing");
  }
  if (!table.includes("+10.0%")) throw new Error("delta missing");
  if (!table.includes(">=30")) throw new Error("ceiling missing");
});

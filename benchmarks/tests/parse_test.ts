import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseBenchOutput, parseCheckOutput } from "../lib/parse.ts";

const checkFixture = await Deno.readTextFile(
  new URL("./fixtures/check_v1.json", import.meta.url),
);
const benchFixture = await Deno.readTextFile(
  new URL("./fixtures/bench_v1.json", import.meta.url),
);

Deno.test("parseCheckOutput extracts all 12 v1 scenarios", () => {
  const measurements = parseCheckOutput(checkFixture);
  assertEquals(measurements.length, 12);
  const single = measurements.find(
    (m) => m.path === "mint" && m.scenario === "standard_single",
  );
  if (!single) throw new Error("mint standard_single not found");
  assertEquals(single.version, "v1");
  if (single.mem <= 0 || single.cpu <= 0) {
    throw new Error("expected positive execution units");
  }
});

Deno.test("parseCheckOutput ignores tests without the bench_ prefix", () => {
  const raw = JSON.stringify({
    modules: [
      {
        name: "tests/uverify_state_test",
        tests: [
          {
            title: "should_mint_a_state_token",
            status: "pass",
            execution_units: { mem: 1, cpu: 1 },
          },
          {
            title: "bench_v1_mint_standard_single",
            status: "pass",
            execution_units: { mem: 2, cpu: 3 },
          },
        ],
      },
    ],
  });
  const measurements = parseCheckOutput(raw);
  assertEquals(measurements.length, 1);
  assertEquals(measurements[0].mem, 2);
});

Deno.test("parseCheckOutput throws when a bench test failed", () => {
  const raw = JSON.stringify({
    modules: [
      {
        name: "benchmarks/uverify_state_v1_bench",
        tests: [
          {
            title: "bench_v1_mint_standard_single",
            status: "fail",
            execution_units: { mem: 2, cpu: 3 },
          },
        ],
      },
    ],
  });
  assertThrows(() => parseCheckOutput(raw), Error, "failed");
});

Deno.test("parseCheckOutput throws on non-JSON input", () => {
  assertThrows(
    () => parseCheckOutput("Compiling uverify/validators..."),
    Error,
    "did not produce JSON",
  );
});

Deno.test("parseCheckOutput throws when nothing matches", () => {
  assertThrows(
    () => parseCheckOutput(JSON.stringify({ modules: [] })),
    Error,
    "No bench_",
  );
});

Deno.test("parseBenchOutput extracts sweeps and maps size to count", () => {
  const sweeps = parseBenchOutput(benchFixture);
  assertEquals(sweeps.length, 4);
  const mintStandard = sweeps.find(
    (s) => s.path === "mint" && s.preset === "standard",
  );
  if (!mintStandard) throw new Error("mint standard sweep not found");
  assertEquals(mintStandard.version, "v1");
  assertEquals(mintStandard.points[0].count, 1);
  assertEquals(mintStandard.points.length, 6);
});

Deno.test("parseBenchOutput throws when nothing matches", () => {
  assertThrows(
    () => parseBenchOutput(JSON.stringify({ benchmarks: [] })),
    Error,
    "No bench_",
  );
});

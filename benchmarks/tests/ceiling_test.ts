import { assertEquals } from "jsr:@std/assert@1";
import { computeCeiling } from "../lib/ceiling.ts";

const points = [
  { count: 1, mem: 100, cpu: 1000 },
  { count: 2, mem: 200, cpu: 2000 },
  { count: 3, mem: 900, cpu: 9000 },
];

Deno.test("computeCeiling returns the largest fitting count", () => {
  const budget = { maxMem: 500, maxCpu: 100000, maxTxSizeBytes: 16384 };
  assertEquals(computeCeiling(points, budget, () => 100), {
    value: 2,
    saturated: false,
  });
});

Deno.test("computeCeiling reports saturation when every sample fits", () => {
  const budget = { maxMem: 10000, maxCpu: 100000, maxTxSizeBytes: 16384 };
  assertEquals(computeCeiling(points, budget, () => 100), {
    value: 3,
    saturated: true,
  });
});

Deno.test("computeCeiling applies the transaction size limit", () => {
  const budget = { maxMem: 10000, maxCpu: 100000, maxTxSizeBytes: 16384 };
  assertEquals(computeCeiling(points, budget, (count) => count * 8000), {
    value: 2,
    saturated: false,
  });
});

Deno.test("computeCeiling handles an empty sweep", () => {
  const budget = { maxMem: 10000, maxCpu: 100000, maxTxSizeBytes: 16384 };
  assertEquals(computeCeiling([], budget, () => 100), {
    value: 0,
    saturated: false,
  });
});

import type { SweepPoint } from "./parse.ts";

export interface Budget {
  maxMem: number;
  maxCpu: number;
  maxTxSizeBytes: number;
}

export interface Ceiling {
  value: number;
  saturated: boolean;
}

export function computeCeiling(
  points: SweepPoint[],
  budget: Budget,
  txSizeForCount: (count: number) => number,
): Ceiling {
  const sorted = [...points].sort((a, b) => a.count - b.count);
  let value = 0;
  let saturated = sorted.length > 0;
  for (const point of sorted) {
    const fits = point.mem <= budget.maxMem &&
      point.cpu <= budget.maxCpu &&
      txSizeForCount(point.count) <= budget.maxTxSizeBytes;
    if (!fits) {
      saturated = false;
      break;
    }
    value = point.count;
  }
  return { value, saturated };
}

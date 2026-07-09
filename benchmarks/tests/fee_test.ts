import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { estimateFeeLovelace, estimateTxSizeBytes } from "../lib/fee.ts";

Deno.test("estimateTxSizeBytes adds overhead plus per-certificate bytes", () => {
  const model = {
    overheadBytes: 1000,
    certificateOverheadBytes: 10,
    presetExtraBytes: { standard: 100 },
  };
  // per certificate: 32 hash + 7 algorithm + 28 issuer + 100 extra + 10 framing = 177
  assertEquals(estimateTxSizeBytes(model, "standard", 1), 1177);
  assertEquals(estimateTxSizeBytes(model, "standard", 5), 1885);
});

Deno.test("estimateTxSizeBytes rejects unknown presets", () => {
  const model = {
    overheadBytes: 1000,
    certificateOverheadBytes: 10,
    presetExtraBytes: { standard: 100 },
  };
  assertThrows(() => estimateTxSizeBytes(model, "luxurious", 1), Error, "preset");
});

Deno.test("estimateFeeLovelace applies the mainnet formula and rounds up", () => {
  const params = {
    txFeeFixed: 155381,
    txFeePerByte: 44,
    priceMem: 0.0577,
    priceStep: 0.0000721,
  };
  // 155381 + 44 * 2000 + 0.0577 * 400000 + 0.0000721 * 150000000
  // = 155381 + 88000 + 23080 + 10815 = 277276
  assertEquals(estimateFeeLovelace(params, 2000, 400000, 150000000), 277276);
});

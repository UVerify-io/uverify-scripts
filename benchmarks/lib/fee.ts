export interface FeeParams {
  txFeeFixed: number;
  txFeePerByte: number;
  priceMem: number;
  priceStep: number;
}

export interface TxSizeModel {
  overheadBytes: number;
  certificateOverheadBytes: number;
  presetExtraBytes: Record<string, number>;
}

const HASH_BYTES = 32;
const ALGORITHM_BYTES = 7;
const ISSUER_BYTES = 28;

export function estimateTxSizeBytes(
  model: TxSizeModel,
  preset: string,
  certificateCount: number,
): number {
  const extraBytes = model.presetExtraBytes[preset];
  if (extraBytes === undefined) {
    throw new Error(`Unknown payload preset: ${preset}`);
  }
  const perCertificate = HASH_BYTES + ALGORITHM_BYTES + ISSUER_BYTES +
    extraBytes + model.certificateOverheadBytes;
  return model.overheadBytes + perCertificate * certificateCount;
}

export function estimateFeeLovelace(
  params: FeeParams,
  txSizeBytes: number,
  mem: number,
  cpu: number,
): number {
  return Math.ceil(
    params.txFeeFixed + params.txFeePerByte * txSizeBytes +
      params.priceMem * mem + params.priceStep * cpu,
  );
}

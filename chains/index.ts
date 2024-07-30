import { default as mode } from "./mode";
import { default as base } from "./base";
import { ChainConfig } from "./types";

export { mode, base };

export const chainIdToConfig: { [chainId: number]: ChainConfig } = {
  [mode.chainId]: mode,
  [base.chainId]: base
};

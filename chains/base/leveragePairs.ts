import { Address } from "viem";
import { LeveragePoolConfig } from "../types";

const collaterals: Address[] = [
  "0x079f84161642D81aaFb67966123C9949F9284bf5", // ionezETH
  "0x9D62e30c6cB7964C99314DCf5F847e36Fcb29ca9", // ionwstETH
  "0x9c201024A62466F9157b2dAaDda9326207ADDd29", // ioncbETH
  "0x014e08F05ac11BB532BE62774A4C548368f59779", // ionAERO
  "0xa900A17a49Bc4D442bA7F72c39FA2108865671f0", // ionUSDC
  "0x9c2A4f9c5471fd36bE3BBd8437A33935107215A1", // ionEUSD
  "0x49420311B518f3d0c94e897592014de53831cfA3", // ionWETH
  "0x84341B650598002d427570298564d6701733c805", // ionweETH
  "0x3D9669DE9E3E98DB41A1CbF6dC23446109945E3C" // ionbsdETH
];
const borrows: Address[] = [
  "0xa900A17a49Bc4D442bA7F72c39FA2108865671f0", // ionUSDC
  "0x49420311B518f3d0c94e897592014de53831cfA3", // ionWETH
  "0x9c2A4f9c5471fd36bE3BBd8437A33935107215A1" // ionEUSD
];

const leveragePairs: LeveragePoolConfig[] = [
  {
    pool: "Main" as Address,
    pairs: collaterals.flatMap((collateral) => borrows.map((borrow) => ({ collateral, borrow })))
  }
];

export default leveragePairs;

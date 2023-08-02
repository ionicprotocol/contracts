// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library PrudentiaLib {
  struct PrudentiaConfig {
    address controller; // Adrastia Prudentia controller address
    uint8 offset; // Offset for delayed rate activation
  }
}

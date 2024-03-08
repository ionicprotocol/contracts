// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../BasePriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../ionic/SafeOwnableUpgradeable.sol";

/**
 * @title RedstoneLayerBankPriceOracle
 * @notice Returns prices from Redstone.
 * @dev Implements `BasePriceOracle`.
 * @author Veliko Minkov <v.minkov@dcvx.io> (https://github.com/vminkov)
 */
contract RedstoneLayerBankPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {

  /**
   * @notice Redstone NATIVE/USD price feed contracts.
   */
  address public NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @notice The USD Token of the chain
   */
  address public USD_TOKEN;

  /**
   * @dev Constructor to set admin, wtoken address and native token USD price feed address
   * @param _usdToken The Wrapped native asset address
   * @param nativeTokenUsd Will this oracle return prices denominated in USD or in the native token.
   */
  function initialize(address _usdToken, address nativeTokenUsd) public initializer {
    __SafeOwnable_init(msg.sender);
    USD_TOKEN = _usdToken;
    NATIVE_TOKEN_USD_PRICE_FEED = nativeTokenUsd;
  }


  /**
   * @notice Internal function returning the price in of `underlying`.
   * @dev If the oracle got constructed with `nativeTokenUsd` = TRUE
   * this will return a price denominated in USD otherwise in the native token
   */
  function _price(address underlying) internal view returns (uint256) {
    return 0;
  }


  /**
   * @notice Returns the price in of `underlying` either in the
   * native token (implements `BasePriceOracle`).
   */
  function price(address underlying) external view override returns (uint256) {
    return _price(underlying);
  }


  /**
   * @notice Returns the price in WNATIVE of the token underlying `cToken`.
   * @dev Implements the `BasePriceOracle` interface for Ionic pools (and Compound v2).
   * @return Price in WNATIVE of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICErc20 cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = cToken.underlying();

    uint256 oraclePrice = _price(underlying);

    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
    underlyingDecimals <= 18
    ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
    : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }
}
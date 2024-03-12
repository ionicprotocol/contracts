// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../BasePriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../ionic/SafeOwnableUpgradeable.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface AnkrRatioFeed {
  function getRatioFor(address token) external view returns (uint256);
}

/**
 * @title AnkrRatioPriceOracle
 * @notice Returns prices for bridged Ankr assets.
 * @dev Implements `BasePriceOracle`.
 * @author Veliko Minkov <v.minkov@dcvx.io> (https://github.com/vminkov)
 */
contract AnkrRatioPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  address public ANKR_RATIO_FEED;

  mapping(address => address) public stakedToOriginalAsset;

  /**
   * @dev Initializer to ratio feed address
   */
  function initialize() public initializer {
    __SafeOwnable_init(msg.sender);
    ANKR_RATIO_FEED = 0xEf3C162450E1d08804493aA27BE60CDAa054050F;
  }

  /**
   * @dev Admin-only function to map staked to original assets.
   * @param stakedAssets Underlying token addresses for which to set price feeds.
   * @param originalAssets The Chainlink price feed contract addresses for each of `underlyings`.
   */
  function setStakedAndOriginalAssets(address[] memory stakedAssets, address[] memory originalAssets)
    external
    onlyOwner
  {
    // Input validation
    require(stakedAssets.length > 0 && stakedAssets.length == originalAssets.length, "arr len 0 or diff");

    for (uint256 i = 0; i < stakedAssets.length; i++) {
      stakedToOriginalAsset[stakedAssets[i]] = originalAssets[i];
    }
  }

  /**
   * @notice Internal function returning the price in of `asset`.
   * @dev will return a price denominated in the native token
   */
  function _price(address asset) internal view returns (uint256) {
    address originalAsset = stakedToOriginalAsset[asset];
    uint256 originalAssetPrice = BasePriceOracle(msg.sender).price(originalAsset);
    uint256 ratio = AnkrRatioFeed(ANKR_RATIO_FEED).getRatioFor(asset);

    // e.g. ankrETH/ratio=ETH => ankrETH = ETH * ratio
    // assuming ratio is scaled by 18 decimals
    return (originalAssetPrice * ratio) / 1e18;
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

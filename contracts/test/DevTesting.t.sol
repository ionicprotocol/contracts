// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./config/BaseTest.t.sol";
import { IonicComptroller } from "../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { ISwapRouter } from "../external/uniswap/ISwapRouter.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { PoolLens } from "../PoolLens.sol";
import { PoolLensSecondary } from "../PoolLensSecondary.sol";

contract DevTesting is BaseTest {
  IonicComptroller pool = IonicComptroller(0xFB3323E24743Caf4ADD0fDCCFB268565c0685556);
  PoolLensSecondary lens2 = PoolLensSecondary(0x7Ea7BB80F3bBEE9b52e6Ed3775bA06C9C80D4154);
  PoolLens lens = PoolLens(0x431C87E08e2636733a945D742d25Ba77577ED480);

  address deployer = 0x1155b614971f16758C92c4890eD338C9e3ede6b7;
  ICErc20 wethMarket;
  ICErc20 usdcMarket;
  ICErc20 usdtMarket;
  ICErc20 wbtcMarket;

  // mode mainnet assets
  address WETH = 0x4200000000000000000000000000000000000006;
  address USDC = 0xd988097fb8612cc24eeC14542bC03424c656005f;
  address USDT = 0xf0F161fDA2712DB8b566946122a5af183995e2eD;
  address WBTC = 0xcDd475325D6F564d27247D1DddBb0DAc6fA0a5CF;
  address UNI = 0x3e7eF8f50246f725885102E8238CBba33F276747;
  address SNX = 0x9e5AAC1Ba1a2e6aEd6b32689DFcF62A509Ca96f3;
  address LINK = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
  address DAI = 0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea;
  address BAL = 0xD08a2917653d4E460893203471f0000826fb4034;
  address AAVE = 0x7c6b91D9Be155A6Db01f749217d76fF02A7227F2;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    if (block.chainid == MODE_MAINNET) {
      wethMarket = ICErc20(0x71ef7EDa2Be775E5A7aa8afD02C45F059833e9d2);
      usdcMarket = ICErc20(0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038);
      usdtMarket = ICErc20(0x94812F2eEa03A49869f95e1b5868C6f3206ee3D3);
      wbtcMarket = ICErc20(0xd70254C3baD29504789714A7c69d60Ec1127375C);
    } else {
      ICErc20[] memory markets = pool.getAllMarkets();
      wethMarket = markets[0];
      usdcMarket = markets[1];
    }
  }

  function testModeHealthFactor() public debuggingOnly fork(MODE_MAINNET) {
    address rahul = 0x5A9e792143bf2708b4765C144451dCa54f559a19;

    uint256 wethSupplied = wethMarket.balanceOfUnderlying(rahul);
    uint256 usdcSupplied = usdcMarket.balanceOfUnderlying(rahul);
    uint256 usdtSupplied = usdtMarket.balanceOfUnderlying(rahul);
    uint256 wbtcSupplied = wbtcMarket.balanceOfUnderlying(rahul);
    emit log_named_uint("wethSupplied", wethSupplied);
    emit log_named_uint("usdcSupplied", usdcSupplied);
    emit log_named_uint("usdtSupplied", usdtSupplied);
    emit log_named_uint("wbtcSupplied", wbtcSupplied);
    emit log_named_uint("value of wethSupplied", wethSupplied * pool.oracle().getUnderlyingPrice(wethMarket));
    emit log_named_uint("value of usdcSupplied", usdcSupplied * pool.oracle().getUnderlyingPrice(usdcMarket));
    emit log_named_uint("value of usdtSupplied", usdtSupplied * pool.oracle().getUnderlyingPrice(usdtMarket));
    emit log_named_uint("value of wbtcSupplied", wbtcSupplied * pool.oracle().getUnderlyingPrice(wbtcMarket));

    PoolLens newImpl = new PoolLens();
    //    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(lens)));
    //    vm.prank(dpa.owner());
    //    proxy.upgradeTo(address(newImpl));

    uint256 hf = newImpl.getHealthFactor(rahul, pool);

    emit log_named_uint("hf", hf);
  }

  function testModeMaxBorrow() public debuggingOnly fork(MODE_MAINNET) {
    address user = 0x5A9e792143bf2708b4765C144451dCa54f559a19;
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(user, usdcMarket, true);

    emit log_named_uint("max borrow", maxBorrow);
  }

  function testMarketMember() public debuggingOnly fork(MODE_MAINNET) {
    address rahul = 0x5A9e792143bf2708b4765C144451dCa54f559a19;
    ICErc20[] memory markets = pool.getAllMarkets();

    for (uint256 i = 0; i < markets.length; i++) {
      if (pool.checkMembership(rahul, markets[i])) {
        emit log("is a member");
      } else {
        emit log("NOT a member");
      }
    }
  }

  function testModeRepay() public debuggingOnly fork(MODE_MAINNET) {
    address user = 0x1A3C4E9B49e4fc595fB7e5f723159bA73a9426e7;
    ICErc20 market = usdcMarket;
    ERC20 asset = ERC20(market.underlying());

    uint256 borrowBalance = market.borrowBalanceCurrent(user);
    emit log_named_uint("borrowBalance", borrowBalance);

    vm.startPrank(user);
    asset.approve(address(market), borrowBalance);
    uint256 err = market.repayBorrow(borrowBalance / 2);

    emit log_named_uint("error", err);
  }

  function testAssetsPrices() public debuggingOnly fork(MODE_MAINNET) {
    MasterPriceOracle mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));

    emit log_named_uint("WETH price", mpo.price(WETH));
    emit log_named_uint("USDC price", mpo.price(USDC));
    emit log_named_uint("USDT price", mpo.price(USDT));
    emit log_named_uint("UNI price", mpo.price(UNI));
    emit log_named_uint("SNX price", mpo.price(SNX));
    emit log_named_uint("LINK price", mpo.price(LINK));
    emit log_named_uint("DAI price", mpo.price(DAI));
    emit log_named_uint("BAL price", mpo.price(BAL));
    emit log_named_uint("AAVE price", mpo.price(AAVE));
    emit log_named_uint("WBTC price", mpo.price(WBTC));
  }

  function testDeployedMarkets() public debuggingOnly fork(MODE_MAINNET) {
    ICErc20[] memory markets = pool.getAllMarkets();

    for (uint8 i = 0; i < markets.length; i++) {
      emit log_named_address("market", address(markets[i]));
      emit log(markets[i].symbol());
      emit log(markets[i].name());
    }
  }

  function testDisableCollateralUsdc() public debuggingOnly fork(MODE_MAINNET) {
    address user = 0xF70CBE91fB1b1AfdeB3C45Fb8CDD2E1249b5b75E;
    address usdcMarketAddr = 0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038;

    vm.startPrank(user);

    uint256 borrowed = ICErc20(usdcMarketAddr).borrowBalanceCurrent(user);

    emit log_named_uint("borrowed", borrowed);

    pool.exitMarket(usdcMarketAddr);
  }

  function testAssetAsCollateralCap() public debuggingOnly fork(MODE_MAINNET) {
    pool.getAssetAsCollateralValueCap(wethMarket, usdcMarket, false, deployer);
  }

  function testRegisterSFS() public debuggingOnly fork(MODE_MAINNET) {
    emit log_named_address("pool admin", pool.admin());

    vm.startPrank(0x8Fba84867Ba458E7c6E2c024D2DE3d0b5C3ea1C2);
    pool.registerInSFS();

    ICErc20[] memory markets = pool.getAllMarkets();

    for (uint8 i = 0; i < markets.length; i++) {
      markets[i].registerInSFS();
    }
  }

  function testModeUsdcBorrow() public debuggingOnly fork(MODE_MAINNET) {
    vm.prank(deployer);
    require(usdcMarket.borrow(5e6) == 0, "can't borrow");
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }

  function testRawCall() public debuggingOnly fork(MODE_MAINNET) {
    address caller = 0x1155b614971f16758C92c4890eD338C9e3ede6b7;
    address target = 0x431C87E08e2636733a945D742d25Ba77577ED480;
    bytes memory data = hex"4a5844320000000000000000000000002be717340023c9e14c1bb12cb3ecbcfd3c3fb038";
    vm.prank(caller);
    _functionCall(target, data, "raw call failed");
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./config/BaseTest.t.sol";
import {IonicComptroller} from "../compound/ComptrollerInterface.sol";
import {ComptrollerFirstExtension} from "../compound/ComptrollerFirstExtension.sol";
import {Unitroller} from "../compound/Unitroller.sol";
import {DiamondExtension} from "../ionic/DiamondExtension.sol";
import {ICErc20} from "../compound/CTokenInterfaces.sol";
import {ISwapRouter} from "../external/uniswap/ISwapRouter.sol";
import {MasterPriceOracle} from "../oracles/MasterPriceOracle.sol";
import {BasePriceOracle} from "../oracles/BasePriceOracle.sol";
import {PoolLens} from "../PoolLens.sol";
import {PoolLensSecondary} from "../PoolLensSecondary.sol";
import {JumpRateModel} from "../compound/JumpRateModel.sol";

contract DevTesting is BaseTest {
    IonicComptroller pool = IonicComptroller(0xFB3323E24743Caf4ADD0fDCCFB268565c0685556);
    PoolLensSecondary lens2 = PoolLensSecondary(0x7Ea7BB80F3bBEE9b52e6Ed3775bA06C9C80D4154);
    PoolLens lens = PoolLens(0x431C87E08e2636733a945D742d25Ba77577ED480);

    address deployer = 0x1155b614971f16758C92c4890eD338C9e3ede6b7;
    address multisig = 0x8Fba84867Ba458E7c6E2c024D2DE3d0b5C3ea1C2;

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

    function testModeUsdcBorrowCaps() public debuggingOnly fork(MODE_MAINNET) {
        _testModeBorrowCaps(usdcMarket);
    }

    function testModeUsdtBorrowCaps() public debuggingOnly fork(MODE_MAINNET) {
        _testModeBorrowCaps(usdtMarket);
    }

    function testModeWethBorrowCaps() public debuggingOnly fork(MODE_MAINNET) {
        _testModeBorrowCaps(wethMarket);
        wethMarket.accrueInterest();
        _testModeBorrowCaps(wethMarket);
    }

    function _testModeBorrowCaps(ICErc20 market) internal {
        uint256 borrowCapUsdc = pool.borrowCaps(address(market));
        uint256 totalBorrowsCurrent = market.totalBorrowsCurrent();

        uint256 wethBorrowAmount = 154753148031252;
        console.log("borrowCapUsdc %e", borrowCapUsdc);
        console.log("totalBorrowsCurrent %e", totalBorrowsCurrent);
        console.log("new totalBorrowsCurrent %e", totalBorrowsCurrent + wethBorrowAmount);
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
        address MODE_EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        address ezEthWhale = 0xd3B02d999C681BD8B75F340FA7e078cE9097bF23;

        vm.startPrank(multisig);
        uint256 errCode = pool._deployMarket(
            1, //delegateType
            abi.encode(
                MODE_EZETH,
                address(pool),
                ap.getAddress("FeeDistributor"),
                0x21a455cEd9C79BC523D4E340c2B97521F4217817, // irm - jump rate model on mode
                "Ionic Renzo Restaked ETH",
                "ionezETH",
                0.1e18,
                0.1e18
            ),
            "",
            0.7e18
        );
        vm.stopPrank();
        require(errCode == 0, "error deploying market");

        ICErc20[] memory markets = pool.getAllMarkets();
        ICErc20 ezEthMarket = markets[markets.length - 1];

        //    uint256 cap = pool.getAssetAsCollateralValueCap(ezEthMarket, usdcMarket, false, deployer);
        uint256 cap = pool.supplyCaps(address(ezEthMarket));
        require(cap == 0, "non-zero cap");

        vm.startPrank(ezEthWhale);
        ERC20(MODE_EZETH).approve(address(ezEthMarket), 1e36);
        errCode = ezEthMarket.mint(1e18);
        require(errCode == 0, "should be unable to supply");
    }

    function testRegisterSFS() public debuggingOnly fork(MODE_MAINNET) {
        emit log_named_address("pool admin", pool.admin());

        vm.startPrank(multisig);
        pool.registerInSFS();

        ICErc20[] memory markets = pool.getAllMarkets();

        for (uint8 i = 0; i < markets.length; i++) {
            markets[i].registerInSFS();
        }
    }

    function upgradePool() internal {
        ComptrollerFirstExtension newComptrollerExtension = new ComptrollerFirstExtension();

        Unitroller asUnitroller = Unitroller(payable(address(pool)));

        // upgrade to the new comptroller extension
        vm.startPrank(asUnitroller.admin());
        asUnitroller._registerExtension(newComptrollerExtension, DiamondExtension(asUnitroller._listExtensions()[1]));

        //asUnitroller._upgrade();
        vm.stopPrank();
    }

    function testModeBorrowRate() public fork(MODE_MAINNET) {
        //ICErc20[] memory markets = pool.getAllMarkets();
        ICErc20 ezEthMarket = ICErc20(0x59e710215d45F584f44c0FEe83DA6d43D762D857);

        IonicComptroller pool = ezEthMarket.comptroller();
        vm.prank(pool.admin());
        ezEthMarket._setInterestRateModel(JumpRateModel(0x413aD59b80b1632988d478115a466bdF9B26743a));

        JumpRateModel discRateModel = JumpRateModel(ezEthMarket.interestRateModel());

        uint256 borrows = 200e18;
        uint256 cash = 5000e18 - borrows;
        uint256 reserves = 1e18;
        uint256 rate = discRateModel.getBorrowRate(cash, borrows, reserves);

        emit log_named_uint("rate per year %e", rate * discRateModel.blocksPerYear());
    }

    function testModeFetchBorrowers() public fork(MODE_MAINNET) {
        //    address[] memory borrowers = pool.getAllBorrowers();
        //    emit log_named_uint("borrowers.len", borrowers.length);

        //upgradePool();

        (uint256 totalPages, address[] memory borrowersPage) = pool.getPaginatedBorrowers(1, 0);

        emit log_named_uint("total pages with 300 size (default)", totalPages);

        (totalPages, borrowersPage) = pool.getPaginatedBorrowers(totalPages - 1, 50);
        emit log_named_array("last page of 300 borrowers", borrowersPage);

        (totalPages, borrowersPage) = pool.getPaginatedBorrowers(1, 50);
        emit log_named_uint("total pages with 50 size", totalPages);
        emit log_named_array("page of 50 borrowers", borrowersPage);

        //    for (uint256 i = 0; i < borrowers.length; i++) {
        //      (
        //        uint256 error,
        //        uint256 collateralValue,
        //        uint256 liquidity,
        //        uint256 shortfall
        //      ) = pool.getAccountLiquidity(borrowers[i]);
        //
        //      emit log("");
        //      emit log_named_address("user", borrowers[i]);
        //      emit log_named_uint("collateralValue", collateralValue);
        //      if (liquidity > 0) emit log_named_uint("liquidity", liquidity);
        //      if (shortfall > 0) emit log_named_uint("SHORTFALL", shortfall);
        //    }
    }

    function testModeUsdcBorrow() public debuggingOnly fork(MODE_MAINNET) {
        vm.prank(deployer);
        require(usdcMarket.borrow(5e6) == 0, "can't borrow");
    }

    function testModeDeployMarket() public debuggingOnly fork(MODE_MAINNET) {
        address MODE_WEETH = 0x028227c4dd1e5419d11Bb6fa6e661920c519D4F5;
        address weEthWhale = 0x6e55a90772B92f17f87Be04F9562f3faafd0cc38;

        vm.startPrank(pool.admin());
        uint256 errCode = pool._deployMarket(
            1, //delegateType
            abi.encode(
                MODE_WEETH,
                address(pool),
                ap.getAddress("FeeDistributor"),
                0x21a455cEd9C79BC523D4E340c2B97521F4217817, // irm - jump rate model on mode
                "Ionic Wrapped eETH",
                "ionweETH",
                0.1e18,
                0.1e18
            ),
            "",
            0.7e18
        );
        vm.stopPrank();
        require(errCode == 0, "error deploying market");

        ICErc20[] memory markets = pool.getAllMarkets();
        ICErc20 weEthMarket = markets[markets.length - 1];

        //    uint256 cap = pool.getAssetAsCollateralValueCap(weEthMarket, usdcMarket, false, deployer);
        uint256 cap = pool.supplyCaps(address(weEthMarket));
        require(cap == 0, "non-zero cap");

        vm.startPrank(weEthWhale);
        ERC20(MODE_WEETH).approve(address(weEthMarket), 1e36);
        errCode = weEthMarket.mint(0.01e18);
        require(errCode == 0, "should be unable to supply");
    }

    function testModeUpdateOracle() public debuggingOnly fork(MODE_MAINNET) {
        BasePriceOracle pyth = BasePriceOracle(0x52Ee6E740C1785412e51A381B0d87fb1692a7b23);
        MasterPriceOracle mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
        assertTrue(address(mpo.oracles(USDC)) != address(pyth));
        assertTrue(address(mpo.oracles(USDT)) != address(pyth));
        assertTrue(address(mpo.oracles(WBTC)) != address(pyth));

        uint256 priceUSDC = mpo.price(USDC);
        uint256 priceUSDT = mpo.price(USDT);
        uint256 priceWBTC = mpo.price(WBTC);

        emit log_named_uint("USDC price", mpo.price(USDC));
        emit log_named_uint("USDT price", mpo.price(USDT));
        emit log_named_uint("WBTC price", mpo.price(WBTC));

        address[] memory underlyings = new address[](3);
        underlyings[0] = address(USDC);
        underlyings[1] = address(USDT);
        underlyings[2] = address(WBTC);

        BasePriceOracle[] memory oracles = new BasePriceOracle[](3);
        oracles[0] = pyth;
        oracles[1] = pyth;
        oracles[2] = pyth;
        vm.prank(deployer);
        mpo.add(underlyings, oracles);
        assertEq(address(mpo.oracles(USDC)), address(pyth));
        assertEq(address(mpo.oracles(USDT)), address(pyth));
        assertEq(address(mpo.oracles(WBTC)), address(pyth));

        uint256 priceUSDCNew = mpo.price(USDC);
        uint256 priceUSDTNew = mpo.price(USDT);
        uint256 priceWBTCNew = mpo.price(WBTC);

        assertApproxEqRel(priceUSDCNew, priceUSDC, 0.01 ether);
        assertApproxEqRel(priceUSDTNew, priceUSDT, 0.01 ether);
        assertApproxEqRel(priceWBTCNew, priceWBTC, 0.01 ether);

        emit log_named_uint("USDC price", mpo.price(USDC));
        emit log_named_uint("USDT price", mpo.price(USDT));
        emit log_named_uint("WBTC price", mpo.price(WBTC));
    }

    function _functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
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

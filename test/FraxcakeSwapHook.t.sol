// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
 
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {Constants} from "@pancakeswap/v4-core/test/pool-cl/helpers/Constants.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {LPFeeLibrary} from "@pancakeswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {FraxcakeSwapHook} from "../src/FraxcakeSwapHook.sol";
import {CLTestUtils} from "./pool-cl/utils/CLTestUtils.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLSwapRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLSwapRouterBase.sol";
import {IHooks} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLHooks.sol";
import {SwapFee} from "../src/SwapFee.sol";
import "forge-std/console.sol";
 
contract FraxcakeSwapHookTest is Test, CLTestUtils {
    using PoolIdLibrary for PoolKey;
    using CLPoolParametersHelper for bytes32;
 
    FraxcakeSwapHook hook;
    Currency currency0;
    Currency currency1;
    PoolKey key;
    MockERC20 fraxPoints = new MockERC20("FRXP", "FRXP", 18);
    SwapFee swapFee;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address constant ADDRESS_ZERO = address(0);
    bytes constant ZERO_BYTES = new bytes(0);
    uint256 initialFraxPointsTotalSupply = 2 ether;
 
    function setUp() public {
        // deploy swap fee discount contract
        // 50% discount for fraxPoints holders with balance more than 1/4 of total fraxPoints supply
        // 20% discount for fraxPoints holders with balance more than 1/8 of total fraxPoints supply
        // 10% discount for fraxPoints holders with balance more than 1/32 of total fraxPoints supply
        swapFee = new SwapFee(address(fraxPoints), 4, 8, 32, 5000, 2000, 1000);
        (currency0, currency1) = deployContractsWithTokens();
        hook = new FraxcakeSwapHook(poolManager, address(swapFee));
 
        // create the pool key with a hook
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolManager,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });
 
        // initialize pool at 1:1 price point and set 3000 as initial lp fee, lpFee is stored in the hook
        poolManager.initialize(key, Constants.SQRT_RATIO_1_1, abi.encode(uint24(3000)));
 
        // add deep liquidity so that swap fee discount can be observed
        MockERC20(Currency.unwrap(currency0)).mint(address(this), 100 ether);
        MockERC20(Currency.unwrap(currency1)).mint(address(this), 100 ether);
        addLiquidity(key, 100 ether, 100 ether, -60, 60);
 
        // approve from alice for swap in the test cases below
        vm.startPrank(alice);
        MockERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();

        // Mint fraxPoints to Bob
        fraxPoints.mint(address(bob), initialFraxPointsTotalSupply);
    }
 
    function testNonFraxPointsHolder() public {
        uint256 amtOut = _swap();
 
        console.log("non frax amout out %s", amtOut);
        // amt out be at least 0.15% lesser due to swap fee
        assertLe(amtOut, 0.997 ether);
    }

    function testFraxPointsTier1Holder() public {
        // mint alice fraxPoints for Tier1
        fraxPoints.mint(address(alice), initialFraxPointsTotalSupply);
 
        uint256 amtOut = _swap();

        assertGe(amtOut, 0.9982 ether);
    }

    function testFraxPointsTier2Holder() public {
        // mint alice fraxPoints for Tier2
        fraxPoints.mint(address(alice), initialFraxPointsTotalSupply/4);
 
        uint256 amtOut = _swap();

        assertGe(amtOut, 0.9973 ether);
    }

    function testFraxPointsTier3Holder() public {
        // mint alice fraxPoints for Tier3
        fraxPoints.mint(address(alice), initialFraxPointsTotalSupply/16);
 
        uint256 amtOut = _swap();

        assertGe(amtOut, 0.9970 ether);
    }
 
    function _swap() internal returns (uint256 amtOut) {
        MockERC20(Currency.unwrap(currency0)).mint(address(alice), 10 ether);
 
        // set alice as tx.origin and mint alice token
        vm.prank(address(alice), address(alice));
 
        amtOut = swapRouter.exactInputSingle(
            ICLSwapRouterBase.V4CLExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                recipient: address(alice),
                amountIn: 10 ether,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                hookData: new bytes(0)
            }),
            block.timestamp
        );
    }
}
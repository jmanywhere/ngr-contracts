// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/NGR.sol";

contract CounterTest is Test {
    NGR public ngr;
    ERC20PresetFixedSupply public usdt;
    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    function setUp() public {
        usdt = new ERC20PresetFixedSupply(
            "USDT",
            "USDT",
            1_000_000 ether,
            address(this)
        );
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        ngr = new NGR(address(usdt), owners);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;

        for (uint i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 100 ether);
            usdt.transfer(owners[i], 2_000 ether);
            vm.prank(owners[i]);
            usdt.approve(address(ngr), 2_000 ether);
        }
    }

    function test_deposit() public {
        vm.prank(user1);
        ngr.deposit(1 ether, false);

        assertEq(ngr.totalPositions(), 1);
        (
            address user,
            uint initialDeposit,
            uint helixAmount,
            uint depositTime,
            uint liquidationPrice,
            bool redeposit
        ) = ngr.positions(1);
        assertEq(user, user1);
        assertEq(initialDeposit, 1 ether);
        uint expectedHelix = uint(0.97 ether * 1 ether) /
            uint((1.1 ether * 909) / 1000);
        assertEq(helixAmount, expectedHelix);
        assertEq(depositTime, block.timestamp);
        assertEq(ngr.currentSparks(), 0.97 ether);
        uint theoreticalEndLiquidation = ((1.1 ether * 30 * 12) / 10000) +
            1.1 ether;
        theoreticalEndLiquidation =
            theoreticalEndLiquidation -
            ((theoreticalEndLiquidation * 6) / 10000);
        assertEq(liquidationPrice, theoreticalEndLiquidation);
    }
}

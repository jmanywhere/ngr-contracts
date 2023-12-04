//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "forge-std/Script.sol";

import "../src/GROW.sol";
import "../src/GrowDrip.sol";

contract DeployTestnetDrip is Script {
    address[] owners;
    uint[] shares;
    IERC20 usdt = IERC20(0xb6D07D107FF8e26A21E497Bf64c3239101FED3Cf);

    function run() public {
        vm.startBroadcast();
        address[] memory addrs = new address[](1);
        addrs[0] = address(usdt);
        owners.push(msg.sender);
        shares.push(225);
        GrowToken grow = new GrowToken(addrs, owners, shares, msg.sender);
        usdt.transfer(address(grow), 1 ether);
        owners.push(0xD43f17A3103a07d35215E1b19676f4FbFb6db682);
        shares.push(225);
        owners.push(0x5a74Ed711403C3bF2e137AcDC191AC397Df52bca);
        shares.push(50);
        GrowDrip drip = new GrowDrip(
            address(usdt),
            address(grow),
            owners,
            shares
        );
        console.log("Drip address: %s", address(drip));
        console.log("Grow address: %s", address(grow));
        grow.setExecutorAddress(address(drip), true);
        grow.setFeeExemption(address(drip), true);
        vm.stopBroadcast();
    }
}

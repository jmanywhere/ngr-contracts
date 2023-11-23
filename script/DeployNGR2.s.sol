//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/GROW.sol";
import "../src/NGR_Grow.sol";

contract DeployNGR2 is Script {
    GrowToken public grow;
    NGR_with_Grow public ngrGrow;

    function run() public {
        address[] memory stables = new address[](1);
        stables[0] = 0x55d398326f99059fF775485246999027B3197955;
        address[] memory owners = new address[](3);
        owners[0] = 0xD43f17A3103a07d35215E1b19676f4FbFb6db682;
        owners[1] = 0xccFaBE896671b27F002Da529Ea9b6B8578397124;
        owners[2] = 0x5a74Ed711403C3bF2e137AcDC191AC397Df52bca;
        uint256[] memory shares = new uint256[](3);
        shares[0] = 45;
        shares[1] = 35;
        shares[2] = 20;
        grow = GrowToken(0xA72f53ea4f3Cf19f1F6359E87E58221Bd0a7068b);
        vm.startBroadcast();
        // grow = new GrowToken(stables, owners, shares, owners[0]);
        ngrGrow = new NGR_with_Grow(address(grow), stables[0], msg.sender);
        // IERC20 USDT = IERC20(stables[0]);
        // USDT.approve(address(ngrGrow), type(uint256).max);
        // // This will need to be made manually
        // for (uint256 i = 0; i < owners.length; i++) {
        //     grow.setExecutorAddress(owners[i], true);
        // }
        // grow.setExecutorAddress(address(ngrGrow), true);
        // USDT.transfer(address(grow), 1 ether);
        vm.stopBroadcast();

        // ngrGrow = NGR_with_Grow(0xf8E7796F60cA5A1D8cAD4c0A1153235A5d5c4FC4);
        // console.log("GrowToken address: %s", address(grow));
        console.log("NGR_with_Grow address: %s", address(ngrGrow));
    }
}

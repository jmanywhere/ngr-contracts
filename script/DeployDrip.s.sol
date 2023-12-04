//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/GrowDrip.sol";
import "../src/GROW.sol";
import "forge-std/Script.sol";

contract DeployDrip is Script {
    address[] owners;
    uint[] shares;
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address owner1 = 0xD43f17A3103a07d35215E1b19676f4FbFb6db682;
    address owner2 = 0xccFaBE896671b27F002Da529Ea9b6B8578397124;
    address owner3 = 0x5a74Ed711403C3bF2e137AcDC191AC397Df52bca;

    function run() public {
        owners.push(owner1);
        shares.push(225);
        owners.push(owner2);
        shares.push(225);
        owners.push(owner3);
        shares.push(50);

        GrowToken grow = GrowToken(0xA72f53ea4f3Cf19f1F6359E87E58221Bd0a7068b);

        vm.startBroadcast();
        GrowDrip drip = new GrowDrip(
            address(usdt),
            address(grow),
            owners,
            shares
        );

        console.log("Drip address: %s", address(drip));

        grow.setFeeExemption(address(drip), true);
        vm.stopBroadcast();
    }
}

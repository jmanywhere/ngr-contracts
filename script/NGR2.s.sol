// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/prevNGR/NGR_2.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract DeployNGR is Script {
    function run() public {
        uint256 deployerPrivate = vm.envUint("PRIVATE_KEY");
        uint256 neo = vm.envUint("NEO_PKEY");
        address[] memory owners = new address[](3);
        owners[0] = 0x5a74Ed711403C3bF2e137AcDC191AC397Df52bca;
        owners[1] = 0x7Ff20b4E1Ad27C5266a929FC87b00F5cCB456374;
        owners[2] = 0xD43f17A3103a07d35215E1b19676f4FbFb6db682;
        IERC20 usdt = IERC20(0xb6D07D107FF8e26A21E497Bf64c3239101FED3Cf);

        vm.startBroadcast(deployerPrivate);
        NGR_v2 ngr = new NGR_v2(
            0xb6D07D107FF8e26A21E497Bf64c3239101FED3Cf,
            0xFe4c0A272046b4d6D140F60F7C6376a98BcB3511,
            0xDE4015049535C5322d92A1da6c4E38F213b002aF,
            owners
        );
        usdt.transfer(address(ngr), 1 ether);

        usdt.approve(address(ngr), ~uint256(0));
        vm.stopBroadcast();

        vm.broadcast(neo);
        usdt.approve(address(ngr), ~uint256(0));
    }
}

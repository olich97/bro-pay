// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {BroPayAddressRegistry} from "../src/BroPayAddressRegistry.sol";
import {BroPayPaymaster}      from "../src/BroPayPaymaster.sol";
import {BroPayEscrowMinter}   from "../src/BroPayEscrowMinter.sol";
import {BroPayRefundGuard}    from "../src/BroPayRefundGuard.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIV_KEY_PK");
        vm.startBroadcast(pk);

        BroPayAddressRegistry reg = BroPayAddressRegistry(
            Upgrades.deployUUPSProxy(
                "BroPayAddressRegistry",
                abi.encodeCall(BroPayAddressRegistry.initialize, (msg.sender))
            )
        );

        BroPayPaymaster pm = BroPayPaymaster(
            Upgrades.deployUUPSProxy(
                "BroPayPaymaster",
                abi.encodeCall(
                    BroPayPaymaster.initialize,
                    (0x0576a174D229E3cFA37253523E645A78A0C91B57 /*EntryPoint*/, msg.sender)
                )
            )
        );

        BroPayEscrowMinter em = BroPayEscrowMinter(
            Upgrades.deployUUPSProxy(
                "BroPayEscrowMinter",
                abi.encodeCall(BroPayEscrowMinter.initialize, (0x0 /* token */, msg.sender))
            )
        );

        BroPayRefundGuard rg = BroPayRefundGuard(
            Upgrades.deployUUPSProxy(
                "BroPayRefundGuard",
                abi.encodeCall(BroPayRefundGuard.initialize, (msg.sender))
            )
        );

        console2.log("Registry", address(reg));
        console2.log("Paymaster", address(pm));
        console2.log("EscrowMinter", address(em));
        console2.log("RefundGuard", address(rg));

        vm.stopBroadcast();
    }
}

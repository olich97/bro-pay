pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {BroPayAddressRegistry} from "../src/BroPayAddressRegistry.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract RegistryTest is Test {
    BroPayAddressRegistry reg;
    address owner = address(0xA11CE);

    function setUp() public {
        vm.startPrank(owner);
        reg = BroPayAddressRegistry(
            Upgrades.deployUUPSProxy(
                "BroPayAddressRegistry",
                abi.encodeCall(BroPayAddressRegistry.initialize, (owner))
            )
        );
        vm.stopPrank();
    }

    function testBind() public {
        bytes32 h = keccak256("123");
        vm.prank(owner);
        reg.bind(h, address(0xBEEF));
        assertEq(reg.resolve(h), address(0xBEEF));
    }

    function testCannotRebind() public {
        bytes32 h = keccak256("123");
        vm.startPrank(owner);
        reg.bind(h, address(0xBEEF));
        vm.expectRevert(BroPayAddressRegistry.AlreadyBound.selector);
        reg.bind(h, address(0xCAFE));
    }
}

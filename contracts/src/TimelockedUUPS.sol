// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @dev Adds a 24 h delay to all upgrades (immutable gracePeriod)
 */
abstract contract TimelockedUUPS is UUPSUpgradeable, OwnableUpgradeable {
    uint256 public constant GRACE_PERIOD = 24 hours;
    mapping(bytes32 => uint256) public queued;

    event UpgradeQueued(address impl, bytes32 id, uint256 eta);

    function queueUpgrade(address newImplementation) external onlyOwner {
        bytes32 id = keccak256(abi.encode(newImplementation, block.timestamp));
        queued[id] = block.timestamp + GRACE_PERIOD;
        emit UpgradeQueued(newImplementation, id, queued[id]);
    }

    /// @dev called by OZ during `upgradeTo`
    function _authorizeUpgrade(address newImpl) internal view override {
        bytes32 id = keccak256(abi.encode(newImpl, block.timestamp - GRACE_PERIOD));
        require(queued[id] != 0 && block.timestamp >= queued[id], "upgrade blocked / grace");
    }
}

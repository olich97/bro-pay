// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./TimelockedUUPS.sol";

/**
 * @title Phone‑number → deterministic wallet mapping (write‑once)
 */
contract BroPayAddressRegistry is Initializable, TimelockedUUPS {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error AlreadyBound();
    error NotOwner();

    mapping(bytes32 => address) public resolve;
    EnumerableSet.Bytes32Set private _allHashes;

    /** @custom:oz-upgrades-unsafe-allow constructor **/
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    /// @notice owner == Cloudflare Worker backend hot‑wallet
    function bind(bytes32 phoneHash, address wallet) external onlyOwner {
        if (resolve[phoneHash] != address(0)) revert AlreadyBound();
        resolve[phoneHash] = wallet;
        _allHashes.add(phoneHash);
    }

    // enumeration helper for analytics
    function totalBound() external view returns (uint256) {
        return _allHashes.length();
    }
}

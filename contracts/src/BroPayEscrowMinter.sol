// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TimelockedUUPS.sol";

/**
 * @notice Mints token upon webhook confirmation from PSP.
 *         Can also burn on chargeback (owner‑only).
 */
contract BroPayEscrowMinter is Initializable, TimelockedUUPS {
    error AlreadyProcessed();
    error NotProcessor();

    mapping(bytes32 => bool) public processed;
    IERC20PermitUpgradeable public token;

    /** @custom:oz-upgrades-unsafe-allow constructor **/
    constructor() { _disableInitializers(); }

    function initialize(
        address _token,
        address owner_
    ) public initializer {
        token = IERC20PermitUpgradeable(_token);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    function release(bytes32 id, address to, uint256 amount) external onlyOwner {
        if (processed[id]) revert AlreadyProcessed();
        processed[id] = true;
        ERC20BurnableUpgradeable(address(token)).mint(to, amount);
    }

    /// @dev PSP can claw back funds if fiat leg fails
    function burnOnChargeback(bytes32 id, address from, uint256 amt) external onlyOwner {
        ERC20BurnableUpgradeable(address(token)).burnFrom(from, amt);
    }
}

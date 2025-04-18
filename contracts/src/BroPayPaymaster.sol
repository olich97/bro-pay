// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "account-abstraction/interfaces/IPaymaster.sol";
import "account-abstraction/core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./TimelockedUUPS.sol";

contract BroPayPaymaster is BasePaymaster, TimelockedUUPS {
    using SafeERC20 for IERC20;

    uint256 public maxGas = 300_000;

    /** @custom:oz-upgrades-unsafe-allow constructor **/
    constructor() {
        _disableInitializers();
    }

    function initialize(IEntryPoint ep, address owner_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        _entryPoint = ep;
    }

    /* -------------------------------------------------------------------- */
    /* BasePaymaster overrides                                              */
    /* -------------------------------------------------------------------- */

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        uint256 maxCost
    ) internal view override returns (bytes memory, uint256) {
        require(maxCost < maxGas * tx.gasprice, "gas demasiado");
        // No post‑op context
        return ("", 0);
    }

    /* -------------------------------------------------------------------- */
    /* Owner admin                                                          */
    /* -------------------------------------------------------------------- */

    function setMaxGas(uint256 newLimit) external onlyOwner { maxGas = newLimit; }

    /// @notice fund paymaster on L2
    receive() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }
}

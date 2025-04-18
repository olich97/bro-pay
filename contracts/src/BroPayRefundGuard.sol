// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./TimelockedUUPS.sol";

contract BroPayRefundGuard is Initializable, ReentrancyGuardUpgradeable, TimelockedUUPS {
    uint64 public constant EXPIRY = 7 days;

    struct Escrow {
        address token;
        address sender;
        address receiver;
        uint256 amount;
        uint64 timestamp;
        bool claimed;
    }

    mapping(bytes32 => Escrow) public escrows; // txHash → Escrow

    /** @custom:oz‑upgrades‑unsafe‑allow constructor */
    constructor() { _disableInitializers(); }

    function initialize(address owner_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function register(bytes32 txHash, Escrow calldata e) external onlyOwner {
        escrows[txHash] = e;
    }

    /// @notice Sender triggers after EXPIRY if receiver never redeemed
    function refund(bytes32 txHash) external nonReentrant {
        Escrow storage e = escrows[txHash];
        require(msg.sender == e.sender, "not sender");
        require(!e.claimed, "claimed");
        require(block.timestamp > e.timestamp + EXPIRY, "still fresh");
        e.claimed = true;
        IERC20Upgradeable(e.token).transfer(e.sender, e.amount);
    }
}

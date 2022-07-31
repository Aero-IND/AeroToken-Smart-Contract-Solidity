// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "./FlexibleStaking.sol";
import "./LockedStaking.sol";

contract AeroToken is ERC20, ERC20Capped, ERC20Burnable, AccessControl {
    address public dev;
    address public owner;
    address public liquidityWallet;
    address public tradingWallet;


    VestingWallet public vestingOwnerContract;
    uint64 public VESTING_OWNER_START_TIMESTAMP = (uint64(block.timestamp)) + 3600 * 24;//1672441200; // 31/12/2022 00:00 // for testing use (uint64(block.timestamp))
    uint64 public VESTING_OWNER_DURATION = 30 * 12 * 3 days; // use 1 day for testing

    FlexibleStaking public flexibleStakingContract;
    LockedStaking public lockedStakingContract3;
    LockedStaking public lockedStakingContract6;
    LockedStaking public lockedStakingContract12;

    // Max cap to 11B
    uint256 public maxCap = 11_000_000_000 * 10**decimals();
    uint256 public minCap = 10_000_000 * 10**decimals();

    uint256 public rewardsTotal = 6_990_000_000 * 10**decimals();

    uint256 public rewardsFlexible = (rewardsTotal / 15) * 1;
    uint256 public rewardsLocked3 = (rewardsTotal / 15) * 2;
    uint256 public rewardsLocked6 = (rewardsTotal / 15) * 4;
    uint256 public rewardsLocked12 = (rewardsTotal / 15) * 8;

    uint public rewardsDuration = 30 * 12 * 3 days; // 1095

    uint public lockedStaking3Duration = 30 * 3 days;
    uint public lockedStaking6Duration = 30 * 6 days;
    uint public lockedStaking12Duration = 30 * 12 days;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint BURN_FEE = 27; // = 0.27%
    mapping(address => bool) public feesExclusion;

    constructor(
        address _dev,
        address _owner,
        address _liquidityWallet,
        address _tradingWallet
    ) ERC20("Aero IND", "AERO") ERC20Capped(maxCap) {
        // Dev is admin by default
        // dev = msg.sender;
        dev = _dev;
        _grantRole(DEFAULT_ADMIN_ROLE, dev);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Special addresses
        owner = _owner;
        liquidityWallet = _liquidityWallet;
        tradingWallet = _tradingWallet;
        _grantRole(OWNER_ROLE, owner);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        // Initial mints
        _mint(owner, 1_000_000_000 * 10**decimals());
        _mint(liquidityWallet, 1_000_000_000 * 10**decimals());
        _mint(tradingWallet, 10_000_000 * 10**decimals());

        // Vesting Wallet
        vestingOwnerContract = new VestingWallet(
            owner,
            VESTING_OWNER_START_TIMESTAMP,
            VESTING_OWNER_DURATION
        );
        _mint(address(vestingOwnerContract), 2_000_000_000 * 10**decimals());

        // Flexible Staking
        flexibleStakingContract = new FlexibleStaking(
            dev,
            dev,
            address(this),
            address(this),
            rewardsDuration
        );
        _mint(address(flexibleStakingContract), rewardsFlexible);
        // notifyRewardAmount to start the staking rewards

        // Locked Staking
        lockedStakingContract3 = new LockedStaking(
            dev,
            dev,
            address(this),
            address(this),
            rewardsDuration,
            lockedStaking3Duration
        );
        lockedStakingContract6 = new LockedStaking(
            dev,
            dev,
            address(this),
            address(this),
            rewardsDuration,
            lockedStaking6Duration
        );
        lockedStakingContract12 = new LockedStaking(
            dev,
            dev,
            address(this),
            address(this),
            rewardsDuration,
            lockedStaking12Duration
        );
        _mint(address(lockedStakingContract3), rewardsLocked3);
        _mint(address(lockedStakingContract6), rewardsLocked6);
        _mint(address(lockedStakingContract12), rewardsLocked12);

        // Add contracts to fee exclusion
        addWalletToFeesExclusion(dev);
        addWalletToFeesExclusion(owner);
        addWalletToFeesExclusion(liquidityWallet);
        addWalletToFeesExclusion(tradingWallet);
        addWalletToFeesExclusion(address(vestingOwnerContract));
        addWalletToFeesExclusion(address(flexibleStakingContract));
        addWalletToFeesExclusion(address(lockedStakingContract3));
        addWalletToFeesExclusion(address(lockedStakingContract6));
        addWalletToFeesExclusion(address(lockedStakingContract12));
    }

    function addWalletToFeesExclusion(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        feesExclusion[_account] = true;
    }

    function removeWalletToFeesExclusion(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        feesExclusion[_account] = false;
    }

    function vestForOwner() public {
        vestingOwnerContract.release(address(this));
    }

    // Override Mint
    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }

    // Override Transfer
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        address spender = _msgSender();

        if (feesExclusion[spender] == true || totalSupply() < minCap) {
            super.transfer(recipient, amount);
        } else {
            uint burnAmount = (amount * BURN_FEE) / 10000;
            uint remainingAmount = amount - burnAmount;
            _burn(spender, burnAmount);
            super.transfer(recipient, remainingAmount);
        }

        return true;
    }
}

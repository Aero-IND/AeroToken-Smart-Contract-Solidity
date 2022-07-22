// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract AeroToken is ERC20, ERC20Capped, ERC20Burnable, AccessControl {
    address public _owner;
    address public _liquidity_wallet;
    address public _admin;

    VestingWallet public vesting_wallet_for_owner;

    // Max cap to 11B
    uint256 private _cap = 11_000_000_000 * 10 ** decimals();

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    constructor(address owner, address liquidity_wallet) ERC20("Aerotyne IND", "AERO") ERC20Capped(_cap) {
        // Initial mint to owner
        _mint(owner, 1_000_000_000 * 10 ** decimals());

        // Dev is admin by default
        _admin = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Special addresses
        _owner = owner;
        _liquidity_wallet = liquidity_wallet;
        _grantRole(OWNER_ROLE, _owner);

        // Vesting Wallet
        vesting_wallet_for_owner = new VestingWallet(owner, 0, 1 * 3600 * 24);
        _mint(address(vesting_wallet_for_owner), 2_000_000_000 * 10 ** decimals());
    }

    // function setVestingWalletForOwner public onlyRole(DEFAULT_ADMIN_ROLE) {
    //     _mint(address(vesting_wallet_for_owner), 2_000_000_000 * 10 ** decimals());
    // }

    // Override Mint
    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

}
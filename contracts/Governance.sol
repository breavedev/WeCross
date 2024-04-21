// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./ImportsManager.sol";
import "./IVestingControllerERC721.sol";

/// @title Cross network ERC20 Governance Aggregator contract for Automata Witness
/// @notice Default implementation of the OpenZeppelin ERC20 standard by overriding balanceOf() and totalSupply() and disallow token transfers
contract Governance is ImportsManager {
    string private name_;
    string private symbol_;

    // upgrades-unsafe-allow constructor
    constructor() initializer {}

    /// @notice Initializer allow proxy scheme
    /// @dev For upgradability its necessary to use initialize instead of simple constructor
    /// @param _name Name of the token like `Cross Governance Aggregator ERC20`
    /// @param _symbol Short symbol like `gCROSS`
    /// @param _registry is the address of address registry
    function initialize(
        string memory _name,
        string memory _symbol,
        IAddressRegistry _registry
    ) public initializer {
        __ImportsManager_init();

        name_ = _name;
        symbol_ = _symbol;
        REGISTRY = _registry;

        address _multisigVault = REGISTRY.getAddressOf(REGISTRY.MULTISIG());
        _grantRole(DEFAULT_ADMIN_ROLE, _multisigVault);
        _grantRole(PAUSER_ROLE, _multisigVault);
        _grantRole(READER_ROLE, _multisigVault);
    }

    /// @notice Function to override default totalSupply and point it to the totalSupply of CROSS token contract
    function totalSupply() public view returns (uint256) {
        return
            IERC20Upgradeable(REGISTRY.getAddressOf(REGISTRY.CROSS_TOKEN()))
                .totalSupply();
    }

    /// @notice Function to summarize balances of an account over multiple Cross Ecosystem tokens
    /// @param account to summarize balance for in VC, SM and CROSS
    function balanceOf(
        address account
    ) public view onlyRole(READER_ROLE) returns (uint256) {
        // tokenOfOwnerByIndex(address owner, uint256 index) → uint256
        // Returns a token ID owned by owner at a given index of its token list.
        // Use along with balanceOf to enumerate all of owner's tokens.
        uint256 _accountBalance;
        address _vcAddress = REGISTRY.getAddressOf(
            REGISTRY.VESTING_CONTROLLER()
        );
        uint256 _vcBalance = IVestingControllerERC721(_vcAddress).balanceOf(
            account
        );
        for (uint256 i; i < _vcBalance; i++) {
            // Get tokenId
            uint256 _tokenId = IVestingControllerERC721(_vcAddress)
                .tokenOfOwnerByIndex(account, i);
            // Get Investment info for tokenId
            (
                uint256 crossTokenAmount,
                uint256 crossClaimedAmount,
                ,
                ,
                uint256 crossStakedAmount
            ) = IVestingControllerERC721(_vcAddress).getInvestmentInfo(
                    _tokenId
                );
            _accountBalance +=
                crossTokenAmount -
                crossClaimedAmount -
                crossStakedAmount;
        }
        // SM balanceOf = SM.balanceOf()
        _accountBalance += IERC20Upgradeable(
            REGISTRY.getAddressOf(REGISTRY.SAFETY_MODULE())
        ).balanceOf(account);
        // CROSS balanceOf = CROSS.balanceOf()
        _accountBalance += IERC20Upgradeable(
            REGISTRY.getAddressOf(REGISTRY.CROSS_TOKEN())
        ).balanceOf(account);

        return _accountBalance;
    }

    function name() public view returns (string memory) {
        return name_;
    }

    function symbol() public view returns (string memory) {
        return symbol_;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}

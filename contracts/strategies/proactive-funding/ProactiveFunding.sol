// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseStrategy} from "../BaseStrategy.sol";
import {ProactiveFundingVoucher} from "./ProactiveFundingVoucher.sol";

contract ProactiveFunding is BaseStrategy {
    uint256 public constant HOURLY_RATE = 10000; // TODO correct this later
    uint256 public constant HOURS_PER_VOUCHER= 10;

    
    ProactiveFundingVoucher public voucher;
    
    error InvalidVoucher();
    error UnauthorizedClaim();
    
    event DirectAllocated(
        bytes32 indexed profileId, address profileOwner, uint256 amount, address token, address sender
    );
    event VoucherClaimed(uint256 indexed tokenId, address indexed recipient);

    constructor(address _allo, string memory _name) BaseStrategy(_allo, _name) {}

    function initialize(uint256 _poolId, bytes memory _data) external virtual override {
        __BaseStrategy_init(_poolId);
        
        // Deploy new voucher contract
        voucher = new ProactiveFundingVoucher(address(this));
        
        emit Initialized(_poolId, _data);
    }

    /// @notice Withdraw funds
    /// @param _token Token address
    /// @param _recipient Address to send the funds to
    function withdraw(address _token, address _recipient) external onlyPoolManager(msg.sender) {
        uint256 amount = _getBalance(_token, address(this));
        _transferAmount(_token, _recipient, amount);
    }

    /// @notice Claim a specific voucher
    /// @param _tokenId The ID of the voucher to claim
    function claimVoucher(uint256 _tokenId) external {
        // Check if the voucher exists and is owned by this contract
        if (!voucher.ownerOf(_tokenId) == address(this)) {
            revert InvalidVoucher();
        }
        
        // Check if the caller is the worker associated with this voucher
        if (msg.sender != voucher.tokenToWorker(_tokenId)) {
            revert UnauthorizedClaim();
        }

        // Transfer the voucher to the caller
        voucher.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        emit VoucherClaimed(_tokenId, msg.sender);
    }

    /// Allocate funds to a recipient
    /// @param _data The data to allocate
    /// @param _sender The sender
    function _allocate(bytes memory _data, address _sender) internal virtual override {
        (address PFVAddress, address token, uint256 nonce) =
            abi.decode(_data, (address, address, uint256));
        bytes32 profileId = keccak256(abi.encodePacked(nonce, profileOwner));
        // Mint voucher to pool
        uint256 tokenId = voucher.mintVoucherToPool(_sender);
        _transferAmount(_token, _sender, HOURLY_RATE * HOURS_PER_VOUCHER);
        emit DirectAllocated(profileId, profileOwner, amount, token, _sender);
    }

    receive() external payable {
        revert NOT_IMPLEMENTED();
    }

    function _beforeIncreasePoolAmount(uint256) internal virtual override {
        revert NOT_IMPLEMENTED();
    }

    // Not implemented

    

    function _distribute(address[] memory, bytes memory, address) internal virtual override {
        revert NOT_IMPLEMENTED();
    }

    function _getRecipientStatus(address) internal view virtual override returns (Status) {
        revert NOT_IMPLEMENTED();
    }

    function _isValidAllocator(address _allocator) internal view virtual override returns (bool) {}

    function _registerRecipient(bytes memory _data, address _sender) internal virtual override returns (address) {}

    function _getPayout(address _recipientId, bytes memory _data)
        internal
        view
        virtual
        override
        returns (PayoutSummary memory)
    {}
}

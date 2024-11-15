// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title ProactiveFundingVoucher
 * @notice A simple NFT contract for ProactiveFunding vouchers
 */
contract ProactiveFundingVoucher is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    address public proactiveFundingContract;

    mapping(uint256 => address) public tokenToWorker;
    
    error UnauthorizedMinter();
    
    event VoucherMinted();
    
    constructor(address _proactiveFundingContract) 
        ERC721("ProactiveFunding Voucher", "PFV") 
        Ownable(msg.sender) 
    {
        proactiveFundingContract = _proactiveFundingContract;
    }
    
    /**
     * @notice Mint a new voucher NFT to the pool
     * @dev Only callable by the ProactiveFunding contract
     * @return tokenId The ID of the newly minted NFT
     */
    function mintVoucherToPool(address _worker) external returns (uint256) {
        if (msg.sender != proactiveFundingContract) {
            revert UnauthorizedMinter();
        }
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        tokenToWorker[newTokenId] = _worker;
        _safeMint(proactiveFundingContract, newTokenId);
        
        emit VoucherMinted();
        return newTokenId;
    }

    /**
     * @notice Get all vouchers currently owned by the ProactiveFunding contract
     * @return voucherIds Array of token IDs owned by the ProactiveFunding contract
     * @return workers Array of worker addresses corresponding to each voucher
     */
    function getActiveVouchers() external view returns (uint256[] memory voucherIds, address[] memory workers) {
        uint256 totalSupply = _tokenIds.current();
        uint256 activeCount = 0;
        
        // First pass: count active vouchers
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (_exists(i) && ownerOf(i) == proactiveFundingContract) {
                activeCount++;
            }
        }
        
        // Initialize arrays with the correct size
        voucherIds = new uint256[](activeCount);
        workers = new address[](activeCount);
        
        // Second pass: populate arrays
        uint256 currentIndex = 0;
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (_exists(i) && ownerOf(i) == proactiveFundingContract) {
                voucherIds[currentIndex] = i;
                workers[currentIndex] = tokenToWorker[i];
                currentIndex++;
            }
        }
        
        return (voucherIds, workers);
    }
} 
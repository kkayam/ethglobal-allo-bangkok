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
        Ownable()
    {
        proactiveFundingContract = _proactiveFundingContract;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }
    
    function mintVoucherToPool(address _worker) external returns (uint256) {
        if (msg.sender != proactiveFundingContract) {
            revert UnauthorizedMinter();
        }
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        tokenToWorker[newTokenId] = _worker;
        _mint(proactiveFundingContract, newTokenId);
        
        emit VoucherMinted();
        return newTokenId;
    }

    function getActiveVouchers() external view returns (uint256[] memory voucherIds, address[] memory workers) {
        uint256 total = _tokenIds.current();
        uint256 activeCount = 0;
        
        // First pass: count active vouchers
        for (uint256 i = 1; i <= total; i++) {
            if (_exists(i) && ownerOf(i) == proactiveFundingContract) {
                activeCount++;
            }
        }
        
        // Initialize arrays with the correct size
        voucherIds = new uint256[](activeCount);
        workers = new address[](activeCount);
        
        // Second pass: populate arrays
        uint256 currentIndex = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (_exists(i) && ownerOf(i) == proactiveFundingContract) {
                voucherIds[currentIndex] = i;
                workers[currentIndex] = tokenToWorker[i];
                currentIndex++;
            }
        }
        
        return (voucherIds, workers);
    }
} 
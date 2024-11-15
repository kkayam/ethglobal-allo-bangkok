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
} 
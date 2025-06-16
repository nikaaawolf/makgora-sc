// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title MakgoraNFT
 * @dev Galapagoz NFT Contract - Only handles NFT functionality
 */
contract MakgoraNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Interface ID as defined in ERC-4906. This does not correspond to a traditional interface ID as ERC-4906 only
    // defines events and does not include any external function.
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);

    // Optional mapping for token URIs
    mapping(uint256 tokenId => string) private _tokenURIs;
    
    // Token ID counter
    uint256 private _tokenIdCounter;
    
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {}

    /**
     * @dev Mint creature (Only callable by Makgora contract)
     * traits are stored for tokenURI generation.
     */
    function mint(
        address to
    ) external onlyOwner returns (uint256 tokenId) {
        tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    /**
     * @dev Burn creature (Only callable by Makgora contract)
     */
    function burn(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "MakgoraNFT: Token to burn does not exist");
        _burn(tokenId);
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // Overriding _beforeTokenTransfer from ERC721 is more common,
    // but the current codebase directly overrides transferFrom, so we follow this approach.
    // Using _beforeTokenTransfer would apply to all transfer paths including safeTransferFrom.
    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        // Token ownership and approval checks are performed by the ERC721 standard before super.transferFrom
        // (Actually checked inside _isApprovedOrOwner and _transfer)
        // Here we only check additional conditions.

        // Only check for normal transfers, not for minting (from == address(0)) or burning (to == address(0))
        if (from != address(0) && to != address(0)) {
            bool creatureIsActuallyRoared = false; // Actual roar status
            try IMakgoraForNFT(owner()).isRoared(tokenId) returns (bool isRoaredStatus) {
                // Makgora contract call successful
                creatureIsActuallyRoared = isRoaredStatus;
            } catch {
                // Makgora contract call failed (e.g., contract doesn't exist, out of gas, internal revert, etc.)
                // In this case, allow the transfer according to user requirements.
                // creatureIsActuallyRoared remains false.
            }

            if (creatureIsActuallyRoared) {
                revert("MakgoraNFT: Creature is roared and cannot be transferred.");
            }
        }
        
        super.transferFrom(from, to, tokenId);
    }

}

// IMakgoraForNFT interface declaration typically belongs outside the contract or at the top of the file.
// However, it will compile in Solidity 0.8.x even if declared inside the contract.
// For brevity, we omit moving it outside the contract here.

// The IMakgora interface can be defined directly here.
interface IMakgoraForNFT {
    function isRoared(uint256 tokenId) external view returns (bool);
} 
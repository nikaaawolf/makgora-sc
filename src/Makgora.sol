// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MakgoraNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./libraries/CreatureLogic.sol";
import "./libraries/BattleLogic.sol";
import "./libraries/IPLogic.sol";
import "./libraries/BreedingLogic.sol";
import "./libraries/MakgoraStorage.sol";
import "./libraries/CustomErrors.sol";
import "./libraries/Constants.sol";
import "./config/MakgoraAddressesProvider.sol";

contract Makgora is Ownable, ERC721Holder {
    MakgoraNFT public makgoraNFT; // MakgoraNFT is deployed and owned by Makgora
    
    // Story Protocol and external contract addresses
    MakgoraAddressesProvider public immutable addressesProvider; // Store AddressesProvider
    address public serverAddress;

    event ServerAddressUpdated(address indexed newServerAddress);

    // Modifier definition
    modifier onlyServer() {
        require(msg.sender == serverAddress, "Makgora: Caller is not the server");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address _serverAddress,
        address _addressesProvider // MakgoraAddressesProvider address
    ) Ownable(msg.sender) {
        serverAddress = _serverAddress; // Server address is managed separately
        
        addressesProvider = MakgoraAddressesProvider(_addressesProvider);
        
        // NFT contract deployment, Makgora contract is initial Owner
        makgoraNFT = new MakgoraNFT(name, symbol, address(this)); 
        
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        ds.makgoraNFT = address(makgoraNFT);
    }
    
    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setServerAddress(address _newServerAddress) external onlyOwner {
        serverAddress = _newServerAddress;
        emit ServerAddressUpdated(_newServerAddress);
    }
    
    /*//////////////////////////////////////////////////////////////
                        USER ACCESSIBLE FUNCTIONS
         (internal calls each logic library)
    //////////////////////////////////////////////////////////////*/
    
    function mintGenesis(address to, string memory name, bytes calldata encryptedPrompt) external returns (address ipId, uint256 tokenId) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();

        BreedingLogic.chargeMintingFee(ds, addressesProvider, BreedingLogic.BASE_MINT_PRICE);
        
        // 1. NFT mint (call of mintCreature of MakgoraNFT)
        tokenId = makgoraNFT.mint(address(this)); // Modified
        
        // 2. IP registration and default license connection
        ipId = IPLogic.registerGenesisIP(ds, addressesProvider, tokenId);
        // ipId = address(0x1);

        // 3. Creature data generation
        BreedingLogic.handleMintGenesis(ds, tokenId, name, encryptedPrompt);

        // 4. NFT transfer
        makgoraNFT.transferFrom(address(this), to, tokenId);
        return (ipId, tokenId);
    }
    
    function roar(uint256 creatureId) external {
        if (makgoraNFT.ownerOf(creatureId) != msg.sender) {
            revert CustomErrors.NotCreatureOwner(creatureId, msg.sender, makgoraNFT.ownerOf(creatureId));
        }

        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        
        BattleLogic.handleRoar(ds, creatureId);
    }
    
    function requestBreeding(uint256 parentId, bytes calldata encryptedPrompt) external { 
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();

        BreedingLogic.chargeBreedingFee(ds, addressesProvider, ds.creatures[parentId].mintCount);

        BreedingLogic.handleRequestBreeding(ds, parentId, encryptedPrompt);
    }

    /*//////////////////////////////////////////////////////////////
                        SERVER ACCESSIBLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function resolveBattle(uint256 battleId, uint256 winnerCreatureId) onlyServer external {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        
        uint256 loserId = BattleLogic.handleResolveBattle(ds, battleId, winnerCreatureId);

        makgoraNFT.burn(loserId);
    }

    function executeBreeding(uint256 requestId, string memory name, bytes calldata encryptedPrompt) onlyServer external returns (address childIpId, uint256 childTokenId) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();

        MakgoraStorage.BreedingRequest storage request = ds.breedingRequests[requestId]; 
        
        // 1. Actual NFT mint
        childTokenId = makgoraNFT.mint(address(this));

        // 2. Derivative IP registration
        uint256 parentTokenId = ds.breedingRequests[requestId].parentId;
        childIpId = IPLogic.registerDerivativeIP(ds, addressesProvider, childTokenId, parentTokenId);

        // 3. Creature generation
        BreedingLogic.handleExecuteBreeding(ds, requestId, childTokenId, name, encryptedPrompt);

        // 4. NFT transfer
        makgoraNFT.transferFrom(address(this), request.requester, childTokenId); 
        
        return (childIpId, childTokenId);
    }

    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function getCreature(uint256 tokenId) external view returns (MakgoraStorage.Creature memory) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        return ds.creatures[tokenId];
    }
    
    function getBattle(uint256 battleId) external view returns (MakgoraStorage.Battle memory) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        return ds.battles[battleId];
    }

    /**
     * @notice Check if a specific creature is currently in battle (or in queue)
     */
    function isRoared(uint256 tokenId) external view returns (bool) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        if (!ds.creatures[tokenId].exists) {
            return false; // Non-existent creature cannot be in battle
        }
        return ds.creatures[tokenId].roared;
    }

    function getBreedingFee(uint256 tokenId) external view returns (uint256) {
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        return BreedingLogic.calculateBreedingPrice(ds.creatures[tokenId].mintCount);
    }

    /*//////////////////////////////////////////////////////////////
                            Vault Functions
    //////////////////////////////////////////////////////////////*/

    // Withdraw function for received ETH (Ownable)
    function withdrawPayments(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = to.call{value: balance}("");
        require(success, "Withdrawal failed");
    }


}


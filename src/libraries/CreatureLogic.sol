// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MakgoraStorage.sol";
import "./CustomErrors.sol";

library CreatureLogic {
    
    event AlphaUpdated(uint256 indexed newAlphaId, uint256 indexed winCount, uint256 indexed lastWinAt);

    error CreatureAlreadyExists(uint256 tokenId);

    function createCreature(
        address ipId,
        uint256 parentId,
        uint256 generation,
        string memory name,
        bytes calldata encryptedPrompt
    ) internal returns (MakgoraStorage.Creature memory) {
        return MakgoraStorage.Creature({
            ipId: ipId,
            parentId: parentId,
            generation: generation,
            winCount: 0,
            mintCount: 0,
            lastWinAt: 0,
            name: name,
            encryptedPrompt: encryptedPrompt,
            exists: true,
            roared: false
        });
    }

    function addCreature(
        MakgoraStorage.Layout storage ds,
        uint256 tokenId,
        address ipId,
        string memory name,
        bytes calldata encryptedPrompt
    ) internal {
        if (ds.creatures[tokenId].exists) {
            revert CreatureAlreadyExists(tokenId);
        }
        ds.creatures[tokenId] = createCreature(ipId, 0, 0, name, encryptedPrompt);
    }

    function addCreature(
        MakgoraStorage.Layout storage ds,
        uint256 tokenId,
        address ipId,
        uint256 parentId,
        string memory name,
        bytes calldata encryptedPrompt
    ) internal {
        if (!ds.creatures[parentId].exists) {
            revert CustomErrors.CreatureNotFound(parentId);
        }
        if (ds.creatures[tokenId].exists) {
            revert CreatureAlreadyExists(tokenId);
        }
        uint256 parentGeneration = ds.creatures[parentId].generation;
        ds.creatures[tokenId] = createCreature(ipId, parentId, parentGeneration + 1, name, encryptedPrompt);
    }
    
    function handleWinner(MakgoraStorage.Layout storage ds, uint256 tokenId) internal {
        MakgoraStorage.Creature storage creature = ds.creatures[tokenId];
        creature.winCount++;
        creature.lastWinAt = block.timestamp;
        creature.roared = false;

        MakgoraStorage.Creature storage alphaCreature = ds.creatures[ds.currentAlphaId];
        if (!alphaCreature.exists || creature.winCount > getScaledWinCount(ds, ds.currentAlphaId)) {
            emit AlphaUpdated(tokenId, creature.winCount, creature.lastWinAt);
            ds.currentAlphaId = tokenId;
        }
    }

    function handleLoser(MakgoraStorage.Layout storage ds, uint256 tokenId) internal {
        MakgoraStorage.Creature storage creature = ds.creatures[tokenId];
        creature.exists = false; 
    }

    function getScaledWinCount(MakgoraStorage.Layout storage ds, uint256 tokenId) internal view returns (uint256) {
        MakgoraStorage.Creature storage creature = ds.creatures[tokenId];
        // penalty applied for each hour that has passed since the creature was last win
        uint256 penalty = (block.timestamp - creature.lastWinAt) / 3600;
        return creature.winCount - penalty;
    }
} 
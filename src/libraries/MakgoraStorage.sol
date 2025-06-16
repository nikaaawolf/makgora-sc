// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library MakgoraStorage {
    // Using a unique ID like keccak256("makgora.storage.Makgora").
    bytes32 constant STORAGE_SLOT = 0x9241e0391709ed2e9ad94e8fd9da2e6807cecdc52fbbcd32d6635d26235730f7; // "makgora.storage.Makgora"

    struct Creature {
        address ipId;          // Token ID
        uint256 parentId;
        uint256 generation;
        uint256 winCount;
        uint256 mintCount;
        uint256 lastWinAt;
        string name;
        bytes encryptedPrompt;
        bool exists;         // false if burned or deactivated
        bool roared;
    }

    struct BreedingRequest {
        address requester;
        uint256 parentId;
        bool processed;
    }

    struct Battle {
        uint256 id;
        uint256 creature1Id;
        uint256 creature2Id;
        uint256 winnerId; // 0 means undecided
        bool resolved;
    }

    struct Layout {
        // Creature state
        mapping(uint256 => Creature) creatures; // Changed to CreatureLogic.Creature

        // IP state
        mapping(uint256 => address) tokenToIpId; // tokenId => Story IP ID
        mapping(address => uint256) ipIdToToken; // Story IP ID => tokenId (optional)
        mapping(bytes32 => address) promptOwner; // prompt => owner

        // Battle Queue
        uint256[] roarQueue; 

        // Battle state
        mapping(uint256 => Battle) battles; // Changed to BattleLogic.Battle
        uint256 nextBattleId; // Removed as it's managed in Makgora.sol

        mapping(uint256 => BreedingRequest) breedingRequests; // requestId => BreedingRequest data
        uint256 nextBreedingRequestId; 

        uint256 currentAlphaId;

        uint256 globalDerivativeLicenseTermsId; // <-- Added global derivative license terms ID

        address makgoraNFT;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
} 
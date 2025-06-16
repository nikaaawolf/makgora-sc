// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MakgoraStorage.sol";
import "./CreatureLogic.sol";
import "./BreedingLogic.sol";
import "./CustomErrors.sol";

library BattleLogic {
    event RoarQueued(uint256 indexed creatureId, address indexed owner);
    event BattleCreated(uint256 indexed battleId, uint256 creature1Id, uint256 creature2Id);
    event BattleResolved(uint256 indexed battleId, uint256 winnerId, uint256 loserId);

    error CreatureAlreadyRoared(uint256 creatureId);
    error BattleAlreadyResolved(uint256 battleId);
    error InvalidWinner(uint256 battleId, uint256 winnerId);

    /**
     * @dev 플레이어가 배틀 참여(roar)를 요청할 때 호출됩니다.
     * MakgoraStorage.Layout에는 큐잉된 크리처 ID를 직접 저장하지 않습니다.
     * 큐 관리는 Makgora.sol의 `roarQueue` 배열에서 이루어집니다.
     * 이 함수는 유효성 검사 및 이벤트 발생에 집중합니다.
     */
    function handleRoar(
        MakgoraStorage.Layout storage ds,
        uint256 creatureId
    ) internal {
        MakgoraStorage.Creature storage creature = ds.creatures[creatureId];
        if (!creature.exists) {
            revert CustomErrors.CreatureNotFound(creatureId);
        }
        if (creature.roared) {
            revert CreatureAlreadyRoared(creatureId);
        }

        creature.roared = true;

        // 2. 자체 큐에 추가
        ds.roarQueue.push(creatureId);
    
        emit RoarQueued(creatureId, msg.sender);

        if (ds.roarQueue.length >= 2) {
            createNewBattle(ds);
        }
        // emit RoarQueued(creatureId, requester); // Makgora.sol에서 roarQueue에 push 후 이벤트 발생
    }

    /**
     * @dev 서버가 배틀 큐에서 두 크리처를 선택하여 배틀을 생성할 때 호출됩니다.
     * Makgora.sol에서 큐에서 두 참가자를 꺼낸 후 이 함수를 호출합니다.
     */
    function createNewBattle(
        MakgoraStorage.Layout storage ds
    ) internal {

        uint256 creature1Id = ds.roarQueue[ds.roarQueue.length - 1];
        uint256 creature2Id = ds.roarQueue[ds.roarQueue.length - 2];

        ds.roarQueue.pop();
        ds.roarQueue.pop();
        
        if (!ds.creatures[creature1Id].exists) {
            revert CustomErrors.CreatureNotFound(creature1Id);
        }
        if (!ds.creatures[creature2Id].exists) {
            revert CustomErrors.CreatureNotFound(creature2Id);
        }
        require(creature1Id != creature2Id, "BattleLogic: Cannot battle self");

        uint256 battleId = ds.nextBattleId++; // Makgora.sol에서 전달받은 ID 사용
        ds.battles[battleId] = MakgoraStorage.Battle({
            id: battleId,
            creature1Id: creature1Id,
            creature2Id: creature2Id,
            winnerId: 0, // 아직 승자 없음
            resolved: false
        });

        emit BattleCreated(battleId, creature1Id, creature2Id); 
    }

    function handleResolveBattle(
        MakgoraStorage.Layout storage ds,
        uint256 battleId,
        uint256 winnerId
    ) internal returns (uint256 loserId) {
        MakgoraStorage.Battle storage battle = ds.battles[battleId];
        if (battle.resolved) {
            revert BattleAlreadyResolved(battleId);
        }
        if (winnerId != battle.creature1Id && winnerId != battle.creature2Id) {
            revert InvalidWinner(battleId, winnerId);
        }

        battle.winnerId = winnerId;
        battle.resolved = true;

        if (winnerId == battle.creature1Id) {
            loserId = battle.creature2Id;
        } else {
            loserId = battle.creature1Id;
        }

        CreatureLogic.handleWinner(ds, winnerId);
        CreatureLogic.handleLoser(ds, loserId); 

        emit BattleResolved(battleId, winnerId, loserId);

        return loserId;
    }

} 
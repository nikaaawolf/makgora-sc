pragma solidity ^0.8.19;

library CustomErrors {
    error CreatureNotFound(uint256 creatureId);
    error NotCreatureOwner(uint256 creatureId, address caller, address owner);
}
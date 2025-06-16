// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library NetworkConfig {
    struct StoryProtocolAddresses {
        address ipAssetRegistry;
        address royaltyModule;
        address licensingModule;
        address pilTemplate;
        address wipToken;
        address royaltyPolicyLRP;
    }
    
    /// @dev Story Aeneid Testnet addresses
    function getAeneidTestnetConfig() internal pure returns (StoryProtocolAddresses memory) {
        return StoryProtocolAddresses({
            ipAssetRegistry: 0x77319B4031e6eF1250907aa00018B8B1c67a244b,
            royaltyModule: 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086,
            licensingModule: 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f,
            pilTemplate: 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316,
            wipToken: 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E,
            royaltyPolicyLRP: 0x9156e603C949481883B1d3355c6f1132D191fC41
        });
    }
    
    /// @dev Story Mainnet addresses
    function getMainnetConfig() internal pure returns (StoryProtocolAddresses memory) {
        return StoryProtocolAddresses({
            ipAssetRegistry: 0x77319B4031e6eF1250907aa00018B8B1c67a244b,
            royaltyModule: 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086,
            licensingModule: 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f,
            pilTemplate: 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316,
            wipToken: 0x1514000000000000000000000000000000000000,
            royaltyPolicyLRP: 0x9156e603C949481883B1d3355c6f1132D191fC41
        });
    }
    
    /// @dev 체인 ID별 설정 가져오기
    function getConfig(uint256 chainId) internal pure returns (StoryProtocolAddresses memory) {
        if (chainId == 1315) {
            // Aeneid Testnet
            return getAeneidTestnetConfig();
        } else if (chainId == 1514) {
            // Story Mainnet
            return getMainnetConfig();
        } else {
            revert("Unsupported network");
        }
    }
} 
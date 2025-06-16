// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Makgora.sol";
import "../src/MakgoraNFT.sol";
import "../src/config/MakgoraAddressesProvider.sol";
import "../src/libraries/MakgoraStorage.sol";
import "../src/libraries/BreedingLogic.sol";
import "../src/libraries/CreatureLogic.sol";
import "../src/libraries/BattleLogic.sol";
import "../src/libraries/Constants.sol";
import "./helpers/NetworkConfig.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol"; 

// Story Protocol Interfaces
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface MockERC20 {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function deposit() external payable;
}

contract MakgoraTest is Test {
    using Math for uint256;

    // --- 이벤트 정의 ---
    event ServerAddressUpdated(address indexed newServerAddress);
    // --- Actor Addresses ---
    address contractOwner; // Makgora 컨트랙트 배포자 및 초기 Owner
    address server;
    address user1;
    address user2;
    address user3;

    // --- Contract Instances ---
    MakgoraAddressesProvider public addressesProvider;
    Makgora public makgora;
    MakgoraNFT public nft;
    MockERC20 public paymentToken; // WIP 토큰으로 사용될 Mock ERC20

    // --- 테스트 상수 ---
    uint256 constant BASE_MINT_PRICE = 0.1 ether;
    uint256 constant SYSTEM_FEE_PERCENTAGE = 10; // 10%
    uint256 constant REVENUE_SHARE_PERCENTAGE = 50; // 50%

    function setUp() public {
        // etch IPGraph
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        _setupAccounts();
        _deployContracts();
    }

    // --- 테스트 셋업 헬퍼 함수 ---
    function _setupAccounts() internal {
        contractOwner = makeAddr("contractOwner");
        server = makeAddr("server");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
    }

    function _deployContracts() internal {
        NetworkConfig.StoryProtocolAddresses memory config;
        
        if (block.chainid == 1315) {
            config = NetworkConfig.getAeneidTestnetConfig();
        } else {
            config = NetworkConfig.getMainnetConfig();
        }
        
        vm.startPrank(contractOwner);
        paymentToken = MockERC20(config.wipToken);
        
        // 주소 제공자 컨트랙트 배포
        addressesProvider = new MakgoraAddressesProvider(contractOwner);
        
        // 주요 주소 설정
        addressesProvider.setAddress(Constants.PAYMENT_TOKEN_ID, address(paymentToken));
        addressesProvider.setAddress(Constants.IP_ASSET_REGISTRY_ID, config.ipAssetRegistry);
        addressesProvider.setAddress(Constants.ROYALTY_MODULE_ID, config.royaltyModule);
        addressesProvider.setAddress(Constants.LICENSING_MODULE_ID, config.licensingModule);
        addressesProvider.setAddress(Constants.PIL_TEMPLATE_ID, config.pilTemplate);
        addressesProvider.setAddress(Constants.ROYALTY_POLICY_LRP_ID, config.royaltyPolicyLRP);
        
        // Makgora 컨트랙트 배포
        makgora = new Makgora("Makgora Creatures", "MKCR", server, address(addressesProvider));
        
        // NFT 컨트랙트 참조 설정
        nft = MakgoraNFT(makgora.makgoraNFT());
        
        vm.stopPrank();
    }

    // --- 크리처 생성/관리 헬퍼 함수 ---
    
    // 제네시스 크리처 생성 헬퍼 함수 (Scratch 민팅)
    function _mintGenesis(
        address user,
        string memory name,
        string memory prompt
    ) internal returns (uint256) {
        bytes memory encryptedPrompt = bytes(prompt);
        
        vm.startPrank(user);
        paymentToken.approve(address(makgora), BASE_MINT_PRICE);
        if (block.chainid == 1315) {
            paymentToken.mint(user, BASE_MINT_PRICE);  
        } else {
            vm.deal(user, BASE_MINT_PRICE);
            paymentToken.deposit{value: BASE_MINT_PRICE}();
        }
        
        // mintGenesis 함수 호출 방식 업데이트
        (address ipId, uint256 tokenId) = makgora.mintGenesis(user, name, encryptedPrompt);
        
        vm.stopPrank();
        
        return tokenId;
    }
    
    // 크리처 Roar 헬퍼 함수
    function _roarCreature(address user, uint256 creatureId) internal {
        vm.startPrank(user);
        makgora.roar(creatureId);
        vm.stopPrank();
        
        // 크리처가 실제로 roared 상태인지 확인
        MakgoraStorage.Creature memory creature = makgora.getCreature(creatureId);
        assertTrue(creature.roared, "Creature should be in roared state");
    }
    
    // --- 배틀 관련 헬퍼 함수 ---
    
    // 배틀 준비 및 승자 결정 헬퍼 함수
    function _setupBattleAndResolve(
        uint256 creature1Id, 
        uint256 creature2Id, 
        uint256 winnerId
    ) internal returns (uint256 battleId) {
        // 두 크리처를 Roar 상태로 만들어 배틀 시작
        address creature1Owner = nft.ownerOf(creature1Id);
        address creature2Owner = nft.ownerOf(creature2Id);
        
        _roarCreature(creature1Owner, creature1Id);
        _roarCreature(creature2Owner, creature2Id);
        
        // 배틀 ID 계산 (첫 번째 배틀은 0)
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        battleId = ds.nextBattleId;
        
        // 배틀 존재 확인
        MakgoraStorage.Battle memory battle = makgora.getBattle(battleId);
        
        uint256 loserId = (winnerId == creature1Id) ? creature2Id : creature1Id;
        
        vm.prank(server);
        makgora.resolveBattle(battleId, winnerId);
        
        // 배틀 결과 검증
        battle = makgora.getBattle(battleId);
        assertTrue(battle.resolved, "Battle should be resolved");
        assertEq(battle.winnerId, winnerId, "Winner mismatch");
        
        // 패자 NFT 소각 확인
        vm.expectRevert();
        nft.ownerOf(loserId);
        
        // 승자의 상태 확인 (로어 상태 해제)
        assertFalse(makgora.isRoared(winnerId), "Winner should not be roared after battle");
        
        return battleId;
    }
    
    // 완전한 배틀 시나리오 실행 (제네시스 생성부터 배틀 결과까지)
    function _setupFullBattleScenario() internal returns (
        uint256 victorId, 
        MakgoraStorage.Creature memory victorCreature,
        uint256 breedingPoolId
    ) {
        // 두 생물체 생성
        victorId = _mintGenesis(user1, "victor_name", "victor_prompt");
        uint256 loserId = _mintGenesis(user2, "loser_name", "loser_prompt");
        
        // 배틀 시작 및 결과 처리 (creature1이 승리)
        uint256 battleId = _setupBattleAndResolve(victorId, loserId, victorId);
        
        // 승자 정보 가져오기
        victorCreature = makgora.getCreature(victorId);
        assertEq(victorCreature.winCount, 1, "Victor's win count should be increased");
        
        // 브리딩 풀 ID는 일반적으로 battleId와 동일하다고 가정
        breedingPoolId = battleId;
        
        return (victorId, victorCreature, breedingPoolId);
    }
    
    // --- 브리딩 관련 헬퍼 함수 ---
    
    // 브리딩 요청 헬퍼 함수 (Remix 민팅)
    function _requestBreeding(
        address requester, 
        uint256 parentTokenId,
        string memory prompt
    ) internal {
        uint256 expectedCost = makgora.getBreedingFee(parentTokenId);
        console.log("expectedCost for breeding", expectedCost);

        // 요청자에게 충분한 토큰 지급
        vm.startPrank(requester);
        paymentToken.approve(address(makgora), expectedCost);
        if (block.chainid == 1315) {
            paymentToken.mint(requester, expectedCost);  
        } else {
            vm.deal(requester, expectedCost);
            paymentToken.deposit{value: expectedCost}();
        }

        // 요청 전 잔액 확인
        uint256 contractBalanceBefore = paymentToken.balanceOf(address(makgora));
        uint256 requesterBalanceBefore = paymentToken.balanceOf(requester);
        
        // 문자열을 bytes로 변환
        bytes memory promptBytes = bytes(prompt);
        
        // 기존 함수 시그니처에 맞게 호출
        makgora.requestBreeding(parentTokenId, promptBytes);
        vm.stopPrank();
        
        // 결제 확인
        uint256 contractBalanceAfter = paymentToken.balanceOf(address(makgora));
        uint256 requesterBalanceAfter = paymentToken.balanceOf(requester);

        // assertEq(
        //     contractBalanceAfter - contractBalanceBefore, 
        //     expectedCost.mulDiv(10, 100),
        //     "Contract should receive exact fee"
        // );
        // assertEq(
        //     requesterBalanceBefore - requesterBalanceAfter, 
        //     payment, 
        //     "Requester should pay exact breeding cost"
        // );
    }
    
    // 브리딩 실행 헬퍼 함수
    function _executeBreeding(
        uint256 requestId, 
        string memory childName,
        string memory childPrompt
    ) internal returns (uint256 childTokenId) {
        vm.startPrank(server);
        // 기존 함수 시그니처에 맞게 호출
        bytes memory encryptedPrompt = bytes(childPrompt);
        (, uint256 childTokenId) = makgora.executeBreeding(requestId, childName, encryptedPrompt);
        vm.stopPrank();
        
        return childTokenId;
    }
    
    // 자식 크리처 검증 헬퍼 함수
    function _verifyChildCreature(
        uint256 childTokenId, 
        uint256 parentId, 
        uint256 parentGeneration, 
        address expectedOwner
    ) internal {
        // 자식 크리처의 소유자 확인
        assertEq(nft.ownerOf(childTokenId), expectedOwner, "Child NFT owner should be the expected owner");
        
        // 자식 크리처의 상태 확인
        MakgoraStorage.Creature memory childCreature = makgora.getCreature(childTokenId);
        assertTrue(childCreature.exists, "Child creature should exist");
        assertEq(childCreature.parentId, parentId, "Child's parent ID should match");
        assertEq(childCreature.generation, parentGeneration + 1, "Child generation should be parent's + 1");
        assertFalse(childCreature.roared, "Child should not be roared initially");
    }

    // --- 테스트 케이스 ---
    
    function test_SetUp_CorrectOwnerAndServer() public {
        assertEq(makgora.owner(), contractOwner);
        assertEq(makgora.serverAddress(), server);
        assertEq(nft.owner(), address(makgora));
    }

    function test_Fail_SetServerAddress_NotOwner() public {
        vm.startPrank(user1); // Not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        makgora.setServerAddress(user2);
        vm.stopPrank();
    }

    function test_MintGenesis_Success() public {
        uint256 tokenId = _mintGenesis(user1, "genesis_name", "genesis_prompt");
        
        // 기본 검증
        assertTrue(tokenId >= 0, "Token ID should be valid");
        assertEq(nft.ownerOf(tokenId), user1, "NFT owner should be user1");
    }

    function test_RoarAndBattle_And_TransferRestriction() public {
        // 1. 두 크리처 생성
        uint256 creature1Id = _mintGenesis(user1, "g1_name", "g1_prompt");
        uint256 creature2Id = _mintGenesis(user2, "g2_name", "g2_prompt");
        
        // 2. 첫 번째 크리처 Roar 및 전송 제한 테스트
        _roarCreature(user1, creature1Id);
        
        vm.startPrank(user1);
        vm.expectRevert("MakgoraNFT: Creature is roared and cannot be transferred.");
        nft.transferFrom(user1, user3, creature1Id);
        vm.stopPrank();
        
        // 3. 두 번째 크리처 Roar
        _roarCreature(user2, creature2Id);
        
        // 4. 서버가 배틀 매칭 및 결과 처리
        vm.startPrank(server);
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        uint256 battleId = ds.nextBattleId;
        
        makgora.resolveBattle(battleId, creature1Id);
        vm.stopPrank();
     
        // 7. 배틀 후에는 전송이 가능해야 함
        vm.startPrank(user1);
        nft.transferFrom(user1, user3, creature1Id);
        vm.stopPrank();
        
        assertEq(nft.ownerOf(creature1Id), user3, "NFT should be transferred to user3");
    }
    
    function test_Breeding() public returns (uint256 childTokenId) {
        // 1. 민팅
        uint256 parentTokenId = _mintGenesis(user1, "genesis_name", "genesis_prompt");

        // 3. 브리딩 요청
        _requestBreeding(user2, parentTokenId, "breeding_prompt");
        
        // 4. 브리딩 실행
        MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
        uint256 requestId = ds.nextBreedingRequestId;
        childTokenId = _executeBreeding(requestId, "child_from_genesis_name", "child_from_genesis_prompt");
        
        // 5. 자식 크리처 검증
        _verifyChildCreature(childTokenId, parentTokenId, 0, user2);
        
        // 6. 부모 크리처의 mintCount 증가 확인
        MakgoraStorage.Creature memory parentCreature = makgora.getCreature(parentTokenId);
        assertEq(parentCreature.mintCount, 1, "Parent's mint count should be increased");

        return childTokenId;
    }

    function test_Breeding_Multiple() public {
        test_Breeding();

        uint256 parentTokenId = 0;

        for (uint256 i = 0; i < 10; i++) {
            string memory prompt = string.concat("more_breeding_prompt", Strings.toString(i));
            _requestBreeding(user3, parentTokenId, prompt);
            // 4. 브리딩 실행
            // MakgoraStorage.Layout storage ds = MakgoraStorage.layout();

            uint256 requestId = i+1;
            string memory childName = string.concat("more_child_from_genesis_name", Strings.toString(i));
            string memory encryptedChildPrompt = string.concat("more_child_from_genesis_prompt", Strings.toString(i));
            uint256 childTokenId = _executeBreeding(requestId, childName, encryptedChildPrompt);
            
            // 5. 자식 크리처 검증
            _verifyChildCreature(childTokenId, parentTokenId, 0, user3);
            
            // 6. 부모 크리처의 mintCount 증가 확인
            MakgoraStorage.Creature memory parentCreature = makgora.getCreature(parentTokenId);
            assertEq(parentCreature.mintCount, i + 2, "Parent's mint count should be increased");
        }
    }

    function test_Breeding_Continuously() public {
        uint256 parentTokenId = test_Breeding();

        for (uint256 i = 0; i < 10; i++) {
            string memory prompt = string.concat("more_breeding_prompt", Strings.toString(i));
            _requestBreeding(user3, parentTokenId, prompt);        

            // 4. 브리딩 실행
            MakgoraStorage.Layout storage ds = MakgoraStorage.layout();
            // uint256 requestId = ds.nextBreedingRequestId;
            uint256 requestId = i+1;
            string memory childName = string.concat("more_child_from_genesis_name", Strings.toString(i));
            string memory encryptedChildPrompt = string.concat("more_child_from_genesis_prompt", Strings.toString(i));
            uint256 childTokenId = _executeBreeding(requestId, childName, encryptedChildPrompt);

            // 5. 자식 크리처 검증
            _verifyChildCreature(childTokenId, parentTokenId, i + 1, user3);

            // 6. 부모 크리처의 mintCount 증가 확인
            MakgoraStorage.Creature memory parentCreature = makgora.getCreature(parentTokenId);
            assertEq(parentCreature.mintCount, 1, "Parent's mint count should be increased");
            
            parentTokenId = childTokenId;
        }
    }

} 
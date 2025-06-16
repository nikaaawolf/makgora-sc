// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Makgora.sol";
import "../src/MakgoraNFT.sol";
import "../src/config/MakgoraAddressesProvider.sol";
import "../src/libraries/Constants.sol";
import "../test/helpers/NetworkConfig.sol";

interface MockERC20 {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function deposit() external payable;
}

contract DeployScript is Script {
    address contractOwner;
    address server;
    address user1;

    // --- Contract Instances ---
    MakgoraAddressesProvider public addressesProvider;
    Makgora public makgora;
    MakgoraNFT public nft;
    MockERC20 public paymentToken; // WIP 토큰으로 사용될 Mock ERC20
    NetworkConfig.StoryProtocolAddresses public config;

    // --- 테스트 상수 ---
    uint256 constant BASE_MINT_PRICE = 0.1 ether;
    uint256 constant SYSTEM_FEE_PERCENTAGE = 10; // 10%
    uint256 constant REVENUE_SHARE_PERCENTAGE = 50; // 50%

    mapping(address => uint256) public userPrivateKeys;

    function setUp() public {
        contractOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        server = vm.addr(vm.envUint("PRIVATE_KEY2"));
        user1 = vm.addr(vm.envUint("PRIVATE_KEY3"));

        console.log("contractOwner: ", contractOwner);
        console.log("server: ", server);
        console.log("user1: ", user1);

        userPrivateKeys[contractOwner] = vm.envUint("PRIVATE_KEY");
        userPrivateKeys[server] = vm.envUint("PRIVATE_KEY2");
        userPrivateKeys[user1] = vm.envUint("PRIVATE_KEY3");

        if (block.chainid == 1315) {
            config = NetworkConfig.getAeneidTestnetConfig();
        } else {
            config = NetworkConfig.getMainnetConfig();
        }
        
        paymentToken = MockERC20(config.wipToken);

    }

    function deployContracts() public {
        vm.startBroadcast(userPrivateKeys[contractOwner]);
        vm.txGasPrice(2);
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
        nft = makgora.makgoraNFT();

        console.log("Makgora deployed at: ", address(makgora));
        console.log("MakgoraNFT deployed at: ", address(nft));
        vm.stopBroadcast();
    }

    function _mintGenesis(
        address user,
        string memory name,
        string memory prompt
    ) internal returns (uint256) {
        bytes memory encryptedPrompt = bytes(prompt);
        
        vm.startBroadcast(userPrivateKeys[user]);
        paymentToken.approve(address(makgora), BASE_MINT_PRICE);
        if (block.chainid == 1315) {
            paymentToken.mint(user, BASE_MINT_PRICE);  
        } else {
            paymentToken.deposit{value: BASE_MINT_PRICE}();
        }
        
        // mintGenesis 함수 호출 방식 업데이트
        (address ipId, uint256 tokenId) = makgora.mintGenesis(user, name, encryptedPrompt);
        vm.stopBroadcast();
        return tokenId;
    }
    
    // 크리처 Roar 헬퍼 함수
    function _roarCreature(address user, uint256 creatureId) internal {
        vm.startBroadcast(userPrivateKeys[user]);
        makgora.roar(creatureId);
        vm.stopBroadcast();
    }

    function run() public {
        // deployContracts();
        makgora = Makgora(0xdf5aFeCE5A59EDc84D60498ADf91718049f5537C);
        nft = MakgoraNFT(0xAe5b3084476b551687Eb33b5349A0b081a5fb6b2);

        _mintGenesis(contractOwner, "g1_name", "g1_prompt");
    }
} 
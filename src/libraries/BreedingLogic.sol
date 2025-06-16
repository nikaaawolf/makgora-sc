// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MakgoraStorage.sol";
import "./CreatureLogic.sol"; // for canCreatureBreed
import "../config/MakgoraAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol"; 

library BreedingLogic {
    using Math for uint256;

    uint256 constant BASE_MINT_PRICE = 0.1 ether; // Base mint price

    event MintCompleted(uint256 indexed tokenId, address indexed owner, bytes indexed encryptedPrompt);
    event BreedingRequested(uint256 indexed requestId, uint256 indexed parentId, bytes indexed encryptedPrompt);
    event BreedingCompleted(uint256 indexed requestId, uint256 indexed childTokenId, address indexed to);

    error PromptAlreadyRegistered(bytes32 hashedPrompt, address owner);
    error BreedingRequestAlreadyProcessed(uint256 requestId);

    bytes32 constant PAYMENT_TOKEN_ID = keccak256("PAYMENT_TOKEN"); // Directly define constant similar to IPLogic.sol

    function registerPrompt(
        MakgoraStorage.Layout storage ds,
        bytes calldata encryptedPrompt
    ) internal {
        // 1) Compress the entire encryptedData with keccak256 hash
        bytes32 hashedPrompt = keccak256(encryptedPrompt);

        // 2) Check if the same hash is already registered, and if so, if it belongs to msg.sender
        if (ds.promptOwner[hashedPrompt] != address(0) && ds.promptOwner[hashedPrompt] != msg.sender) {
            revert PromptAlreadyRegistered(hashedPrompt, ds.promptOwner[hashedPrompt]);
        }

        // 3) If not registered, store the current msg.sender address
        ds.promptOwner[hashedPrompt] = msg.sender;
    }

    function transferRoyalty(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        uint256 targetId,
        uint256 amount
    ) internal {
        address royaltyModule = addressesProvider.getRoyaltyModule();
        address paymentToken = addressesProvider.getPaymentToken();

        MakgoraStorage.Creature storage targetCreature = ds.creatures[targetId];
        address targetVault = IRoyaltyModule(royaltyModule).ipRoyaltyVaults(targetCreature.ipId);
        if (targetVault == address(0)) {
            address owner = IERC721(ds.makgoraNFT).ownerOf(targetId);
            IERC20(paymentToken).transfer(owner, amount);
        } else {
            IERC20(paymentToken).approve(royaltyModule, amount);
            IRoyaltyModule(royaltyModule).payRoyaltyOnBehalf(targetCreature.ipId, address(0), paymentToken, amount);
        }
    }


    function chargeMintingFee(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        uint256 mintingFee
    ) internal returns (uint256 parentFee) {
        address paymentToken = addressesProvider.getPaymentToken();

        require(IERC20(paymentToken).transferFrom(msg.sender, address(this), mintingFee), "Payment failed");

        uint256 protocolFee = mintingFee.mulDiv(10, 100);
        parentFee = mintingFee - protocolFee;
        
        MakgoraStorage.Creature storage alphaCreature = ds.creatures[ds.currentAlphaId];
        if (alphaCreature.exists) {
            uint256 alphaFee = BASE_MINT_PRICE.mulDiv(90, 100);
            transferRoyalty(ds, addressesProvider, ds.currentAlphaId, alphaFee);
            parentFee -= alphaFee;
        }
        return parentFee;
    }

    function chargeBreedingFee(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        uint256 mintCount
    ) internal {
        uint256 breedingFee = calculateBreedingPrice(mintCount);
        uint256 parentFee = chargeMintingFee(ds, addressesProvider, breedingFee);
        // IRoyaltyModule(addressesProvider.getAddress(Constants.ROYALTY_MODULE_ID)).payRoyaltyOnBehalf(ds.tokenToIpId[parentId], address(0), addressesProvider.getAddress(Constants.PAYMENT_TOKEN_ID), revenue);
    }
    
    function handleMintGenesis(
        MakgoraStorage.Layout storage ds, 
        uint256 tokenId,
        string memory name,
        bytes calldata encryptedPrompt
    ) internal {
        CreatureLogic.addCreature(ds, tokenId, ds.tokenToIpId[tokenId], name, encryptedPrompt);

        emit MintCompleted(tokenId, msg.sender, encryptedPrompt);
    }

    function handleRequestBreeding(
        MakgoraStorage.Layout storage ds,
        uint256 parentId,
        bytes calldata encryptedPrompt
    ) internal {
        registerPrompt(ds, encryptedPrompt);

        uint256 requestId = ds.nextBreedingRequestId++;
        ds.breedingRequests[requestId] = MakgoraStorage.BreedingRequest({
            requester: msg.sender,
            parentId: parentId,
            processed: false
        });
        emit BreedingRequested(requestId, parentId, encryptedPrompt);
    }

    function handleExecuteBreeding(
        MakgoraStorage.Layout storage ds, 
        uint256 requestId,
        uint256 childTokenId,
        string memory name,
        bytes calldata encryptedPrompt
    ) internal {
        MakgoraStorage.BreedingRequest storage request = ds.breedingRequests[requestId];
        if (request.processed) {
            revert BreedingRequestAlreadyProcessed(requestId);
        }

        uint256 parentId = ds.breedingRequests[requestId].parentId;
        ds.creatures[parentId].mintCount++;
        CreatureLogic.addCreature(ds, childTokenId, ds.tokenToIpId[childTokenId], parentId, name, encryptedPrompt);
        
        request.processed = true; // 민트 완료 처리
        emit BreedingCompleted(requestId, childTokenId, msg.sender);
    }

    function calculateBreedingPrice(uint256 mintCount) internal pure returns (uint256) {
        // Remix(부모 있을시) 비용 0.2 ETH로 시작
        uint256 basePrice = 2 * BASE_MINT_PRICE;
        
        // PRBMath 라이브러리를 사용하여 계산
        // 1. mintCount/10을 UD60x18 타입으로 변환
        UD60x18 tierUD = ud(mintCount).div(ud(10));
        
        // 2. 2^tier 계산
        UD60x18 powerOfTwoUD = tierUD.exp2();
        
        // 3. 결과를 uint256으로 변환하여 basePrice와 곱함
        uint256 powerOfTwo = powerOfTwoUD.unwrap();
        
        // 최종 가격 계산 (1e18로 나누어 스케일링 조정)
        return (basePrice * powerOfTwo) / 1e18;
    }
} 
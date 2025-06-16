// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MakgoraStorage.sol";
import "../config/MakgoraAddressesProvider.sol";
import { Constants } from "./Constants.sol";
import "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate, PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import "@storyprotocol/core/lib/PILFlavors.sol"; // Import PILFlavors

// Removed local IIPAssetRegistry interface definition
/*
interface IIPAssetRegistry {
    function register(address tokenContract, uint256 tokenId, string calldata metadataURI, bytes calldata metadataHash, address deadSignalAddress) external returns (address ipId);
    function registerDerivative(address childTokenContract, uint256 childTokenId, address[] calldata parentIpIds, bytes calldata licenseTermsIds, string calldata metadataURI, bytes calldata metadataHash, address deadSignalAddress) external returns (address childIpId);
    function ipAccount(address tokenContract, uint256 tokenId) external view returns (address);
}
*/

library IPLogic {
    event GlobalDerivativeLicenseTermsRegistered(uint256 indexed licenseTermsId);

    error IPAlreadyRegistered(uint256 tokenId, address existingIpId);
    error ParentIPNotFound(uint256 parentTokenId);
    error AddressNotSetInProvider(bytes32 id);
    error GlobalDerivativeTermsNotSet();

    // 전역 파생 라이선스 조건 등록 (50% 부모, 50% 자식 가정)
    function _ensureGlobalDerivativeLicenseTermsRegistered(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        IPILicenseTemplate pilTemplate
    ) internal returns (uint256) {
        if (ds.globalDerivativeLicenseTermsId == 0) {
            address royaltyPolicyLRPAddr = addressesProvider.getRoyaltyPolicyLRP();
            if (royaltyPolicyLRPAddr == address(0)) revert AddressNotSetInProvider(Constants.ROYALTY_POLICY_LRP_ID);

            address paymentTokenAddr = addressesProvider.getPaymentToken();
            if (paymentTokenAddr == address(0)) revert AddressNotSetInProvider(Constants.PAYMENT_TOKEN_ID);

            
            PILTerms memory derivativeTerms = PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 50 * 10 ** 6,
                royaltyPolicy: royaltyPolicyLRPAddr,
                currencyToken: paymentTokenAddr
            });
            
            ds.globalDerivativeLicenseTermsId = pilTemplate.registerLicenseTerms(derivativeTerms);
            emit GlobalDerivativeLicenseTermsRegistered(ds.globalDerivativeLicenseTermsId);
        }
        return ds.globalDerivativeLicenseTermsId;
    }

    // Genesis IP 등록 및 기본 라이선스 조건 연결 (NonCommercial Social Remixing)
    function registerGenesisIP(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        uint256 tokenId
    ) internal returns (address ipId) {
        // Provider를 통해 주소 가져오기
        address ipAssetRegistryAddr = addressesProvider.getIPAssetRegistry();
        if (ipAssetRegistryAddr == address(0)) revert AddressNotSetInProvider(Constants.IP_ASSET_REGISTRY_ID);
        IIPAssetRegistry ipAssetRegistry = IIPAssetRegistry(ipAssetRegistryAddr);

        address licensingModuleAddr = addressesProvider.getLicensingModule();
        if (licensingModuleAddr == address(0)) revert AddressNotSetInProvider(Constants.LICENSING_MODULE_ID);
        ILicensingModule licensingModule = ILicensingModule(licensingModuleAddr);

        address pilTemplateAddr = addressesProvider.getPilTemplate();
        if (pilTemplateAddr == address(0)) revert AddressNotSetInProvider(Constants.PIL_TEMPLATE_ID);
        IPILicenseTemplate pilTemplate = IPILicenseTemplate(pilTemplateAddr);

        // 1. 전역 파생 라이선스 조건이 등록되었는지 확인/등록
        _ensureGlobalDerivativeLicenseTermsRegistered(ds, addressesProvider, pilTemplate);

        // 2. IP 등록
        ipId = ipAssetRegistry.register(block.chainid, ds.makgoraNFT, tokenId);
        ds.tokenToIpId[tokenId] = ipId;
        ds.ipIdToToken[ipId] = tokenId;

        licensingModule.attachLicenseTerms(ipId, address(pilTemplate), ds.globalDerivativeLicenseTermsId);
        
        return ipId;
    }

    // 파생 IP 등록
    function registerDerivativeIP(
        MakgoraStorage.Layout storage ds,
        MakgoraAddressesProvider addressesProvider,
        uint256 childTokenId,
        uint256 parentTokenId
    ) internal returns (address childIpId) {
        address parentIpId = ds.tokenToIpId[parentTokenId];
        if (parentIpId == address(0)) {
            revert ParentIPNotFound(parentTokenId);
        }

        if (ds.globalDerivativeLicenseTermsId == 0) revert GlobalDerivativeTermsNotSet();

        address ipAssetRegistryAddr = addressesProvider.getIPAssetRegistry();
        if (ipAssetRegistryAddr == address(0)) revert AddressNotSetInProvider(Constants.IP_ASSET_REGISTRY_ID);
        IIPAssetRegistry ipAssetRegistry = IIPAssetRegistry(ipAssetRegistryAddr);

        address licensingModuleAddr = addressesProvider.getLicensingModule();
        if (licensingModuleAddr == address(0)) revert AddressNotSetInProvider(Constants.LICENSING_MODULE_ID);
        ILicensingModule licensingModule = ILicensingModule(licensingModuleAddr);
        
        address pilTemplateAddr = addressesProvider.getPilTemplate();
        if (pilTemplateAddr == address(0)) revert AddressNotSetInProvider(Constants.PIL_TEMPLATE_ID);
        // IPILicenseTemplate pilTemplate = IPILicenseTemplate(pilTemplateAddr); // mintLicenseTokens 호출 시 template 주소만 필요

        // 1. 파생 IP 등록
        childIpId = ipAssetRegistry.register(block.chainid, ds.makgoraNFT, childTokenId);
        ds.tokenToIpId[childTokenId] = childIpId;
        ds.ipIdToToken[childIpId] = childTokenId;
        
        // 2. 전역 파생 라이선스 조건 ID를 사용하여 라이선스 토큰 민팅
        uint256 derivativeLicenseTermsIdToUse = ds.globalDerivativeLicenseTermsId;

        uint256 licenseTokenId = licensingModule.mintLicenseTokens(
            parentIpId,                 // 라이선스를 제공하는 부모 IP
            pilTemplateAddr,            // 사용할 라이선스 템플릿 주소
            derivativeLicenseTermsIdToUse, // 저장된 전역 파생 라이선스 조건 ID
            1,                          // 민팅할 라이선스 토큰 수량
            address(this),                 // 라이선스 토큰 수령자 (파생 IP 소유자)
            bytes(""),                  // royaltyContext
            0,                          // maxMintingFee
            0                           // maxRevenueShare (PIL.PILTerms에 이미 정의되어 있음)
        );
        
        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = licenseTokenId;

        // 3. 파생 IP로 라이선스 연결 (registerDerivativeWithLicenseTokens 사용)
        licensingModule.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: bytes(""),
            maxRts: 0
        });

        return childIpId;
    }
} 
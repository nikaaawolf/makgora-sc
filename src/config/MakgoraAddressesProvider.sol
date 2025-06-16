// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/Constants.sol";

contract MakgoraAddressesProvider is Ownable {

    mapping(bytes32 => address) private addresses;

    event AddressSet(bytes32 indexed id, address indexed newAddress, address indexed oldAddress);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setAddress(bytes32 id, address newAddress) external onlyOwner {
        address oldAddress = addresses[id];
        addresses[id] = newAddress;
        emit AddressSet(id, newAddress, oldAddress);
    }
    
    function getAddress(bytes32 id) external view returns (address) {
        return addresses[id];
    }

    // Convenience Getter functions
    function getIPAssetRegistry() external view returns (address) {
        return addresses[Constants.IP_ASSET_REGISTRY_ID];
    }

    function getRoyaltyModule() external view returns (address) {
        return addresses[Constants.ROYALTY_MODULE_ID];
    }

    function getLicensingModule() external view returns (address) {
        return addresses[Constants.LICENSING_MODULE_ID];
    }

    function getPilTemplate() external view returns (address) {
        return addresses[Constants.PIL_TEMPLATE_ID];
    }

    function getPaymentToken() external view returns (address) {
        return addresses[Constants.PAYMENT_TOKEN_ID];
    }

    function getRoyaltyPolicyLRP() external view returns (address) {
        return addresses[Constants.ROYALTY_POLICY_LRP_ID];
    }
} 
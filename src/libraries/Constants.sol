pragma solidity ^0.8.19;

library Constants {
    bytes32 public constant IP_ASSET_REGISTRY_ID = keccak256("IP_ASSET_REGISTRY"); 
    bytes32 public constant LICENSE_TERMS_REGISTRY_ID = keccak256("LICENSE_TERMS_REGISTRY");
    bytes32 public constant ROYALTY_MODULE_ID = keccak256("ROYALTY_MODULE");
    bytes32 public constant LICENSING_MODULE_ID = keccak256("LICENSING_MODULE");
    bytes32 public constant PIL_TEMPLATE_ID = keccak256("PIL_TEMPLATE");
    bytes32 public constant PAYMENT_TOKEN_ID = keccak256("PAYMENT_TOKEN_ID");
    bytes32 public constant ROYALTY_POLICY_LRP_ID = keccak256("ROYALTY_POLICY_LRP");
}
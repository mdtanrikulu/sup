// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-sup/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-sup/proxy/ERC1967/ERC1967Utils.sol";

contract SingleTimeUpgradableProxy is ERC1967Proxy {
    // Custom storage slot for admin (EIP-1967 compatible)
    // ref: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0d0e4aabdbd6e5994d52048fe42832fc334c6d1f/contracts/proxy/ERC1967/ERC1967Utils.sol#L83C31-L83C41
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 private constant _UPGRADED_SLOT = keccak256("SingleTimeUpgradableProxy.upgraded");

    // Custom errors
    error CallerNotAdmin();
    error UpgradeAlreadyPerformed();
    error InvalidImplementation();
    error SameImplementation();

    event UpgradeRevoked(address indexed admin);

    modifier onlyAdmin() {
        if (msg.sender != _getAdmin()) revert CallerNotAdmin();
        _;
    }

    constructor(address admin_, address logic_, bytes memory data_) ERC1967Proxy(logic_, data_) {
        ERC1967Utils.changeAdmin(admin_);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable onlyAdmin {
        if (StorageSlot.getBooleanSlot(_UPGRADED_SLOT).value) {
            revert UpgradeAlreadyPerformed();
        }

        _validateImplementation(newImplementation);
        StorageSlot.getBooleanSlot(_UPGRADED_SLOT).value = true;

        ERC1967Utils.upgradeToAndCall(newImplementation, data);
        _revokeAdmin();
    }

    /// @notice Validates the new implementation contract
    function _validateImplementation(address newImplementation) internal view {
        if (newImplementation.code.length == 0) revert InvalidImplementation();
        if (ERC1967Utils.getImplementation() == newImplementation) {
            revert SameImplementation();
        }
    }

    /// @notice Returns current implementation address
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function admin() external view returns (address) {
        return _getAdmin();
    }

    function _revokeAdmin() internal {
        address previousAdmin = _getAdmin();
        // Bypass ERC1967Utils checks by writing directly to storage
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = address(0);

        // this can be emitted as well as part of EIP-1967 compatibility
        // emit IERC1967.AdminChanged(previousAdmin, address(0));
        emit UpgradeRevoked(previousAdmin);
    }

    function _getAdmin() internal view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    fallback() external payable override {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}

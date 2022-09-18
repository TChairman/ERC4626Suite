// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626AssetBase.sol";
import "../liabilities/ERC4626Tranche.sol"; // TODO: replace with interface

/// @notice Support for ERC4626 tranche investments
/// @notice Manager decides when and how much to invest in the tranche, and periodically sweeps coupons and distributions
/// @notice influenced by a ERC4626 multi-vault standard, something like this: https://github.com/superform-xyz/experimental-4626/blob/main/contracts/MultiVault.sol

abstract contract ERC4626AssetTranche is ERC4626AssetBase {
    using Math for uint256;

    // Events
    bytes32 public constant TRANCHE_ASSET = keccak256("TRANCHE_ASSET");

    constructor() {
    }

    function getLatestNAV(assetStruct storage asset) internal view virtual override returns (uint256) {
        if (asset.assetType == TRANCHE_ASSET) {
            return ERC4626Tranche(asset.assetAddress).balanceOf(asset.id, address(this));
        } else {
            return super.getLatestNAV(asset);
        }
    }

    function attachERC4626Tranche(ERC4626Tranche _vault, uint256 _vaultID, uint256 _expectedReturnBPS) public virtual onlyManager {
        require(_vault.asset() == asset(), "Investment asset does not match vault");
        require(_vault.maxDeposit(address(this)) > 0, "Cannot deposit to vault");
        require(createAsset(TRANCHE_ASSET, address(_vault), _vaultID, 0, 0, _expectedReturnBPS), "vault already attached");
    }

    function depositERC4626Tranche(ERC4626Tranche _vault, uint256 _vaultID, uint256 _assets) public virtual onlyManager returns (uint256 _shares) {
        uint32 index = assetIndex(address(_vault), _vaultID);
        require(index > 0, "tranche not found");
        _shares = _vault.deposit(_vaultID, _assets, address(this));
        assetList[index].parValue += _shares;
        assetList[index].netValue += _shares;
    }

    function withdrawERC4626Tranche(ERC4626Tranche _vault, uint256 _vaultID, uint256 _assets) public virtual onlyManager returns (uint256 _shares) {
        uint32 index = assetIndex(address(_vault), _vaultID);
        require(index > 0, "tranche not found");
        _shares = _vault.withdraw(_vaultID, _assets, address(this), address(this));
        assetList[index].parValue -= _shares;
        assetList[index].netValue -= _shares;
    }

    function sweepERC4626Tranche(ERC4626Tranche _vault, uint256 _vaultID) public virtual onlyManager returns (uint256 _shares) {
        return withdrawERC4626Tranche(_vault, _vaultID, _vault.maxWithdraw(_vaultID, address(this)));
    }

}
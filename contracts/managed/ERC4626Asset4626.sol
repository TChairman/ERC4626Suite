// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626AssetBase.sol";

/// @notice Support for ERC4626 assets
/// @notice Manager decides when to invest/divest in any off-chain investment
/// @notice Gains are estimated until investments are updated by a call to updateNAV

abstract contract ERC4626Asset4626 is ERC4626AssetBase {
    using Math for uint256;

    // Events
    bytes32 public constant ERC4626_ASSET = keccak256("ERC4626_ASSET");

    constructor() {
    }

    function getLatestNAV(assetStruct storage asset) internal view virtual override returns (uint256) {
        if (asset.assetType == ERC4626_ASSET) {
            return ERC4626(asset.assetAddress).maxWithdraw(address(this));
        } else {
            return super.getLatestNAV(asset);
        }
    }


    function depositERC4626(ERC4626 _vault, uint256 _assets) public virtual onlyManager returns (uint256 _shares) {
        require(_vault.asset() == asset(), "Investment asset does not match vault");
        _shares = _vault.deposit(_assets, address(this));
        if (!createAsset(ERC4626_ASSET, address(_vault), 0, _assets, 0)) {
            updateNAV(address(_vault), 0);
        }
    }
    function redeemERC4626(ERC4626 _vault, uint256 _shares) public virtual onlyManager returns (uint256 _assets) {
        uint256 sharesMax = _vault.maxRedeem(address(this));
        if (_shares > sharesMax) _shares = sharesMax;
        _assets = _vault.redeem(_shares, address(this), address(this));
        updateNAV(address(_vault), 0);
    }

}
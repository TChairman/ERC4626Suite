// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626AssetBase.sol";

/// @notice Support for off-chain assets
/// @notice Manager decides when to invest/divest in any off-chain investment
/// @notice Gains are not computed until investments are updated by a call to updateNAV

abstract contract ERC4626AssetOffChain is ERC4626AssetBase {
    using Math for uint256;

    // Events
    bytes32 public constant OFFCHAIN_ASSET = keccak256("OFFCHAIN_ASSET");

    constructor() {
    }

    function distributeCoupon(uint256 _coupon) public virtual;

    function depositOffChainInvestment(address _receiver, uint256 _reference, uint256 _amount) public virtual onlyManager {
        depositOffChainDebt(_receiver, _reference, _amount, 0);
    }
 
    function depositOffChainDebt(address _receiver, uint256 _reference, uint256 _amount, uint256 _expectedReturnBPS) public virtual onlyManager {
        require(createAsset(OFFCHAIN_ASSET, _receiver, _reference, _amount, _amount, _expectedReturnBPS), "createAsset failed, increment reference?");
        require(ERC20(asset()).transfer(_receiver, _amount), "Transfer failed");
    }

    function redeemOffChainInvestment(address _investor, uint256 _reference, uint256 _remainingNAV, uint256 _principal) public virtual onlyManager {
        require(ERC20(asset()).transferFrom(_investor, address(this), _principal), "TransferFrom failed");
        setNAV(_investor, _reference, _remainingNAV);
    }

    function redeemOffChainDebt(address _investor, uint256 _reference, uint256 _remainingNAV, uint256 _principal, uint256 _coupon) public virtual onlyManager {
        redeemOffChainInvestment(_investor, _reference, _remainingNAV, _principal + _coupon);
        distributeCoupon(_coupon);
    }

}
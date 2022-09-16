// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "../ERC4626SuiteContext.sol";

/// @notice Asset Base provides functions for keeping track of investmnents, and setting NAV and expected returns
/// @notice Manager decides when to invest/divest in any asset
/// @notice Gains are estimated with expectedReturnBPS until investments are updated, it is recommended that this be used judiciously

abstract contract ERC4626AssetBase is ERC4626SuiteContext {
    using Math for uint256;

    // Events
    event createAssetEvent(bytes32 indexed _type, address indexed _vault, uint256 _reference, uint256 _parValue, uint256 _netValue, uint256 _expectedReturnBPS);
    event deleteAssetEvent(bytes32 indexed _type, address indexed _vault, uint256 _reference);
    event setNAVEvent(bytes32 indexed _type, address indexed _vault, uint256 _reference, uint256 _oldNAV, uint256 _newNAV);
    event setExpectedReturnBPSEvent(bytes32 indexed _type, address indexed _vault, uint256 _reference, uint256 _oldBPS, uint256 _newBPS);

    // Constants
    uint32 constant MAX_ASSETS = 255;

    struct assetStruct {
        bytes32 assetType;
        address assetAddress;
        uint256 id;
        uint256 parValue;
        uint256 netValue;
        uint256 lastNAVupdate;
        uint256 expectedReturnBPS;
    }

    // Variables
    assetStruct[] public assetList; // keep track of all the investments
    mapping(bytes32 => uint32) public assetIndexes; // so we can look them up easily
    uint256 public totalAssetNAV;
    uint256 public accruedExpectedReturn;
    uint256 public lastExpectedReturnUpdate;
    uint256 public totalExpectedReturnPerSec;

    constructor() {
        assetList.push(assetStruct(0x00, address(0), 0, 0, 0, 0, 0)); // create guard entry in assetList;
    }

    function assetHash (address addr, uint256 ref) public view virtual returns (bytes32) {
        return bytes32(bytes20(uint160(addr))) ^ bytes32(ref);
    }
    function assetIndex (address addr, uint256 ref) public view virtual returns (uint32) {
        return assetIndexes[assetHash(addr, ref)];
    }

    // Investment manager functions

    // used in totalAssets()
    function totalNAV () public view virtual override returns (uint256) {
        return totalAssetNAV + accruedExpectedReturn + (block.timestamp - lastExpectedReturnUpdate) * totalExpectedReturnPerSec; 
    }

    // can override for fee calculations
    function afterNAVupdated() internal virtual {}

    // return true if asset newly created, false if asset already existed
    function createAsset(
            bytes32 _assetType,
            address _assetAddress,
            uint256 _assetReference,
            uint256 _assetParValue,
            uint256 _assetNAV,
            uint256 _expectedReturnBPS) public virtual onlyManager returns (bool) {
        uint32 index = assetIndex(_assetAddress, _assetReference);
        if (index > 0) {
            require(assetList[index].assetType == _assetType, "createAsset: collision with differing type");
            return false;
        }
        index = uint32(assetList.length);
        require (index < MAX_ASSETS, "createAsset: would exceed MAX_ASSETS");
        assetIndexes[assetHash(_assetAddress, _assetReference)] = index;
        assetList.push(assetStruct(_assetType, _assetAddress, _assetReference, _assetParValue, 0, block.timestamp, 0));
        if (_assetNAV > 0) setNAVindex(index, _assetNAV);
        if (_expectedReturnBPS > 0) setExpectedReturnBPSindex(index, _expectedReturnBPS);
        emit createAssetEvent(_assetType, _assetAddress, _assetReference, _assetParValue, _assetNAV, _expectedReturnBPS);
        return true;
    }

    function deleteAsset(bytes32 _assetType, address _assetAddress, uint256 _assetReference) public virtual onlyManager {
        uint32 index = assetIndex(_assetAddress, _assetReference);
        require(index > 0 && index < assetList.length, "Index out of range");
        if (assetList[index].netValue > 0) setNAVindex(index, 0);
        if (assetList[index].expectedReturnBPS > 0) setExpectedReturnBPSindex(index, 0);

        // swap and pop
        if (index < assetList.length-1) {
            assetList[index] = assetList[assetList.length-1];
            assetIndexes[assetHash(assetList[index].assetAddress, assetList[index].id)] = index;
        }
        assetList.pop();
        emit deleteAssetEvent(_assetType, _assetAddress, _assetReference);
    }

    // override for asset types that can update on-chain - check type and call super if it doesn't match
    function getLatestNAV(assetStruct storage asset) internal view virtual returns (uint256) {
        return asset.netValue.mulDiv(BPS_MULTIPLE + asset.expectedReturnBPS, BPS_MULTIPLE);
    }

    // orverride this one for asset types that can update both on-chain
    function getLatestNAVandReturnBPS(assetStruct storage asset) internal view virtual returns (uint256, uint256) {
        return (getLatestNAV(asset), asset.expectedReturnBPS);
    }

    function getNAV(address _vault, uint256 _ref) public virtual view returns (uint256 newNAV) {
        uint32 index = assetIndex(_vault, _ref);
        require(index > 0 && index < assetList.length, "Index out of range");
        newNAV = getLatestNAV(assetList[index]); 
    }

    function updateNAV(address addr, uint256 ref) public virtual returns (uint256 newNAV) {
        newNAV = getNAV(addr, ref);
        setNAVindex(assetIndex(addr, ref), newNAV);
    }

    function setNAV(address addr, uint256 ref, uint256 newNAV) public virtual onlyManager {
        setNAVindex(assetIndex(addr, ref), newNAV);
    }

    function setNAVindex(uint32 index, uint256 newNAV) internal virtual {
        require(index > 0 && index < assetList.length, "Index out of range");
        uint256 oldNAV = assetList[index].netValue;
        assetList[index].netValue = newNAV;
        assetList[index].lastNAVupdate = block.timestamp;
        totalAssetNAV = totalAssetNAV + newNAV - oldNAV; // assert that this is safe

        // back out whatever was accrued for this asset since we're now confirming the NAV
        updateAccruedExpectedReturn();
        accruedExpectedReturn -= assetList[index].expectedReturnBPS.mulDiv(oldNAV, SECS_PER_YEAR * BPS_MULTIPLE * (block.timestamp - assetList[index].lastNAVupdate));
        
        afterNAVupdated();
        emit setNAVEvent(assetList[index].assetType, assetList[index].assetAddress, assetList[index].id, oldNAV, newNAV);
    }

    function setNAVandReturnBPS(address addr, uint256 ref, uint256 newNAV, uint256 newBPS) public virtual onlyManager {
        setNAVindex(assetIndex(addr, ref), newNAV);
        setExpectedReturnBPSindex(assetIndex(addr, ref), newBPS);
    }

    function setExpectedReturnBPSindex(uint32 index, uint256 newBPS) internal virtual {
        require(index > 0 && index < assetList.length, "Index out of range");
        uint256 oldBPS = assetList[index].expectedReturnBPS;
        if (newBPS != oldBPS) {
            assetList[index].expectedReturnBPS = newBPS;
            totalExpectedReturnPerSec = totalExpectedReturnPerSec + 
                            newBPS.mulDiv(assetList[index].netValue, BPS_MULTIPLE * SECS_PER_YEAR) -
                            oldBPS.mulDiv(assetList[index].netValue, BPS_MULTIPLE * SECS_PER_YEAR);
            emit setExpectedReturnBPSEvent(assetList[index].assetType, assetList[index].assetAddress, assetList[index].id, oldBPS, newBPS);
        }
    }
    function updateNAVandReturnBPS(address _vault, uint256 _ref) public virtual returns (uint256 newNAV, uint256 newBPS) {
        uint32 index = assetIndex(_vault, _ref);
        require(index > 0 && index < assetList.length, "Index out of range");
        (newNAV, newBPS) = getLatestNAVandReturnBPS(assetList[index]); 
        setNAVindex(index, newNAV);
        setExpectedReturnBPSindex(index, newBPS);
    }

    function updateAccruedExpectedReturn() internal virtual {
        accruedExpectedReturn += (block.timestamp - lastExpectedReturnUpdate) * totalExpectedReturnPerSec;
        lastExpectedReturnUpdate = block.timestamp;
    }

    // probably costs a lot of gas, but here just in case a full reset is needed
    function updateAllAssets() public virtual returns (uint256) {
        totalAssetNAV = 0; 
        totalExpectedReturnPerSec = 0;
        for(uint32 i=0; i<= assetList.length; i++){
            (assetList[i].netValue,  assetList[i].expectedReturnBPS) = getLatestNAVandReturnBPS(assetList[i]);
            totalAssetNAV += assetList[i].netValue;
            totalExpectedReturnPerSec += assetList[i].expectedReturnBPS.mulDiv(assetList[i].netValue, BPS_MULTIPLE * SECS_PER_YEAR);
        }
        accruedExpectedReturn = 0;
        lastExpectedReturnUpdate = block.timestamp;
        return totalAssetNAV;
    }
}
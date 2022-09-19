// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "./ERC4626DepositEscrow.sol"; 

/// @notice Maintain a list of investors and commitment amounts, so those amounts can be simultaneously drawn as a capital call.
/// @notice Does not implement a delinquency penalty, that can be done manually with forceRedeem or a redemption with 0 assets.

abstract contract ERC4626CapitalCall is ERC4626DepositEscrow {
    using Math for uint256;

    uint32 constant MAX_INVESTORS = type(uint32).max;

    // Variables
    struct investorType {
        bytes32 id; // ID assigned by manager, must be unique
        uint256 commitment;
        uint256 delinquentAmount;
        address depositor; // wallet where deposits came from
        address receiver; // wallet where shares are deposited when capital calls are finalized
    }
    investorType[] public _investors;
    mapping (bytes32 => uint32) public _investorIndex;

    constructor() {
        _investors.push(investorType("", 0, 0, address(0), address(0))); // push guard entry
    }

    function addInvestor(bytes32 _id, uint256 _commitment, address _depositor) public virtual onlyManager {
        require(_investorIndex[_id] == 0, "addInvestor: investor already exists");
        require(_investors.length < MAX_INVESTORS, "addInvestor: max investors reached");
        _investorIndex[_id] = uint32(_investors.length);
        _investors.push(investorType(_id, _commitment, 0, _depositor, _depositor));
    }

    function addInvestorBatch(bytes32[] calldata _ids, uint256[] calldata _commitments, address[] calldata _owners) public virtual onlyManager {
        require(_ids.length == _commitments.length && _ids.length == _owners.length, "addInvestorsBatch: arrays not the same size");
        for (uint32 i=0; i<_ids.length; i++) {
            addInvestor(_ids[i], _commitments[i], _owners[i]);
        }
    }

    function setInvestorCommitment(bytes32 _id, uint256 _commitment) public virtual onlyManager {
        uint32 index = _investorIndex[_id];
        require(index > 0, "investor does not exist");
        _investors[index].commitment = _commitment;
    }
    function setInvestorDepositor(bytes32 _id, address _depositor) public virtual onlyManager {
        uint32 index = _investorIndex[_id];
        require(index > 0, "investor does not exist");
        _investors[index].depositor = _depositor;
    }
    function setInvestorReceiver(bytes32 _id, address _receiver) public virtual onlyManager {
        uint32 index = _investorIndex[_id];
        require(index > 0, "investor does not exist");
        _investors[index].receiver = _receiver;
    }

    function investorCount() public virtual returns (uint256) {
        return _investors.length;
    }
    function investorAt(uint32 _index) public virtual returns (bytes32) {
        return _investors[_index].id;
    }

    function getDelinquentAmount(bytes32 _id) public virtual returns (uint256) {
        return getDelinquentAmountIndex(_investorIndex[_id]);
    }

    function getDelinquentAmountIndex(uint32 _index) public virtual returns (uint256) {
        require(_index > 0 && _index < _investors.length, "investor does not exist");
        return _investors[_index].delinquentAmount;
    }

    function acceptCapitalCall(uint256 _callBPS) public virtual onlyManager returns (bool _success) {
        _success = true;
        for (uint32 i=1; i<_investors.length; i++) {
            uint256 callAmount = _investors[i].commitment.mulDiv(_callBPS, BPS_MULTIPLE) + _investors[i].delinquentAmount;
            uint256 depositedAmount = escrowedBalanceOf(_investors[i].depositor);
            if (depositedAmount >= callAmount) {
                acceptEscrowedDeposit(_investors[i].depositor, callAmount);
            } else {
                if (depositedAmount > 0) acceptEscrowedDeposit(_investors[i].depositor, depositedAmount);
                _investors[i].delinquentAmount = callAmount - depositedAmount;
                _success = false;
            }
        }
    }

}

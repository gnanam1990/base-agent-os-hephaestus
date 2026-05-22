// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Multisig3of5
/// @notice Fixed 3-of-5 multisig wallet.
contract Multisig3of5 {
    address[5] public owners;
    uint256 public constant REQUIRED = 3;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approvals;

    error NotOwner();
    error TxDoesNotExist();
    error AlreadyApproved();
    error TxAlreadyExecuted();
    error InsufficientApprovals();

    event TxSubmitted(uint256 indexed txId, address indexed proposer);
    event TxApproved(uint256 indexed txId, address indexed approver);
    event TxExecuted(uint256 indexed txId);

    constructor(address[5] memory _owners) {
        for (uint256 i; i < 5; i++) {
            if (_owners[i] == address(0)) revert NotOwner();
            owners[i] = _owners[i];
        }
    }

    modifier onlyOwner() {
        if (!_isOwner(msg.sender)) revert NotOwner();
        _;
    }

    function _isOwner(address addr) internal view returns (bool) {
        for (uint256 i; i < 5; i++) {
            if (owners[i] == addr) return true;
        }
        return false;
    }

    function submit(address to, uint256 value, bytes calldata data) external onlyOwner {
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, approvalCount: 0}));
        emit TxSubmitted(transactions.length - 1, msg.sender);
    }

    function approve(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert TxDoesNotExist();
        if (approvals[txId][msg.sender]) revert AlreadyApproved();
        approvals[txId][msg.sender] = true;
        transactions[txId].approvalCount++;
        emit TxApproved(txId, msg.sender);
    }

    function execute(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert TxDoesNotExist();
        Transaction storage txn = transactions[txId];
        if (txn.executed) revert TxAlreadyExecuted();
        if (txn.approvalCount < REQUIRED) revert InsufficientApprovals();
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Execution failed");
        emit TxExecuted(txId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title HephaestusRegistry
/// @notice On-chain registry for contracts deployed by the Hephaestus agent.
/// @dev Stores deploy records, tracks requester history, and manages agent authorization.
contract HephaestusRegistry is Ownable {
    /// @notice Record of a single contract deployment.
    struct DeployRecord {
        address contractAddr;
        address requester;
        bytes32 specHash;
        uint64 deployedAt;
        bytes32 attestationUID;
        uint8 auditTier;
    }

    /// @notice Mapping from contract address to its deploy record.
    mapping(address => DeployRecord) public deploys;

    /// @notice Mapping from requester address to list of deployed contract addresses.
    mapping(address => address[]) internal _deploysByRequester;

    /// @notice Address of the authorized agent.
    address public agent;

    /// @notice Total number of deploys recorded.
    uint256 public totalDeploys;

    /// @notice Thrown when a non-agent address attempts an agent-only action.
    error NotAgent();

    /// @notice Thrown when attempting to record a deploy for an already registered contract.
    error DeployExists();

    /// @notice Thrown when a zero address is provided.
    error ZeroAddress();

    /// @notice Emitted when a new deploy is recorded.
    /// @param contractAddr The address of the deployed contract.
    /// @param requester The address that requested the deployment.
    /// @param auditTier The audit tier (0 = standard, 1 = kratos-deep).
    event DeployRecorded(address indexed contractAddr, address indexed requester, uint8 auditTier);

    /// @notice Emitted when the agent address is changed.
    /// @param oldAgent Previous agent address.
    /// @param newAgent New agent address.
    event AgentSet(address indexed oldAgent, address indexed newAgent);

    /// @notice Creates the registry with an initial agent.
    /// @param _agent Address of the authorized agent.
    constructor(address _agent) Ownable(msg.sender) {
        if (_agent == address(0)) revert ZeroAddress();
        agent = _agent;
    }

    /// @notice Sets the authorized agent address. Only callable by the owner.
    /// @param newAgent Address of the new agent.
    function setAgent(address newAgent) external onlyOwner {
        if (newAgent == address(0)) revert ZeroAddress();
        emit AgentSet(agent, newAgent);
        agent = newAgent;
    }

    /// @notice Records a new contract deployment. Only callable by the agent.
    /// @param contractAddr Address of the deployed contract.
    /// @param requester Address that requested the deployment.
    /// @param specHash Keccak256 hash of the deployment specification.
    /// @param auditTier Audit tier (0 = standard, 1 = kratos-deep).
    function recordDeploy(
        address contractAddr,
        address requester,
        bytes32 specHash,
        uint8 auditTier
    ) external {
        if (msg.sender != agent) revert NotAgent();
        if (contractAddr == address(0)) revert ZeroAddress();
        if (deploys[contractAddr].contractAddr != address(0)) revert DeployExists();

        deploys[contractAddr] = DeployRecord({
            contractAddr: contractAddr,
            requester: requester,
            specHash: specHash,
            deployedAt: uint64(block.timestamp),
            attestationUID: bytes32(0),
            auditTier: auditTier
        });

        _deploysByRequester[requester].push(contractAddr);
        totalDeploys++;

        emit DeployRecorded(contractAddr, requester, auditTier);
    }

    /// @notice Returns the deploy record for a given contract address.
    /// @param contractAddr Address of the deployed contract.
    /// @return record The deploy record.
    function getDeployRecord(address contractAddr) external view returns (DeployRecord memory record) {
        record = deploys[contractAddr];
    }

    /// @notice Returns all contract addresses deployed by a given requester.
    /// @param requester Address of the requester.
    /// @return addresses Array of contract addresses.
    function getDeploysByRequester(address requester) external view returns (address[] memory addresses) {
        addresses = _deploysByRequester[requester];
    }
}

/// @title HephaestusRoyalty
/// @notice Manages fee distribution for Hephaestus-deployed contracts.
/// @dev Splits incoming fees between treasury and originator with reentrancy protection.
contract HephaestusRoyalty is ReentrancyGuard {
    /// @notice Mapping from contract address to its fee originator.
    mapping(address => address) public feeOriginatorOf;

    /// @notice Mapping to track if a contract is registered.
    mapping(address => bool) public registered;

    /// @notice Treasury address that receives a share of fees.
    address public treasury;

    /// @notice Address of the authorized agent.
    address public agent;

    /// @notice Treasury share in basis points (5%).
    uint256 public constant TREASURY_BPS = 500;

    /// @notice Thrown when a non-agent address attempts an agent-only action.
    error NotAgent();

    /// @notice Thrown when a zero address is provided.
    error ZeroAddress();

    /// @notice Thrown when the contract is not registered.
    error NotRegistered();

    /// @notice Emitted when a contract is registered with its originator.
    /// @param contractAddr The registered contract address.
    /// @param originator The fee originator address.
    event ContractRegistered(address indexed contractAddr, address indexed originator);

    /// @notice Emitted when a fee is forwarded.
    /// @param contractAddr The contract that generated the fee.
    /// @param treasuryAmount Amount sent to treasury.
    /// @param originatorAmount Amount sent to originator.
    event FeeForwarded(address indexed contractAddr, uint256 treasuryAmount, uint256 originatorAmount);

    /// @notice Creates the royalty contract.
    /// @param _treasury Treasury address.
    /// @param _agent Authorized agent address.
    constructor(address _treasury, address _agent) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_agent == address(0)) revert ZeroAddress();
        treasury = _treasury;
        agent = _agent;
    }

    /// @notice Registers a contract with its fee originator. Only callable by the agent.
    /// @param contractAddr The contract to register.
    /// @param originator The address that should receive the originator share.
    function registerContract(address contractAddr, address originator) external {
        if (msg.sender != agent) revert NotAgent();
        if (contractAddr == address(0)) revert ZeroAddress();

        feeOriginatorOf[contractAddr] = originator;
        registered[contractAddr] = true;

        emit ContractRegistered(contractAddr, originator);
    }

    /// @notice Forwards a fee payment, splitting between treasury and originator.
    /// @dev If the contract is registered, splits 5% treasury / 95% originator.
    ///      If not registered, 100% goes to treasury.
    /// @param contractAddr The contract that generated the fee.
    function forwardFee(address contractAddr) external payable nonReentrant {
        if (msg.value == 0) return;

        uint256 treasuryAmount;
        uint256 originatorAmount;

        if (registered[contractAddr]) {
            originatorAmount = (msg.value * (10000 - TREASURY_BPS)) / 10000;
            treasuryAmount = msg.value - originatorAmount;

            (bool originatorSuccess, ) = payable(feeOriginatorOf[contractAddr]).call{value: originatorAmount}("");
            require(originatorSuccess, "Originator transfer failed");
        } else {
            treasuryAmount = msg.value;
        }

        (bool treasurySuccess, ) = payable(treasury).call{value: treasuryAmount}("");
        require(treasurySuccess, "Treasury transfer failed");

        emit FeeForwarded(contractAddr, treasuryAmount, originatorAmount);
    }
}

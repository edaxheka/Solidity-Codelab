// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowContract {
    address public jobContract;

    // Mappings to track escrow data
    mapping(uint => address payable) public freelancers;
    mapping(uint => uint) public balances;
    mapping(uint => bool) public isReleased;

    // Events
    event FundsDeposited(uint jobId, address freelancer, uint amount);
    event FundsReleased(uint jobId, address freelancer, uint amount);

    constructor(address _jobContract) {
        jobContract = _jobContract;
    }

    // Restrict access to only JobContract
    modifier onlyJobContract() {
        require(msg.sender == jobContract, "Only JobContract can call");
        _;
    }

    // Called by JobContract to hold funds
    function createEscrow(uint jobId, address payable freelancer) external payable onlyJobContract {
        require(msg.value > 0, "No ETH sent");
        freelancers[jobId] = freelancer;
        balances[jobId] = msg.value;

        emit FundsDeposited(jobId, freelancer, msg.value);
    }

    // Called by JobContract to release funds
    function releaseFunds(uint jobId) external onlyJobContract {
        require(!isReleased[jobId], "Funds already released");
        require(balances[jobId] > 0, "No funds available");

        isReleased[jobId] = true;
        uint amount = balances[jobId];
        address payable freelancer = freelancers[jobId];

        freelancer.transfer(amount);

        emit FundsReleased(jobId, freelancer, amount);
    }
}
contract JobContract {
    EscrowContract public escrow;
    uint public jobCount;

    // Mappings to store job info
    mapping(uint => address) public clients;
    mapping(uint => string) public descriptions;
    mapping(uint => uint) public budgets;
    mapping(uint => address payable) public freelancers;
    mapping(uint => bool) public isAssigned;
    mapping(uint => bool) public isCompleted;

    // Events
    event JobCreated(uint jobId, address client, string description, uint budget);
    event JobAssigned(uint jobId, address freelancer);
    event JobCompleted(uint jobId);

    constructor(address escrowAddress) {
        escrow = EscrowContract(escrowAddress);
    }

    // Step 1: Create a job
    function createJob(string memory description, uint budget) public {
        require(budget > 0, "Budget must be greater than 0");

        clients[jobCount] = msg.sender;
        descriptions[jobCount] = description;
        budgets[jobCount] = budget;

        emit JobCreated(jobCount, msg.sender, description, budget);
        jobCount++;
    }

    // Step 2: Assign freelancer and fund escrow
    function assignFreelancer(uint jobId, address payable freelancer) public payable {
        require(msg.sender == clients[jobId], "Only the client can assign");
        require(!isAssigned[jobId], "Freelancer already assigned");
        require(msg.value == budgets[jobId], "Send job budget");

        freelancers[jobId] = freelancer;
        isAssigned[jobId] = true;

        // Send ETH to EscrowContract
        escrow.createEscrow{value: msg.value}(jobId, freelancer);

        emit JobAssigned(jobId, freelancer);
    }

    // Step 3: Mark job as completed and release funds
    function markJobCompleted(uint jobId) public {
        require(msg.sender == clients[jobId], "Only the client can mark as complete");
        require(isAssigned[jobId], "Not assigned");
        require(!isCompleted[jobId], "Completed");

        isCompleted[jobId] = true;
        escrow.releaseFunds(jobId);

        emit JobCompleted(jobId);
    }
}
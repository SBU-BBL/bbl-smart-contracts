// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ICommPutationTaskManager.sol";
import "./CommPutationFactory.sol";

contract CommPutationTaskManager is ICommPutationTaskManager {
    
    mapping(bytes32 => Organization) public organizations;
    mapping(bytes32 => mapping(bytes32 => address)) public referrers;
    mapping(bytes32 => mapping(address => UserDetails)) public usersDetails;
    mapping(bytes32 => mapping(uint256 => Task)) public tasks;
    mapping(bytes32 => mapping(address => mapping(uint256 => uint256))) public userTaskRecord;

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createOrganization(
        bytes32 organizationId,
        uint8 newMemberReward,
        uint8 referralReward,
        string calldata name,
        string calldata symbol
    ) external returns (address token) {
        require(organizations[organizationId].isInitialized == 0, "Organization already exists");
        token = CommPutationFactory.clone(implementation, name, symbol, address(this), msg.sender);
        organizations[organizationId] = Organization(msg.sender, 1, token, 0, 1, newMemberReward, referralReward);
        usersDetails[organizationId][msg.sender] = UserDetails(0, 1, 1);
    }

    function joinOrganization(
        bytes32 organizationId,
        bytes32 referralId
    ) external {
        Organization storage organization = organizations[organizationId];
        require(organization.isInitialized == 1, "Organization not found");
        require(usersDetails[organizationId][msg.sender].isMember == 0, "User already a member");
        usersDetails[organizationId][msg.sender] = UserDetails(0, 0, 1);
        organization.numMembers++;

        // mint newMemberReward
        mint(
            organization.token,
            msg.sender,
            organization.newMemberReward
        );

        // mint referralReward
        address referrer = referrers[organizationId][referralId];
        if (referrer != address(0)) {
            mint(
                organization.token,
                referrer,
                organization.referralReward
            );
        }
    }

    function allocateTokens(
        bytes32 organizationId,
        address user,
        uint128 amount
    ) external {
        Organization memory organization = organizations[organizationId];
        if(msg.sender == organization.admin) {
            mint(organization.token, address(this), amount);
            alloc(organizationId, user, amount);
        } else {
            uint64 senderRole = usersDetails[organizationId][msg.sender].role;
            require(senderRole > 1, "User not authorized");
            // check msg.sender has higher role than user (lower role number means higher role)
            require(senderRole < usersDetails[organizationId][user].role, "User not authorized");
            dealloc(organizationId, msg.sender, amount);
            alloc(organizationId, user, amount);
        }
    }

    function createTask(
        bytes32 organizationId,
        uint48 deadline,
        uint40 reward,
        uint8 mode
    ) external returns (uint256 taskId) {
        Organization memory organization = organizations[organizationId];

        // Tokens minted only by admin
        if(msg.sender == organization.admin) {
            mint(organization.token, address(this), reward);
            taskId = organization.currentTaskId;
            tasks[organizationId][taskId] = Task(msg.sender, deadline, reward, mode);
            organization.currentTaskId++;
        } else {
            require(usersDetails[organizationId][msg.sender].role > 1, "User not authorized");
            taskId = organization.currentTaskId;
            tasks[organizationId][taskId] = Task(msg.sender, deadline, reward, mode);
            dealloc(organizationId, msg.sender, reward);
            organization.currentTaskId++;
        }
    }

    function modifyTask(
        bytes32 organizationId,
        uint256 taskId,
        uint48 deadline,
        uint40 reward,
        uint8 mode
    ) external {
        Organization memory organization = organizations[organizationId];
        Task storage task = tasks[organizationId][taskId];
        require(task.creator == msg.sender || msg.sender == organization.admin, "User not authorized");
        task.deadline = deadline;
        task.mode = mode;

        // calculate reward difference
        if(reward > task.balance) {
            if(msg.sender == organization.admin) {
                mint(organization.token, address(this), reward - task.balance);
            } else {
                alloc(organizationId, msg.sender, reward - task.balance);
            }
        } else if(reward < task.balance) {
            if(msg.sender == organization.admin) {
                burn(organization.token, address(this), task.balance - reward);
            } else {
                dealloc(organizationId, msg.sender, task.balance - reward);
            }
        }
    }

    function completeTask(
        bytes32 organizationId,
        uint256 taskId,
        address user,
        uint40 amount
    ) external {
        Organization memory organization = organizations[organizationId];
        Task storage task = tasks[organizationId][taskId];

        require(msg.sender == task.creator || msg.sender == organization.admin, "User not authorized");
        require(block.timestamp <= task.deadline, "Task deadline passed");
        require(userTaskRecord[organizationId][user][taskId] == 0, "Task already completed");
        require(amount <= task.balance, "Amount exceeds task balance");

        // transfer reward
        transfer(organization.token, user, amount);
        task.balance -= amount;
        userTaskRecord[organizationId][user][taskId] = 1;
    }

    function submitAutonomousTask(
        bytes32 organizationId,
        uint256 taskId
    ) external returns (uint256 reward) {
        Organization memory organization = organizations[organizationId];
        Task storage task = tasks[organizationId][taskId];
        require(task.mode == 1, "Task not autonomous");
        require(block.timestamp <= task.deadline, "Task deadline passed");
        require(userTaskRecord[organizationId][msg.sender][taskId] == 0, "Task already completed");

        reward = task.balance;
        task.balance = 0;
        userTaskRecord[organizationId][msg.sender][taskId] = 1;
        if(task.creator == organization.admin) {
            mint(organization.token, msg.sender, reward);
        } else {
            transfer(organization.token, msg.sender, reward);
        }
    }

    //////////////////////// INTERNAL FUNCTIONS ////////////////////////

    function mint(address token, address to, uint256 amount) internal {
        ERC20Implementation(token).mint(to, amount);
    }

    function burn(address token, address from, uint256 amount) internal {
        ERC20Implementation(token).burn(from, amount);
    }

    function transfer(address token, address to, uint256 amount) internal {
        ERC20Implementation(token).transfer(to, amount);
    }

    function alloc(bytes32 organizationId, address user, uint128 amount) internal {
        usersDetails[organizationId][user].allocation += amount;
    }

    function dealloc(bytes32 organizationId, address user, uint128 amount) internal {
        usersDetails[organizationId][user].allocation -= amount;
    }
}
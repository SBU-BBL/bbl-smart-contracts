// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICommPutationTaskManager {
    
    struct Task {
        address creator; // uint160
        uint48 deadline;
        uint40 balance;
        uint8 mode; // 0 - normal, 1 - autonomous
    }

    struct UserDetails {
        uint128 allocation;
        uint64 role; // 0 - user, 1 - admin, 2 - professor, 3 - team leader
        uint64 isMember;
    }

    struct Organization {
        address admin;
        uint96 numMembers;
        address token;
        uint72 currentTaskId;
        uint8 isInitialized;
        uint8 newMemberReward;
        uint8 referralReward;
    }

    function createOrganization(
        bytes32 organizationId,
        uint8 newMemberReward,
        uint8 referralReward,
        string calldata name,
        string calldata symbol
    ) external returns (address);

    function joinOrganization(
        bytes32 organizationId,
        bytes32 referralId    
    ) external;

    function allocateTokens(
        bytes32 organizationId,
        address user,
        uint128 amount
    ) external;

    function createTask(
        bytes32 organizationId,
        uint48 deadline,
        uint40 reward,
        uint8 mode
    ) external returns (uint256);

    function modifyTask(
        bytes32 organizationId,
        uint256 taskId,
        uint48 deadline,
        uint40 reward,
        uint8 mode
    ) external;

    function completeTask(
        bytes32 organizationId,
        uint256 taskId,
        address user,
        uint40 amount
    ) external;

    function submitAutonomousTask(
        bytes32 organizationId,
        uint256 taskId
    ) external returns (uint256);
}
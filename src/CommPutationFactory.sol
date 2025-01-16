// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ERC20Implementation.sol";

library CommPutationFactory {
    event Clone(address indexed owner, address instanceAddr);

    function clone(
        address implementation,
        string calldata _name,
        string calldata _symbol,
        address commPutationTaskManager,
        address _owner
    ) public returns (address) {
        address cloneInstance = Clones.clone(implementation);
        ERC20Implementation(cloneInstance).initialize(_name, _symbol, commPutationTaskManager, _owner);

        emit Clone(_owner, cloneInstance);
        return cloneInstance;
    }

    function create(
        string calldata _name,
        string calldata _symbol,
        address commPutationTaskManager,
        address _owner
    ) external returns (address) {
        address instance = address(new ERC20Implementation());
        ERC20Implementation(instance).initialize(_name, _symbol, commPutationTaskManager, _owner);

        emit Clone(_owner, instance);
        return instance;
    }
}
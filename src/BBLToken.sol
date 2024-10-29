// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is IERC20 {

    error FORBIDDEN();
    error INVALID_TASK();
    error INVALID_TASK_TYPE();

    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    address public treasury;
    address public relayer; // Auto Reward Task Relayer

    struct Task {
        uint80 id;
        address taskAdmin; // uint160
        uint8 role; // 0 bbl, 1 prof, 2 team leader
        uint8 taskType;
        uint256 reward;
        string name;
        string description;
    }

    // add teams
    // task admin
    // organize by team leader 
    // bbl - prof - team leaders

    // attach emails to addresses 

    mapping(address => uint256) public nonces;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(uint256 => Task) public tasks; // id <> Task
    mapping(bytes32 => address) public userIdentifier;
    mapping(bytes32 => mapping(uint256 => uint256)) public userTaskRecord; // user <> id <> boolean

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _treasury,
        uint256 amount
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        treasury = _treasury;

        _mint(msg.sender, (amount ** _decimals));
    }

    function setTreasury(address newTreasury) external {
        if(msg.sender != treasury) revert FORBIDDEN();
        treasury = newTreasury;
    }

    function setRelayer(address newRelayer) external {
        if(msg.sender != treasury || msg.sender != relayer) revert FORBIDDEN();
        relayer = newRelayer;
    }

    function issueTokens(uint256 amount) external {
        if(msg.sender != treasury) revert FORBIDDEN();
        _mint(treasury, amount);
    }

    function reallocateUserTokens(bytes32 userId, address userNewAddress) external {
        if(msg.sender != treasury) revert FORBIDDEN();
        address userOldAddress = userIdentifier[userId];
        uint256 amt = balanceOf[userOldAddress];
        _burn(userOldAddress, amt);
        _mint(userNewAddress, amt);
        userIdentifier[userId] = userNewAddress;
    }

    function sendReward(bytes32 userId, uint256 taskId) external {
        if(msg.sender != relayer) revert FORBIDDEN();
        
        Task memory task = tasks[taskId];
        if(task.taskType != 0) revert INVALID_TASK_TYPE();

        uint256 reward = task.reward;
        if(userTaskRecord[userId][taskId] == 1) revert INVALID_TASK();

        userTaskRecord[userId][taskId] = 1;
        transfer(userIdentifier[userId], reward);
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-20 FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}
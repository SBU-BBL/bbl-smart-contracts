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
    uint256 public immutable decimals;
    uint256 public totalSupply;

    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    address public admin;
    uint256 public currentTaskId;

    struct Task {
        address taskCreator; // uint160
        uint8 taskType;
        uint88 reward;
    }

    struct User {
        uint128 role; // 0 - user, 1 - admin, 2 - professor, 3 - team leader
        uint128 nonce;
    }

    // add teams
    // task admin
    // organize by team leader 
    // bbl - prof - team leaders

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => User) public users;
    mapping(uint256 => Task) public tasks; // id <> Task
    mapping(address => mapping(uint256 => uint256)) public userTaskRecord; // user <> task id <> boolean

    constructor(
        string memory _name,
        string memory _symbol,
        address _admin
    ) {
        name = _name;
        symbol = _symbol;
        decimals = 6;

        admin = _admin;
        users[_admin].role = 1;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        _mint(_admin, (10**7) * (10**decimals));
    }

    function getRole(address user) external view returns (uint128) {
        return users[user].role;
    }

    function setRole(address _user, uint8 _role) external {
        User storage user = users[_user];
        User memory requester = users[msg.sender];
        if(_role <= 0 && (msg.sender != admin || requester.role <= _role)) revert FORBIDDEN();
        user.role = _role;
    }

    function setAdmin(address newAdmin) external {
        if(msg.sender != admin) revert FORBIDDEN();
        admin = newAdmin;
    }

    function issueTokens(uint256 amount) external {
        if(msg.sender != admin) revert FORBIDDEN();
        _mint(admin, amount);
    }

    function reallocateUserTokens(address userOldAddress, address userNewAddress) external {
        if(msg.sender != admin) revert FORBIDDEN();
        uint256 amt = balanceOf[userOldAddress];
        _burn(userOldAddress, amt);
        _mint(userNewAddress, amt);
    }

    function sendReward(address user, uint256 taskId) external {
        if(msg.sender != admin) revert FORBIDDEN();
        
        Task memory task = tasks[taskId];
        if(task.taskType != 0) revert INVALID_TASK_TYPE();

        uint256 reward = task.reward;
        if(userTaskRecord[user][taskId] == 1) revert INVALID_TASK();

        userTaskRecord[user][taskId] = 1;
        transfer(user, reward);
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
        User storage user = users[owner];
        uint128 nonce = user.nonce;

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
                                uint256(nonce),
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            user.nonce = nonce + 1;

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
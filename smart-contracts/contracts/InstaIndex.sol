pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


/**
 * @title InstaIndex
 * @dev Main Contract For DeFi Smart Accounts. This is also a factory contract, Which deploys new Smart Account.
 * Also Registry for DeFi Smart Accounts.
 */

interface AccountInterface {
    function version() external view returns (uint256);

    function enable(address authority) external;

    function cast(
        address[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32[] memory responses);

    function setIndex(address _instaIndex) external;

    function initialize(
        address _token,
        uint256 _depositAmount,
        uint256 _period
    ) external;

    function dca(address _origin) external payable;
}

interface ListInterface {
    function init(address _account) external;
}

contract AddressIndex {
    event LogNewMaster(address indexed master);
    event LogUpdateMaster(address indexed master);
    event LogNewCheck(uint256 indexed accountVersion, address indexed check);
    event LogNewAccount(
        address indexed _newAccount,
        address indexed _connectors,
        address indexed _check
    );

    // New Master Address.
    address private newMaster;
    // Master Address.
    address public master;
    // List Registry Address.
    address public list;

    // Connectors Modules(Account Module Version => Connectors Registry Module Address).
    mapping(uint256 => address) public connectors;
    // Check Modules(Account Module Version => Check Module Address).
    mapping(uint256 => address) public check;
    // Account Modules(Account Module Version => Account Module Address).
    mapping(uint256 => address) public account;
    // Version Count of Account Modules.
    uint256 public versionCount;

    /**
     * @dev Throws if the sender not is Master Address.
     */
    modifier isMaster() {
        require(msg.sender == master, "not-master");
        _;
    }

    /**
     * @dev Change the Master Address.
     * @param _newMaster New Master Address.
     */
    function changeMaster(address _newMaster) external isMaster {
        require(_newMaster != master, "already-a-master");
        require(_newMaster != address(0), "not-valid-address");
        require(newMaster != _newMaster, "already-a-new-master");
        newMaster = _newMaster;
        emit LogNewMaster(_newMaster);
    }

    function updateMaster() external {
        require(newMaster != address(0), "not-valid-address");
        require(msg.sender == newMaster, "not-master");
        master = newMaster;
        newMaster = address(0);
        emit LogUpdateMaster(master);
    }

    /**
     * @dev Change the Check Address of a specific Account Module version.
     * @param accountVersion Account Module version.
     * @param _newCheck The New Check Address.
     */
    function changeCheck(uint256 accountVersion, address _newCheck)
        external
        isMaster
    {
        require(_newCheck != check[accountVersion], "already-a-check");
        check[accountVersion] = _newCheck;
        emit LogNewCheck(accountVersion, _newCheck);
    }

    /**
     * @dev Add New Account Module.
     * @param _newAccount The New Account Module Address.
     * @param _connectors Connectors Registry Module Address.
     * @param _check Check Module Address.
     */
    function addNewAccount(
        address _newAccount,
        address _connectors,
        address _check
    ) external isMaster {
        require(_newAccount != address(0), "not-valid-address");
        versionCount++;
        require(
            AccountInterface(_newAccount).version() == versionCount,
            "not-valid-version"
        );
        account[versionCount] = _newAccount;
        if (_connectors != address(0)) connectors[versionCount] = _connectors;
        if (_check != address(0)) check[versionCount] = _check;
        emit LogNewAccount(_newAccount, _connectors, _check);
    }
}

contract CloneFactory is AddressIndex {
    /**
     * @dev Clone a new Account Module.
     * @param version Account Module version to clone.
     */
    function createClone(uint256 version) internal returns (address result) {
        bytes20 targetBytes = bytes20(account[version]);
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }

    /**
     * @dev Check if Account Module is a clone.
     * @param version Account Module version.
     * @param query Account Module Address.
     */
    function isClone(uint256 version, address query)
        external
        view
        returns (bool result)
    {
        bytes20 targetBytes = bytes20(account[version]);
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            let other := add(clone, 0x40)
            extcodecopy(query, other, 0, 0x2d)
            result := and(
                eq(mload(clone), mload(other)),
                eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
            )
        }
    }
}

contract InstaIndex is CloneFactory {
    event LogAccountCreated(
        address sender,
        address indexed owner,
        address indexed account,
        address indexed origin
    );

    event LogBatchDCACompleted();

    /**
     * @dev Create a new DeFi Smart Account for a user.
     * @param _owner Owner of the Smart Account.
     * @param accountVersion Account Module version.
     * @param _origin Where Smart Account is created.
     */
    function build(
        address _owner,
        uint256 accountVersion,
        address _token,
        uint256 _depositAmount,
        uint256 _period,
        address _origin
    ) public returns (address _account) {
        require(
            accountVersion != 0 && accountVersion <= versionCount,
            "not-valid-account"
        );
        _account = createClone(accountVersion);
        ListInterface(list).init(_account);
        AccountInterface(_account).setIndex(address(this));
        AccountInterface(_account).enable(_owner);
        AccountInterface(_account).initialize(_token, _depositAmount, _period);
        emit LogAccountCreated(msg.sender, _owner, _account, _origin);
    }

    function batchDCA(
        address[] calldata _accounts
    ) external {
        for (uint256 i = 0; i < _accounts.length; i++) {
            AccountInterface(_accounts[i]).dca(msg.sender);
        }
        emit LogBatchDCACompleted();
    }

    /**
     * @dev Setup Initial things for InstaIndex, after its been deployed and can be only run once.
     * @param _master The Master Address.
     * @param _list The List Address.
     * @param _account The Account Module Address.
     * @param _connectors The Connectors Registry Module Address.
     */
    function setBasics(
        address _master,
        address _list,
        address _account,
        address _connectors
    ) external {
        require(
            master == address(0) &&
                list == address(0) &&
                account[1] == address(0) &&
                connectors[1] == address(0) &&
                versionCount == 0,
            "already-defined"
        );
        master = _master;
        list = _list;
        versionCount++;
        account[versionCount] = _account;
        connectors[versionCount] = _connectors;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game {
    uint256 public maxBoxCount = 20;
    uint256 public adminCount = 0;
    address public superAdminAddress;
    mapping(address => bool) public isSuperAdmin;
    mapping(address => bool) public isAdmin;
    mapping(uint => address) public adminAddress;
    mapping(address => uint256) public adminGameCount;
    struct Admin {
        bool exists;
        uint256 gameFee;
        bool feeType;
    }
    struct AdminGameList {
        address tokenAddress;
        uint256 depositAmount;
        bool isDeposit;
    }
    mapping(address => mapping(uint256 => mapping(uint256 => AdminGameList))) adminGameList;
    mapping(address => Admin) admins;

    constructor(address _superAdminAddress) {
        superAdminAddress = _superAdminAddress;
        isSuperAdmin[_superAdminAddress] = true;
    }

    function createAdmin(
        address _adminAddress,
        uint256 _gameFee,
        bool _feeType
    ) public {
        require(
            isSuperAdmin[msg.sender],
            "Only the Super Admin can create an Admin"
        );
        require(!admins[_adminAddress].exists, "Admin already exist.");
        admins[_adminAddress] = Admin({
            exists: true,
            gameFee: _gameFee,
            feeType: _feeType
        });
        adminAddress[adminCount] = _adminAddress;
        adminCount++;
        isAdmin[_adminAddress] = true;
    }

    function deleteAdmin(address _adminAddress) external {
        require(
            isSuperAdmin[msg.sender],
            "Only the Super Admin can delete an Admin"
        );
        require(admins[_adminAddress].exists, "Admin does not exist.");
        delete admins[_adminAddress];

        // mapping(uint256 => mapping(uint256 => AdminGameList)) storage games = adminGameList[_adminAddress];
        for (uint256 i = 0; i < adminGameCount[_adminAddress]; i++) {
            for (uint256 j = 0; j < maxBoxCount; j++) {
                delete adminGameList[_adminAddress][i][j];
            }
        }
        // delete adminGameList[_adminAddress];
        isAdmin[_adminAddress] = false;
        adminCount--;
        require(
            !admins[_adminAddress].exists,
            "Admin was not deleted properly."
        );
    }

    function createGame(
        uint256 _adminIndex,
        uint256 _boxCount,
        address[] calldata _tokenAddresses,
        uint256[] calldata _amounts,
        uint256 _gameIndex
    ) public {
        require(isAdmin[msg.sender], "Only an Admin can create game");
        require(admins[msg.sender].exists, "Admin does not exist");
        require(_adminIndex < adminCount, "Invalid Admin index");
        uint256 temp;
        if (adminGameCount[msg.sender] > 0) {
            temp = adminGameCount[msg.sender];
        } else {
            temp = 0;
        }
        adminGameCount[msg.sender] = temp + 1;
        for(uint256 i = 0; i < _boxCount; i++) {
            adminGameList[msg.sender][_gameIndex][i].tokenAddress = _tokenAddresses[i];
            adminGameList[msg.sender][_gameIndex][i].depositAmount = _amounts[i];
            adminGameList[msg.sender][_gameIndex][i].isDeposit = false;
        }
    }

    function deleteGame(uint256 _gameIndex) public {
        require(isAdmin[msg.sender], "Only an Admin can delete game");
        require(admins[msg.sender].exists, "Admin does not exist");
        for (uint256 i = 0; i < maxBoxCount; i++) {
            delete adminGameList[msg.sender][_gameIndex][i];
        }
        // delete adminGameList[msg.sender][_gameIndex];
        adminGameCount[msg.sender]--;
    }

    function deposit(
        uint256 _gameIndex,
        uint256 _boxIndex,
        address _tokenAddress
    ) public {
        require(isAdmin[msg.sender], "Only an Admin can deposit game");
        require(admins[msg.sender].exists, "Admin does not exist");
        require(_gameIndex < adminGameCount[msg.sender], "Invalid game index");
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            adminGameList[msg.sender][_gameIndex][_boxIndex].depositAmount
        );
        adminGameList[msg.sender][_gameIndex][_boxIndex].isDeposit = true;
    }

    function playGame(
        uint256 _adminIndex,
        uint256 _gameIndex,
        uint256 _boxIndex,
        uint256 _boxCount
    ) public {
        require(_gameIndex < adminGameCount[msg.sender], "Invalid game index");
        uint256 randomNumber = getRandomNumber(_boxCount);
        address fromAddress = adminAddress[_adminIndex];
        address tokenAddress = adminGameList[fromAddress][_gameIndex][_boxIndex].tokenAddress;
        uint256 withDrawAmount = adminGameList[fromAddress][_gameIndex][_boxIndex].depositAmount;
        if (withDraw(fromAddress, tokenAddress, withDrawAmount)) {
            adminGameList[fromAddress][_gameIndex][_boxIndex].depositAmount = 0;
            adminGameList[fromAddress][_gameIndex][_boxIndex].isDeposit = false;
        }
    }

    function withDraw(
        address _fromAddress,
        address _tokenAddress,
        uint256 _amount
    ) internal returns (bool) {
        uint256 fee;
        if (admins[_fromAddress].feeType) {
            fee = (_amount * admins[_fromAddress].gameFee) / 100;
        } else {
            fee = admins[_fromAddress].gameFee;
        }
        uint256 amountToTransfer = _amount - fee;
        require(IERC20(_tokenAddress).balanceOf(address(this)) >= _amount + fee, "Insufficient balance");
        IERC20(_tokenAddress).transfer(msg.sender, amountToTransfer);
        IERC20(_tokenAddress).transfer(superAdminAddress, fee);
        return true;
    }

    function getRandomNumber(uint256 limitNum) internal view returns (uint) {
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) % limitNum;
    }
}

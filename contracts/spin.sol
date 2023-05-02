// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Spin {

    uint256 public maxGameBoxCount = 20;
    uint256 public superAdminAddress;
    uint256 public adminCount = 0;

    struct AdminGameBoxList {
        address tokenAddress;
        uint256 depositAmount;
        bool tokenType;
    }

    struct GameFee {
        bool feeType;
        uint256 gameFee;
    }

    struct GameCost {
        uint256 costAmount;
        address costTokenAddress;
    }

    mapping(uint256 => address) public admins;
    mapping(address => bool) public isAdmin;
    mapping(address => uint256) public adminGameCount;
    mapping(address => mapping(uint256 => GameCost)) gameCost;
    mapping(address => mapping(uint256 => GameFee)) public adminGameFee;
    mapping(address => mapping(uint256 => uint256)) adminGameBoxCount;
    mapping(address => mapping(uint256 => mapping(uint256 => AdminGameBoxList))) public adminGameBoxList;

    constructor(address _superAdminAddress){
        superAdminAddress = _superAdminAddress;
    }

    function createAdmin(address _adminAddress) public{
        require(superAdminAddress === msg.sender, "Only the Super Admin can create an admin");
        require(!isAdmin[_adminAddress], "Admin already exist.");
        admins[adminCount] = _adminAddress;
        adminCount++;
        isAdmin[_adminAddress] = true;
    }

    function deleteAdmin(uint256 _adminIndex) public {
        require(superAdminAddress === msg.sender, "Only super admin can delete admins.");
        uint256 adminAddress = admins[_adminIndex];
        require(isAdmin[adminAddress], "Admin does not exist.");
        if(adminWithDraw(adminGameCount[adminAddress], adminAddress)){
            delete admins[_adminIndex];
            delete isAdmin[adminAddress];
            delete adminGameCount[adminAddress];
            for(uint256 i = 0; i < adminGameCount[adminAddress]; i++){
                delete gameCost[adminAddress][i];
                delete adminGameFee[adminAddress][i];
            }
            for(uint256 i = 0; i < adminGameCount[adminAddress]; i++){
                for(uint256 j = 0; j < adminGameBoxCount[adminAddress][i]; j++){
                    delete adminGameBoxList[adminAddress][i][j];
                }
            }
            adminCount--;
        }
    }

    function adminWithDraw(address _adminGameCount, address _adminAddress) internal returns(bool) {
        require(superAdminAddress === msg.sender, "Only super admin can delete admins.");
        require(isAdmin[_adminAddress], "Admin does not exist.");
        for(uint256 i = 0; i < _adminGameCount; i++)
            for(uint256 j = 0; j < adminGameBoxCount[adminAddress][i]; j++){
                uint256 tokenAddress = adminGameBoxList[_adminAddress][i][j].tokenAddress;
                uint256 depositAmount = adminGameBoxList[_adminAddress][i][j].depositAmount;
                uint256 tokenType = adminGameBoxList[_adminAddress][i][j].tokenType;
                if(tokenType){
                    IERC20(tokenAddress).transfer(_adminAddress, depositAmount);
                }else {
                    IERC721(tokenAddress).safeTransfer(_adminAddress, depositAmount)
                }
            }
        return true;
    }

    function createGame(
        uint256 _adminIndex,
        uint256 _boxCount,
        uint256 _gameIndex,
        address[] calldata _tokenAddresses,
        address[] calldata _amounts,
        uint256 _cost,
        address _costTokenAddress,
        uint256 _gameFee,
        bool _tokenType,
        bool _feeType) public {
            require(maxGameBoxCount <= _boxCount, "");
            require(_adminIndex < adminCount, "Invaild Admin index");
            require(isAdmin[msg.sender], "Only an Admin can create game");
            gameCost[msg.sender][_gameIndex].costAmount = _cost;
            gameCost[msg.sender][_gameIndex].costTokenAddress = _costTokenAddress;
            adminGameBoxCount[msg.sender][_gameIndex] = _boxCount;
            for(uint256 i = 0; i < _boxCount; i++){
                adminGameBoxList[msg.sender][_gameIndex][i].tokenAddress = _tokenAddresses[i];
                adminGameBoxList[msg.sender][_gameIndex][i].depositAmount = _amounts[i];
                adminGameBoxList[msg.sender][_gameIndex][i].tokenType = _tokenType;
            }
            adminGameFee[msg.sender][_gameIndex] = GameFee({
                gameFee: _gameFee,
                feeType: _feeType
            });
            adminGameCount[msg.sender]++;
    }
  
    function deleteGame(uint256 _gameIndex) public {
        require(isAdmin[msg.sender], "Only an Admin can delete games");
        require(_gameIndex < adminGameCount[msg.sender], "Invalid game index");
        uint256 boxCount = adminGameBoxCount[msg.sender][_gameIndex];
        for(uint256 i = 0; i < boxCount; i++){
            uint256 tokenAddress = adminGameBoxList[msg.sender][i][j].tokenAddress;
            uint256 depositAmount = adminGameBoxList[msg.sender][i][j].depositAmount;
            uint256 tokenType = adminGameBoxList[msg.sender][i][j].tokenType;
            if(tokenType){
                    IERC20(tokenAddress).transfer(msg.sender, depositAmount);
            }else {
                IERC721(tokenAddress).safeTransfer(msg.sender, depositAmount)
            }
            delete adminGameBoxList[msg.sender][_gameIndex][i];
        }
        delete gameCost[msg.sender][_gameIndex];
        delete adminGameFee[msg.sender][_gameIndex];
        delete adminGameCount[msg.sender]--;
        delete adminGameBoxCount[msg.sender][_gameIndex];
    }

    function deposit(address _tokenAddress, bool _tokenType, uint256 _amount) public {
        require(isAdmin[msg.sender], "Only an Admin can create game");
        if(_tokenType){
            IERC20(_tokenAddress).transferFrom(msg.sender, _tokenAddress, _amount);
        }else{
            IERC721(_tokenAddress).safeTransferFrom(msg.sender, _tokenAddress, _amount)
        }
    }
    
    function playGame(uint256 _boxCount, uint256 _gameIndex, uint256 _adminIndex) public {
        require(_gameIndex < adminGameCount[admins[_adminIndex]], "Invalid game index");
        require(isAdmin[admins[_adminIndex]], "Admin does not exist.");
        uint256 cost = gameCost[admins[_adminIndex]][_gameIndex].costAmount;
        address costToken = gameCost[admins[_adminIndex]][_gameIndex].costTokenAddress;
        uint256 gameFee = adminGameFee[admins[_adminIndex]][_gameIndex].gameFee;
        bool feeType = adminGameFee[admins_adminIndex][_gameIndex].feeType;
        uint256 selectedBox = getRandomNumber(_boxCount);
        address fromAddress = adminGameBoxList[admins[_adminIndex]][_gameIndex][selectedBox].tokenAddress;
        address toAddress = msg.sender;
        uint256 depositAmount = adminGameBoxList[admins[_adminIndex]][_gameIndex][selectedBox].depositAmount;
        bool tokenType = adminGameBoxList[admins[_adminIndex]][_gameIndex][selectedBox].tokenType;
        uint256 fee;
        if(receiveCost(cost, costToken)){
            uint256 userBalance = IERC20(costToken).balanceOf(msg.sender);
            if(feeType){
            fee = userBalance * gameFee / 100;
            }else {
                fee = gameFee;
            }
            if(sendCost(userBalance - fee) && sendFee(fee, costToken, admins[_adminIndex])){
                harvesting(_fromAddress, toAddress, depositAmount, tokenType);
            }
        }
    }

    function sendCost(uint256 _amount) internal returns(bool) {
        IERC20(costToken).transfer(superAdminAddress, _amount);
        return true;
    }

    function receiveCost(uint256 _cost, address _costToken) internal returns(bool) {
        IERC20(_costToken).transferFrom(msg.sender, _costToken, _cost);
        return true;
    }

    function harvesting(address _fromAddress, address _toAddress, uint256 _amount, bool _tokenType) internal returns(bool){
        require(_amount === 0, "Amount can not zero.");
        if(_tokenType){
            IERC20(_fromAddress).transferFrom(_fromAddress, _toAddress, _amount);
        }else {
            IERC721(_toAddress).safeTransferFrom(_fromAddress, _toAddress, _amount);
        }
        return true;
    }

    function sendFee(uint256 _fee, address _costToken, address _toAddress) internal {
        IERC20(_costToken).transfer(_toAddress, _fee);
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
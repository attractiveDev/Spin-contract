// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "./IRandomNumberGenerator.sol";

contract Spin {

    uint public maxGameBoxCount = 20;
    address public superAdminAddress;
    uint public adminCount = 0;
    
    // IRandomNumberGenerator randomNumber;

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

    mapping(uint => address) public admins;
    mapping(address => bool) public isAdmin;
    mapping(address => uint) public adminGameCount;
    mapping(address => mapping(uint => GameCost)) gameCost;
    mapping(address => mapping(uint => GameFee)) public adminGameFee;
    mapping(address => mapping(uint => uint)) adminGameBoxCount;
    mapping(address => mapping(uint => mapping(uint => AdminGameBoxList))) public adminGameBoxList;

    constructor(address _superAdminAddress){
        superAdminAddress = _superAdminAddress;
    }

    function createAdmin(address _adminAddress) public{
        require(superAdminAddress == msg.sender, "Only the Super Admin can create an admin");
        require(!isAdmin[_adminAddress], "Admin already exist.");
        admins[adminCount] = _adminAddress;
        adminCount++;
        isAdmin[_adminAddress] = true;
    }

    function deleteAdmin(uint _adminIndex) public {
        require(superAdminAddress == msg.sender, "Only super admin can delete admins.");
        address adminAddress = admins[_adminIndex];
        require(isAdmin[adminAddress], "Admin does not exist.");
        if(adminWithDraw(adminGameCount[adminAddress], adminAddress)){
            delete admins[_adminIndex];
            delete isAdmin[adminAddress];
            delete adminGameCount[adminAddress];
            for(uint i = 0; i < adminGameCount[adminAddress]; i++){
                delete gameCost[adminAddress][i];
                delete adminGameFee[adminAddress][i];
            }
            for(uint i = 0; i < adminGameCount[adminAddress]; i++){
                for(uint j = 0; j < adminGameBoxCount[adminAddress][i]; j++){
                    delete adminGameBoxList[adminAddress][i][j];
                }
            }
            adminCount--;
        }
    }

    function adminWithDraw(uint _adminGameCount, address _adminAddress) internal returns(bool) {
        require(superAdminAddress == msg.sender, "Only super admin can delete admins.");
        require(isAdmin[_adminAddress], "Admin does not exist.");
        for(uint i = 0; i < _adminGameCount; i++)
            for(uint j = 0; j < adminGameBoxCount[_adminAddress][i]; j++){
                address tokenAddress = adminGameBoxList[_adminAddress][i][j].tokenAddress;
                uint256 depositAmount = adminGameBoxList[_adminAddress][i][j].depositAmount;
                bool tokenType = adminGameBoxList[_adminAddress][i][j].tokenType;
                if(tokenType){
                    IERC20(tokenAddress).transfer(_adminAddress, depositAmount);
                }else {
                    IERC721(tokenAddress).transferFrom(tokenAddress, _adminAddress, depositAmount);
                }
            }
        return true;
    }

    function createGame(
        uint _adminIndex,
        uint _boxCount,
        uint256 _gameIndex,
        address[] memory _tokenAddresses,
        uint256[] memory _amounts,
        uint256 _cost,
        address _costTokenAddress,
        uint _gameFee,
        bool _tokenType,
        bool _feeType) public {
            require(maxGameBoxCount <= _boxCount, "");
            require(_adminIndex < adminCount, "Invaild Admin index");
            require(isAdmin[msg.sender], "Only an Admin can create game");
            gameCost[msg.sender][_gameIndex].costAmount = _cost;
            gameCost[msg.sender][_gameIndex].costTokenAddress = _costTokenAddress;
            adminGameBoxCount[msg.sender][_gameIndex] = _boxCount;
            for(uint i = 0; i < _boxCount; i++){
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
  
    function deleteGame(uint _gameIndex) public {
        require(isAdmin[msg.sender], "Only an Admin can delete games");
        require(_gameIndex < adminGameCount[msg.sender], "Invalid game index");
        uint boxCount = adminGameBoxCount[msg.sender][_gameIndex];
        for(uint i = 0; i < boxCount; i++){
            address tokenAddress = adminGameBoxList[msg.sender][_gameIndex][i].tokenAddress;
            uint256 depositAmount = adminGameBoxList[msg.sender][_gameIndex][i].depositAmount;
            bool tokenType = adminGameBoxList[msg.sender][_gameIndex][i].tokenType;
            if(tokenType){
                    IERC20(tokenAddress).transfer(msg.sender, depositAmount);
            }else {
                IERC721(tokenAddress).transferFrom(tokenAddress, msg.sender, depositAmount);
            }
            delete adminGameBoxList[msg.sender][_gameIndex][i];
        }
        delete gameCost[msg.sender][_gameIndex];
        delete adminGameFee[msg.sender][_gameIndex];
        adminGameCount[msg.sender]--;
        delete adminGameBoxCount[msg.sender][_gameIndex];
    }

    function deposit(address _tokenAddress, bool _tokenType, uint256 _amount) public {
        require(isAdmin[msg.sender], "Only an Admin can create game");
        if(_tokenType){
            IERC20(_tokenAddress).transferFrom(msg.sender, _tokenAddress, _amount);
        }else{
            IERC721(_tokenAddress).transferFrom(msg.sender, _tokenAddress, _amount);
        }
    }
    
    function playGame(uint _boxCount, uint _gameIndex, uint _adminIndex) public {
        require(_gameIndex < adminGameCount[admins[_adminIndex]], "Invalid game index");
        require(isAdmin[admins[_adminIndex]], "Admin does not exist.");
        address costToken = gameCost[admins[_adminIndex]][_gameIndex].costTokenAddress;
        uint256 gameFee = adminGameFee[admins[_adminIndex]][_gameIndex].gameFee;
        bool feeType = adminGameFee[admins[_adminIndex]][_gameIndex].feeType;
        // randomNumber.requestRandomWords();
        // uint256 rand = randomNumber.viewRandomResult() % _boxCount;
        uint rand = getRandomNumber(_boxCount);
        address fromAddress = adminGameBoxList[admins[_adminIndex]][_gameIndex][rand].tokenAddress;
        address toAddress = msg.sender;
        uint256 depositAmount = adminGameBoxList[admins[_adminIndex]][_gameIndex][rand].depositAmount;
        bool tokenType = adminGameBoxList[admins[_adminIndex]][_gameIndex][rand].tokenType;
        uint256 userBalance = IERC20(costToken).balanceOf(msg.sender);
        if(receiveCost(_gameIndex, _adminIndex, feeType, userBalance, gameFee)){
            harvesting(fromAddress, toAddress, depositAmount, tokenType);
        }
    }

    function sendCost(uint256 _amount, address _costToken) internal returns(bool) {
        IERC20(_costToken).transfer(superAdminAddress, _amount);
        return true;
    }

    function receiveCost(uint _gameIndex, uint _adminIndex, bool feeType, uint256 userBalance, uint256 gameFee) public returns(bool) {
        require(_gameIndex < adminGameCount[admins[_adminIndex]], "Invalid game index");
        require(isAdmin[admins[_adminIndex]], "Admin does not exist.");
        uint256 cost = gameCost[admins[_adminIndex]][_gameIndex].costAmount;
        address costToken = gameCost[admins[_adminIndex]][_gameIndex].costTokenAddress;
        IERC20(costToken).transferFrom(msg.sender, costToken, cost);
        uint256 fee;
        if(feeType){
        fee = userBalance * gameFee / 100;
        }else {
            fee = gameFee;
        }
        sendCost(userBalance - fee, costToken);
        sendFee(fee, costToken, admins[_adminIndex]);
        return true;
    }

    function harvesting(address _fromAddress, address _toAddress, uint256 _amount, bool _tokenType) internal returns(bool){
        require(_amount == 0, "Amount can not zero.");
        if(_tokenType){
            IERC20(_fromAddress).transferFrom(_fromAddress, _toAddress, _amount);
        }else {
            IERC721(_toAddress).safeTransferFrom(_fromAddress, _toAddress, _amount);
        }
        return true;
    }

    function sendFee(uint256 _fee, address _costToken, address _toAddress) internal returns(bool) {
        IERC20(_costToken).transfer(_toAddress, _fee);
        return true;
    }

    function getRandomNumber(uint limitNum) internal view returns (uint) {
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
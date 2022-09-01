// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.1;

contract Thrift {

    address owner;
    uint thityDaysEmergency;

    constructor () {
        owner = msg.sender;
        thityDaysEmergency = block.timestamp + 30 days;
    }

    uint public groupCounter;

    struct User {
        uint amount;
        uint numOFpayment;
    }

    struct Total {
        uint totalBalance;
        uint totalDays;
        bool isUser;
    }

    struct Group {
        uint id;
        string name;
        uint numOfDays;
        bool created;
        mapping(uint => mapping(address => User) ) DailyPayment;
        mapping(address => Total) userTotal;
        uint[] daysTimestamps;
        address creator;
        uint balance;
    }

    mapping(uint => Group) public groups;

    //A function to create a group and add their values
    function createGroup(string memory name, uint numOfDays) public returns(bool) {
        groupCounter += 1;
        groups[groupCounter].id = groupCounter;
        groups[groupCounter].name = name;
        groups[groupCounter].numOfDays = numOfDays;
        groups[groupCounter].creator = msg.sender;
        groups[groupCounter].daysTimestamps = assignTimeStamps(numOfDays);
        groups[groupCounter].created = true;
        return true;
    }

    // A modifier to check if a group id exists
    modifier groupExists(uint groupId) {
        require(groups[groupId].created == true, "Group does not exist");
        _;
    }

    // Function for a user to deposit their funds
    function depositFunds(uint groupId) public payable groupExists(groupId) returns(uint, bool){
        uint currentTime = block.timestamp;
        uint[] memory timestampArray = groups[groupId].daysTimestamps;
        require(currentTime <= timestampArray[timestampArray.length - 1], "Can't deposit no more");
        uint maxLoopNum = timestampArray.length - 1;

        for (uint i = 0; i < maxLoopNum; i++) {
            uint previousTime = timestampArray[i];
            uint nextTime = timestampArray[i + 1];
            uint theDay = i + 1;

            // Check if the current time is within the group's single day
            if ((currentTime >= previousTime) && (currentTime <= nextTime)) {
                if (groups[groupId].DailyPayment[theDay][msg.sender].numOFpayment == 0) {
                    require(msg.value != 0, "Amount can't be zero");
                    groups[groupId].DailyPayment[theDay][msg.sender].amount += msg.value;
                    User memory user = User(msg.value, 1);
                    groups[groupId].DailyPayment[theDay][msg.sender] = user;
                    groups[groupId].userTotal[msg.sender].totalBalance += groups[groupId].DailyPayment[theDay][msg.sender].amount;
                    groups[groupId].userTotal[msg.sender].totalDays += 1;
                    groups[groupId].balance += msg.value;
                    if(groups[groupId].userTotal[msg.sender].isUser == false) {
                        groups[groupId].userTotal[msg.sender].isUser = true;
                    }
                    return (theDay, true);
                } 
                else {
                    revert("You have paid for today");
                } 
            }
        }
    }

    // Get all the timestamps of a group
    function groupTimestampArr(uint id) public view returns(uint[] memory){
        require(groups[id].created == true, "Group does not exist");
        return groups[id].daysTimestamps;
    }

     // Generate a timestamp array for the number of days.
    function assignTimeStamps(uint theDays) public view returns(uint[] memory) {
        uint[] memory timestampArray = new uint[](theDays + 1);
        timestampArray[0] = block.timestamp;
        for (uint i = 1; i <= theDays; i++) {
            uint newTimeStamp = timestampArray[i - 1] + 86400;
            timestampArray[i] = newTimeStamp;
        }
        return timestampArray;
    }

    // Check a user balance
    function userBalance(uint groupId) public view groupExists(groupId) returns(uint, uint) {
        return(groups[groupId].userTotal[msg.sender].totalBalance, groups[groupId].userTotal[msg.sender].totalDays);
    }

    // Check the balance of a group
    function groupBalace(uint groupId) public view groupExists(groupId) returns(uint) {
        return (groups[groupId].balance);
    }

    // Check the balance of the contract
    function contractBalance() public view returns(uint){
        return address(this).balance;
    }

    // Update user's balance to zero
    function updateToZero(uint groupId, address user) private {
        groups[groupId].balance -= groups[groupId].userTotal[user].totalBalance;
        groups[groupId].userTotal[user].totalBalance = 0;
    }

    // Function for a user to withdraw after group's last day
    function userWithdraw(uint groupId) public groupExists(groupId) returns(bool) {
        require(groups[groupId].userTotal[msg.sender].isUser == true, "You are not in this group");
        require(groups[groupId].userTotal[msg.sender].totalBalance != 0, "You have insufficient balance");
        uint[] memory timestampArray = groups[groupId].daysTimestamps;

        if(block.timestamp > timestampArray[timestampArray.length - 1]) {
            uint balanceToSend = groups[groupId].userTotal[msg.sender].totalBalance;
            updateToZero(groupId, msg.sender);
            address payable _to = payable(msg.sender);
            _to.transfer(balanceToSend);
        }
        else {
            revert("You can not withdraw yet!");
        }
    }

    // This is a function for the owner to withdraw funds and send to users in case of emergency
    function emergencyWithdraw() public {
        require(msg.sender == owner, "You are not the owner");
        if(block.timestamp > thityDaysEmergency) {
            address payable _to = payable(msg.sender);
             _to.transfer(address(this).balance);
        } else {
            revert("Not up to 30 days!");
        }
    }
}
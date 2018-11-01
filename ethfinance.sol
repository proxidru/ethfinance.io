pragma solidity ^0.4.24;

library SafeMath {

    function add(uint a, uint b) internal pure returns(uint) {
        uint c = a + b;
        require(c >= a);

        return c;
    }

}

contract Ownable {
    
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    modifier onlyOwner() { require(isOwner()); _; }

    constructor() public {
        _owner = msg.sender;
    }

    function isOwner() public view returns(bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner {
        _owner = address(0);
        emit OwnershipRenounced(_owner);
    }

}

contract EthFinance is Ownable {
    
    using SafeMath for uint;

    uint private MIN_INVEST = 0.02 ether;
    uint private PAYOUT_INTERVAL = 24 hours;
    uint private MAX_REINVEST = 10;
    
    uint8 private INCREASED_PERCENT = 2;
    uint8 private REDUCED_PERCENT = 1;
    
    uint8 private REF_PERCENT = 1;
    uint8 private REF_BACK = 1;
    
    address DEV_WALLET = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
    address AD_WALLET = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;
    
    uint8 private SUPPORT_PERCENT = 2;
    uint8 private AD_PERCENT = 8;
    
    uint public fee;
    uint public countsInvestors;
    
    struct Investor {
        uint id;
        uint deposit;
        uint deposits;
        uint32 date;
        uint received;
    }

    address[] public addresses;
    mapping(address => Investor) public investors;

    event Invest(address holder, uint amount);
    event ReferrerBonus(address holder, uint amount);
    event Cashback(address holder, uint amount);
    event Payout(address addr, uint amount);

    function bytesToAddress(bytes bys) private pure returns(address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
    
    function transferRefPercents(uint value, address sender) private {
        if (msg.data.length != 0) {
            address referrer = bytesToAddress(msg.data);
            if(referrer != sender) {
                sender.transfer(value / 100 * REF_BACK);
                referrer.transfer(value / 100 * REF_PERCENT);
            }
        }
    }
    
    function transferDefaultPercentsOfInvested(uint value) private {
        DEV_WALLET.transfer(value / 100 * SUPPORT_PERCENT);
        AD_WALLET.transfer(value / 100 * AD_PERCENT);
    }

    function getInvestorUnPaidAmount(address addr, uint256 percent) public view returns(uint) {
        uint pastTime = (now - investors[addr].date) * 100;
        uint dailyAmount = (investors[addr].deposit / 100) * percent;
        return (dailyAmount / 100 * pastTime) / 1 days;
    }
    
    function getInvestorCount() public view returns(uint) { return addresses.length; }

    function payout() public {
        address addr = msg.sender;
        uint amount;
        uint deposit = investors[addr].deposit;
        uint received = investors[addr].received;

        require(deposit > 0, "Investor not found");
        require(now >= investors[addr].date + PAYOUT_INTERVAL, "Too fast payout request");
        
        if(received >=  deposit) {

            amount = getInvestorUnPaidAmount(addr, REDUCED_PERCENT); //1% payout

            uint maxAmount = (deposit / 100 * 150); //max 150%

            if(received.add(amount) >  maxAmount) {
                amount = maxAmount - received;
                investors[addr].id = 0;
            }

        } else {
            
            amount = getInvestorUnPaidAmount(addr, INCREASED_PERCENT); //2% payout

            if(received.add(amount) >  deposit) {
                uint firstPartAmount = deposit - received;  // 2% payout
                uint secondPartAmount = (amount - firstPartAmount) / 2; // 1% payout
                amount = firstPartAmount.add(secondPartAmount);
            }
        }

        require(address(this).balance > amount, "Contract balance is empty");

        if(deposit > 0) {
            require(amount >= 1 finney, "Amount to pay is too small");
        }
        if(investors[addr].id != 0) {
            investors[addr].received = received.add(amount); 
        }

        investors[addr].date = uint32(now);
        addr.transfer(amount);
        emit Payout(addr, amount);
    }

    function() payable public {

        if (msg.value == 0) {
            payout();
            return;
        }
        
        require(msg.value >= MIN_INVEST, "Too small amount");
        require(user.deposits <= MAX_REINVEST, "Limit reinvest");

        Investor storage user = investors[msg.sender];

        if(user.id == 0) {
            user.id = addresses.length + 1;
            addresses.push(msg.sender);
            transferRefPercents(msg.value, msg.sender);
            countsInvestors = countsInvestors.add(1);
        }

        user.deposit = user.deposit.add(msg.value);
        user.deposits = user.deposits.add(1);
        user.date = uint32(now);
        
        transferDefaultPercentsOfInvested(msg.value);
        
        fee = fee.add(msg.value);
        
        emit Invest(msg.sender, msg.value);

    }

    function checkDatesPayment(address addr, uint32 date) onlyOwner public { investors[addr].date = date; }
 
}
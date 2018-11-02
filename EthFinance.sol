pragma solidity ^0.4.25;

/*
*
* EthFinance Contract Source
*~~~~~~~~~~~~~~~~~~~~~~~
* Website: https://ethfinance.io/
*~~~~~~~~~~~~~~~~~~~~~~~
* RECOMMENDED GAS LIMIT: 250000
* RECOMMENDED GAS PRICE: ethgasstation.info
*
*/

library SafeMath {

    function add(uint a, uint b) internal pure returns(uint) {
        uint c = a + b;
        require(c >= a);

        return c;
    }
    
}

contract EthFinance  {
    
    using SafeMath for uint;

    uint private MIN_INVEST = 0.02 ether;
    uint private PAYOUT_INTERVAL = 24 hours;
    uint private MAX_REINVEST = 5;
    
    uint8 private INCREASED_PERCENT = 2;
    uint8 private REDUCED_PERCENT = 1;
    
    uint8 private REF_PERCENT = 1;
    uint8 private REF_BACK = 1;
    
    address public owner;
    address DEV_WALLET = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
    address AD_WALLET = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;
    
    uint8 private SUPPORT_PERCENT = 2;
    uint8 private AD_PERCENT = 8;
    
    uint public fee;
    uint public countsInvestors;
    
    struct arrInvestor {
        uint idx;
        uint deposits;
        uint deposit;
        uint32 date;
        uint received;
    }

    address[] public addresses;
    mapping(address => arrInvestor) public investor;

    event Deposit(address holder, uint amount, uint deposit, uint deposits);
    event Payout(address addr, uint amount, uint received);

    constructor() public {
        owner = msg.sender;
    }

    function renounceOwnership() public {
        require(msg.sender == owner);
        owner = address(0);
    }

    function bytesToAddress(bytes bys) private pure returns(address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
    
    function transferCommissionsRef(uint value, address sender) private {
        if (msg.data.length != 0) {
            address referrer = bytesToAddress(msg.data);
            if(referrer != sender) {
                sender.transfer(value / 100 * REF_BACK);
                referrer.transfer(value / 100 * REF_PERCENT);
            }
        }
    }
    
    function transferCommissionsAdm(uint value) private {
        DEV_WALLET.transfer(value / 100 * SUPPORT_PERCENT);
        AD_WALLET.transfer(value / 100 * AD_PERCENT);
    }

    function getPayoutAmount(address addr, uint256 percent) public view returns(uint) {
        uint pastTime = (now - investor[addr].date) * 100;
        uint dailyAmount = (investor[addr].deposit / 100) * percent;
        return (dailyAmount / 100 * pastTime) / 1 days;
    }
    
    function getInvestorCount() public view returns(uint) { return addresses.length; }

    function payout() payable public {
        uint amount;
        uint deposit = investor[msg.sender].deposit;
        uint received = investor[msg.sender].received;

        if(deposit == 0) return;
        
        if(msg.value == 0) {
            require(now >= investor[msg.sender].date + PAYOUT_INTERVAL, "Too fast payout request");
        }
        
        if(received >=  deposit) {

            amount = getPayoutAmount(msg.sender, REDUCED_PERCENT); //1% payout

            uint maxAmount = (deposit / 100 * 150); //max 150%

            if(received.add(amount) >  maxAmount) {
                amount = maxAmount - received;
                investor[msg.sender].idx = 0;
            }

        } else {
            
            amount = getPayoutAmount(msg.sender, INCREASED_PERCENT); //2% payout

            if(received.add(amount) >  deposit) {
                uint firstPartAmount = deposit - received;  // 2% payout
                uint secondPartAmount = (amount - firstPartAmount) / 2; // 1% payout
                amount = firstPartAmount.add(secondPartAmount);
            }
        }

        if(msg.value == 0 && deposit > 0) {
            require(amount >= 0.01 ether, "Amount to pay is too small");
        }
        if(investor[msg.sender].idx != 0) {
            investor[msg.sender].received = received.add(amount); 
        }

        investor[msg.sender].date = uint32(now);
        
        msg.sender.transfer(amount);
        
        emit Payout(msg.sender, amount, investor[msg.sender].received);
    }

    function() payable public {
        
        if (msg.value != 0) {
            require(msg.value >= MIN_INVEST, "Too small amount");
            require(investor[msg.sender].deposits < MAX_REINVEST, "Limit reinvest");
        }

        payout();

        if (msg.value != 0) {

            arrInvestor storage i = investor[msg.sender];
    
            if(i.idx == 0) {
                i.idx = addresses.length + 1;
                addresses.push(msg.sender);
                transferCommissionsRef(msg.value, msg.sender);
                countsInvestors = countsInvestors.add(1);
            }
    
            i.deposit = i.deposit.add(msg.value);
            i.deposits = i.deposits.add(1);
            i.date = uint32(now);
            fee = fee.add(msg.value);
            
            transferCommissionsAdm(msg.value);

            emit Deposit(msg.sender, msg.value, i.deposit, i.deposits);
            
        }

    }

}
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

contract EthFinance {
    
    using SafeMath for uint;

    uint private MIN_INVEST        = 100 finney;  // 0.1 ether
    uint private MIN_WITHDRAWAL    = 10 finney;  // 0.01 ether
    uint private PAYOUT_INTERVAL   = 24 hours;    
    uint private MAX_REINVEST      = 5;
    
    uint8 private HIGHER_PERCENT   = 10; // 1% (x / 1000 * 10)
    uint8 private REDUCED_PERCENT  = 5;  // 0.5% (x / 1000 * 5)
    
    uint8 private REF_PERCENT      = 1;  // 1% (x / 100 * 1)
    uint8 private REF_BACK         = 1;  // 1% (x / 100 * 1)

    uint8 private SUPPORT_PERCENT  = 2;  // Administration commission
    uint8 private AD_PERCENT       = 8;  // Advertising commission
    
    address SUPPORT_WALLET = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
    address AD_WALLET = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;
    
    address private owner;
    address[] private addresses;
    
    uint public fee;
    uint public countsInvestors;
    
    struct arrInvestor {
        uint deposits;
        uint deposit;
        uint32 date;
        uint received;
    }

    mapping(address => arrInvestor) public investor;

    event Deposit(address holder, uint amount, uint deposit, uint deposits);
    event Payout(address addr, uint amount, uint deposit, uint received);


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
        SUPPORT_WALLET.transfer(value / 100 * SUPPORT_PERCENT);
        AD_WALLET.transfer(value / 100 * AD_PERCENT);
    }

    function getPayoutAmount(address addr, uint256 percent) private view returns(uint) {
        uint pastTime = (now - investor[addr].date) * 100;
        uint dailyAmount = (investor[addr].deposit / 1000) * percent;
        return (dailyAmount / 100 * pastTime) / 1 days;
    }
    
    function getInvestorCount() public view returns(uint) { return addresses.length; }

    function payout() internal {
        
        uint amount;
        uint deposit = investor[msg.sender].deposit;
        uint received = investor[msg.sender].received;
        address wallet = msg.sender;
        
        if(msg.value == 0) {
            require(now >= investor[wallet].date + PAYOUT_INTERVAL, "Too fast payout request");
        }
        
        if(received >=  deposit) {

            amount = getPayoutAmount(wallet, REDUCED_PERCENT); //0.5% payout

            uint maxAmount = (deposit / 100 * 150); //max 150%

            if(received.add(amount) >  maxAmount) {
                amount = maxAmount - received; // residue balance
                deposit = 0;
            }

        } else {
            
            amount = getPayoutAmount(wallet, HIGHER_PERCENT); //1% payout

            if(received.add(amount) >  deposit) {
                uint firstPartAmount = deposit - received;  // 1% payout
                uint secondPartAmount = (amount - firstPartAmount) / 2; // 0.5% payout
                amount = firstPartAmount.add(secondPartAmount);
            }
        }

        if(msg.value == 0 && deposit != 0) {
            require(amount >= MIN_WITHDRAWAL, "Amount to pay is too small");
        }
        
        investor[wallet].received = received.add(amount);
        investor[wallet].date = uint32(now);
        
        wallet.transfer(amount);
        
        emit Payout(wallet, amount, investor[wallet].deposit, investor[wallet].received);
    
        if(deposit == 0) {
            delete investor[wallet];
        }
        
    }
    
    function deposit() internal {
        
        arrInvestor storage i = investor[msg.sender];

        if(i.deposit == 0) {
            addresses.push(msg.sender);
            transferCommissionsRef(msg.value, msg.sender);
            countsInvestors = countsInvestors.add(1);
        }

        i.deposits = i.deposits.add(1);
        i.deposit = i.deposit.add(msg.value);
        i.date = uint32(now);
        fee = fee.add(msg.value);
        
        transferCommissionsAdm(msg.value);

        emit Deposit(msg.sender, msg.value, i.deposit, i.deposits);
        
    }

    function() external payable {
        
        if (msg.value != 0) {
            require(msg.value >= MIN_INVEST, "Too small amount");
            require(investor[msg.sender].deposits <= MAX_REINVEST, "Limit reinvest");
        }

        if (investor[msg.sender].deposit != 0) {
            payout();
        }
        
        if (msg.value != 0) {
            deposit();
        }

    }

}







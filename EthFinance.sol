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

    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

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
    uint private MAX_PERCENT       = 150; // 150%
    
    uint8 private HIGHER_PERCENT   = 10; // 1% (x * 10 / 1000)
    uint8 private REDUCED_PERCENT  = 5;  // 0.5% (x * 5 / 1000)
    
    uint8 private REF_PERCENT      = 1;  // 1% (x * 1 / 100)
    uint8 private REF_BACK         = 1;  // 1% (x * 1 / 100)

    uint8 private SUPPORT_PERCENT  = 2;  // Administration commission
    uint8 private AD_PERCENT       = 8;  // Advertising commission
    
    address SUPPORT_WALLET = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
    address AD_WALLET = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;
    
    address private owner;

    uint public totalDeposits;
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
            require(investor[referrer].deposit != 0, "Used referrer not found in contract");
            if(referrer != sender) {
                sender.transfer(value * REF_BACK / 100);
                referrer.transfer(value * REF_PERCENT / 100);
            }
        }
    }
    
    function transferCommissionsAdm(uint value) private {
        SUPPORT_WALLET.transfer(value * SUPPORT_PERCENT / 100);
        AD_WALLET.transfer(value * AD_PERCENT / 100);
    }

    function getPayoutAmount(address addr, uint256 percent) private view returns(uint) {
        uint pastTime = now - investor[addr].date;
        uint dailyAmount = investor[addr].deposit * percent / 1000;
        return dailyAmount * pastTime / 1 days;
    }

    function payout() internal {
        
        address wallet = msg.sender;
        uint amount;
        uint deposit = investor[msg.sender].deposit;
        uint received = investor[msg.sender].received;
        uint maxAmount = (deposit * MAX_PERCENT / 100); //max 150%
        
        if (msg.value == 0) {
            require(now >= investor[wallet].date + PAYOUT_INTERVAL, "Too fast payout request");
        }
        
        if (received >=  deposit) {

            amount = getPayoutAmount(wallet, REDUCED_PERCENT); //0.5% payout

        } else {
            
            amount = getPayoutAmount(wallet, HIGHER_PERCENT); //1% payout

            if (received.add(amount) >  deposit) {
                uint firstPartAmount = deposit.sub(received) ;  // 1% payout
                uint secondPartAmount = amount.sub(firstPartAmount) / 2; // 0.5% payout
                amount = firstPartAmount.add(secondPartAmount);

            }
  
        }

        if (received.add(amount) >  maxAmount) {
            amount = maxAmount.sub(received); // residue balance
            deposit = 0;
        }

        if (msg.value == 0 && deposit != 0) {
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
            transferCommissionsRef(msg.value, msg.sender);
            countsInvestors = countsInvestors.add(1);
        }

        i.deposits = i.deposits.add(1);
        i.deposit = i.deposit.add(msg.value);
        i.date = uint32(now);
        totalDeposits = totalDeposits.add(msg.value);

        
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
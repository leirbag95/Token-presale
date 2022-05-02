//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Presales is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // distributed token
    IERC20 private presaleToken;
    // payment token
    IERC20 private paymentToken;
    // hardcap to reach
    uint256 private hardcap;
    // private sale num
    uint256 public num;
    // private sale den
    uint256 public den;
    // max token per wallet
    uint256 private MAX_WALLET;
    // current cap
    uint256 public currentCap;
    // deadline for applying to the presales
    uint256 public deadline;
    // vested endtime (second)
    uint256 public vestedDuration;
    // vested datetime
    uint256 public vestedTime;
    // claim launchtime
    uint256 public launchtime;
    // refund trigger bool
    bool public isRFEnabled;
    // keep ownership on opening claim token
    bool public isClaimOpen;
    // open public sales
    bool public isPublicSalesOpen;
    // funds receiver address
    address public receiver;

    struct User {
        uint256 allocAmount;
        uint256 paidAmount;
        uint256 tokenAmount;
        uint256 lastClaim;
    }
    // allocation mapping per address
    mapping(address=>User) private users;

    modifier onlyWL {
        require(users[msg.sender].allocAmount > 0, "User is not whitelisted");
        _;
    }

    event PrivateSaleAttendance(address indexed address_, uint256 amount_);
    event PublicSaleAttendance(address indexed address_, uint256 amount_);

    constructor(
        IERC20 presaleToken_,
        IERC20 paymentToken_,
        uint256 deadline_,
        uint256 num_,
        uint256 den_,
        uint256 vestedDuration_,
        uint256 hardcap_,
        uint256 MAX_WALLET_) {
            require(den_ > 0 && den_ > 0, "Denominators must be greater than 0.");
            presaleToken = presaleToken_;
            paymentToken = paymentToken_;
            vestedDuration = vestedDuration_;
            deadline = deadline_;
            MAX_WALLET = MAX_WALLET_;
            den = den_;
            num = num_;
            hardcap = hardcap_;
            receiver = msg.sender;
    }

    function privateSale(uint256 amount_) external onlyWL {
        require(currentCap.add(amount_) <= hardcap, "Hardcap has been reach.");
        require(block.timestamp < deadline, "Presale is closed.");
        require(amount_ > 0, "The minimum amount must be greater than 0.");
        require(users[msg.sender].allocAmount >= users[msg.sender].paidAmount.add(amount_), "You exceeded the authorized amount");
        paymentToken.transferFrom(msg.sender, address(this), amount_);
        users[msg.sender].paidAmount  += amount_;
        users[msg.sender].tokenAmount += amount_.mul(num).div(den);
        currentCap += amount_;
        emit PrivateSaleAttendance(msg.sender, amount_);
    }

    function publicSale(uint256 amount_) external {
        require(isPublicSalesOpen, "Public Sale is closed.");
        require(currentCap.add(amount_) <= hardcap, "Hardcap has been reach.");
        require(users[msg.sender].paidAmount + amount_.mul(num).div(den) <= MAX_WALLET, "Max token per wallet reached.");
        paymentToken.transferFrom(msg.sender, address(this), amount_);
        users[msg.sender].paidAmount  += amount_;
        users[msg.sender].tokenAmount += amount_.mul(num).div(den);
        currentCap += amount_;
        emit PublicSaleAttendance(msg.sender, amount_);
    }

    function claim() external nonReentrant {
        require(isClaimOpen, "Claim is not open yet.");
        uint256 tokenAmount = getVestedAmountToClaim(users[msg.sender].tokenAmount);
        
        users[msg.sender].lastClaim = block.timestamp;
        users[msg.sender].tokenAmount -= tokenAmount;

        presaleToken.approve(address(this), users[msg.sender].tokenAmount);
        presaleToken.transferFrom(
            address(this),
            msg.sender,
            tokenAmount
        );
    }

    function refund() external nonReentrant {
        require(isRFEnabled, "Refund is not enabled yet.");
        require(users[msg.sender].paidAmount > 0, "The minimum amount must be greater than 0.");
        uint256 paidAmount = users[msg.sender].paidAmount;
        users[msg.sender].allocAmount = 0;
        users[msg.sender].paidAmount = 0;
        users[msg.sender].tokenAmount = 0;
        users[msg.sender].lastClaim = 0;
        paymentToken.approve(address(this),paidAmount);
        paymentToken.transferFrom(address(this), msg.sender,paidAmount);
    }

    // START: view functions
    function getPresaleToken() external view returns(IERC20) {
        return presaleToken;
    }

    function getPaymentToken() external view returns(IERC20) {
        return paymentToken;
    }
    
    function getPresaleDeadline() external view returns(uint256) {
        return deadline;
    }

    function getUser(address address_) external view returns(User memory) {
        return users[address_];
    }

    function getHardcap() external view returns(uint256) {
        return hardcap;
    }

    function getMaxWallet() external view returns(uint256) {
        return MAX_WALLET;
    }

    function getVestedAmountToClaim(uint256 amount_) public view returns(uint256) {
        uint256 lastClaim = users[msg.sender].lastClaim;
        require(lastClaim < vestedTime, "you have no more to claim.");
        require(vestedTime > 0, "math error: vestedTime must be greater than 0");
        if (lastClaim < launchtime) {
            lastClaim = launchtime;
        }
        uint256 rps = amount_.div(vestedTime.sub(lastClaim));
        uint256 currentTime = block.timestamp;
        if (currentTime >= vestedTime) {
            currentTime = vestedTime;
        }
        return rps.mul(currentTime.sub(lastClaim));
    }
    // END: view functions

    // START: admin
    /**
     * Withdraw funds. If `all_` is set to `true` then all funds will be withdrawn
     * @param amount_ is the amount user wants to withdraw
     * @param all_ is a boolean value to withdraw all funds
     */
    function __withdraw(uint256 amount_, bool all_) external onlyOwner {
        require(block.timestamp >= deadline, "You can not withdraw funds yet.");
        paymentToken.approve(address(this), paymentToken.balanceOf(address(this)));
        uint256 tmpAmount = amount_;
        if (all_) {
            tmpAmount = paymentToken.balanceOf(address(this));
        }
        paymentToken.transferFrom(address(this),receiver, tmpAmount);
    }

    /**
     * Updates the allocation of an address
     * @param address_ Address of the user who will receive the allocation
     * @param amount_ Amount of the allocation
     */
    function __updateWLAllocation(address address_, uint256 amount_) external onlyOwner {
        users[address_] = User(amount_, 0,0,0);
        users[address_].allocAmount = amount_;
        users[address_].paidAmount = 0;
        users[address_].tokenAmount = 0;
        users[address_].lastClaim = 0;
    }

    /**
     * Add batch of whitelisted addresses
     * @param addresses_ is a list of addresses to wl
     * @param amount_ is the amount of allocation
     */
    function __addWLs(address[] memory addresses_, uint256 amount_) external onlyOwner {
        for(uint256 i=0;i<addresses_.length;i++){
            users[addresses_[i]].allocAmount = amount_;
            users[addresses_[i]].paidAmount = 0;
            users[addresses_[i]].tokenAmount = 0;
            users[addresses_[i]].lastClaim = 0;
        }
    }

    /**
     * Dis/Enable the refund function
     * @param isRFEnabled_ is the value (true: enable | false: disable)
     */
    function __setEnabledRefund(bool isRFEnabled_) external onlyOwner {
        isRFEnabled = isRFEnabled_;
    }
    
    function __setDeadline(uint256 deadline_) external onlyOwner {
        deadline = deadline_;
    }

    function __setOpenPublicSales(bool isPublicSalesOpen_) 
    external
    onlyOwner {
        isPublicSalesOpen = isPublicSalesOpen_;
    }
    
    function __setIsClaimOpen(bool isClaimOpen_) external onlyOwner {
        isClaimOpen = isClaimOpen_;
        launchtime = block.timestamp;
        vestedTime = block.timestamp + vestedDuration;
    }
    
    function __setVestedDuration(uint256 vestedDuration_) external onlyOwner {
        vestedDuration = vestedDuration_;
    }

    function __setHardcap(uint256 hardcap_) external onlyOwner {
        hardcap = hardcap_;
    }

    function __setTokens(IERC20 paymentToken_, IERC20 presaleToken_)
    external
    onlyOwner {
        paymentToken = paymentToken_;
        presaleToken = presaleToken_;
    }

    function __setReceiver(address receiver_) external onlyOwner {
        receiver = receiver_;
    }
    // END: admin
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Greeter is Ownable {
    using SafeMath for uint256;

    // distributed token
    IERC20 private presaleToken;
    // payment token
    IERC20 private paymentToken;
    // numerator
    uint256 private num;
    // numerator
    uint256 private den;
    // deadline for applying to the presales
    uint256 private deadline;
    // refund trigger bool
    bool private isRFEnabled;
    // keep ownership on opening claim token
    bool private isClaimOpened;

    struct User {
        uint256 allocAmount;
        uint256 paidAmount;
        bool isWL;
    }
    // allocation mapping per address
    mapping(address=>User) private users;

    constructor(
        IERC20 presaleToken_,
        IERC20 paymentToken_,
        uint256 deadline_,
        uint256 num_,
        uint256 den_) {
        presaleToken = presaleToken_;
        paymentToken = paymentToken_;
        deadline = deadline_;
        num = num_;
        den = den_;
        isClaimOpened = true;
    }

    function participate(uint256 amount_) external {
        require(block.timestamp < deadline, "Presale is closed.");
        require(amount_ > 0, "The minimum amount must be greater than 0.");
        require(users[msg.sender].isWL, "User is not whitelisted.");
        require(users[msg.sender].allocAmount >= amount_, "User has not enough allocation.");
        require(users[msg.sender].paidAmount > 0, "User has not enougth allocation.");
        require(users[msg.sender].allocAmount > users[msg.sender].paidAmount.add(amount_), "You exceeded the authorized amount");
        paymentToken.transferFrom(msg.sender, address(this), amount_);
        users[msg.sender].paidAmount  += amount_;
    }

    function claim() external {
        require(users[msg.sender].isWL, "User is not whitelisted.");
        require(block.timestamp >= deadline, "You can not claim your token yet.");
        require(isClaimOpened, "Claim is not open yet.");
        uint256 tokenAmount = users[msg.sender].paidAmount.mul(num).div(den);
        presaleToken.approve(address(this), tokenAmount);
        presaleToken.transferFrom(address(this), msg.sender, tokenAmount);
        users[msg.sender].isWL = false;
    }

    function refund() external {
        require(isRFEnabled, "Refund is not enabled yet.");
        require(users[msg.sender].isWL, "User is not whitelisted.");
        require(users[msg.sender].paidAmount > 0, "The minimum amount must be greater than 0.");
        paymentToken.approve(address(this),users[msg.sender].paidAmount);
        paymentToken.transferFrom(address(this), msg.sender,users[msg.sender].paidAmount);
        users[msg.sender] = User(0,0,false);
    }

    // START: view functions
    function getPresaleToken_() external view returns(IERC20) {
        return presaleToken;
    }
    // END: view functions

    // START: admin
    /**
     * Updates the allocation of an address
     * @param address_ Address of the user who will receive the allocation
     * @param amount_ Amount of the allocation
     */
    function __updateWLAllocation(address address_, uint256 amount_, bool isWL_) external onlyOwner {
        users[address_] = User(amount_, 0, isWL_);
    }

    function __addWLs(address[] memory addresses_, uint256 amount_) external onlyOwner {
        for(uint256 i=0;i<addresses_.length;i++){
            users[addresses_[i]] = User(amount_, 0, true);
        }
    }

    function __setEnabledRefund(bool isRFEnabled_) external onlyOwner {
        isRFEnabled = isRFEnabled_;
    }
    
    function __setDeadline(uint256 deadline_) external onlyOwner {
        deadline = deadline_;
    }
    
    function __setIsClaimOpened(bool isClaimOpened_) external onlyOwner {
        isClaimOpened = isClaimOpened_;
    }
    // END: admin
}

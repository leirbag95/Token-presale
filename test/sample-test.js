const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Presales", function () {

  let paymentToken;
  let presaleToken;
  
  // We get const for deploying main contract
  let priNum;
  let priDen;
  let pubNum;
  let pubDen;
  let vestedDuration;
  let MAX_WALLET;

  let presales;
  let owner;
  let accounts;

  beforeEach(async function () {
    const Presales = await ethers.getContractFactory("Presales");
    const PaymentERC20 = await ethers.getContractFactory("ERC20Test");
    const PresaleERC20 = await ethers.getContractFactory("ERC20Test");
    paymentToken = await PaymentERC20.deploy("100000000000000000000000000000000000000000000000000", "Dai", "DAI");
    presaleToken = await PresaleERC20.deploy("100000000000000000000000000000000000000000000000000", "YourToken", "YT");

    await paymentToken.deployed();
    await presaleToken.deployed();

    // We get const for deploying main contract
    priNum = "225"
    priDen = "100"
    pubNum = "250"
    pubDen = "100"
    vestedDuration = String(86400 * 2)
    MAX_WALLET = "2500000000000000000000";

    presales = await Presales.deploy(
      presaleToken.address,
      paymentToken.address,
      String(Math.round(Date.now() / 1000) + 86400),
      priNum,
      priDen,
      pubNum,
      pubDen,
      vestedDuration,
      MAX_WALLET
    );
    
    await presales.deployed();

    [owner, ...accounts] = await ethers.getSigners();
    
    await presaleToken.transfer(presales.address, "100000000000000000000000");
    await paymentToken.transfer(accounts[1].address, "500000000000000000000");
    await paymentToken.transfer(accounts[2].address, "1000000000000000000000");
  })

  it("The deadline must be greater than the current date.", async function () {
    expect(await presales.getPresaleDeadline()).to.gt((Math.round(Date.now() / 1000)))
  })
  it("Add some addresses to the WL array.", async function () {
    await presales.__addWLs([accounts[1].address], "500000000000000000000")

    let user1 = (await presales.getUser(accounts[1].address))
    let user2 = (await presales.getUser(accounts[2].address))
    
    expect(user1.allocAmount).to.equal("500000000000000000000");

    expect(user1.isWL).to.equal(true)
    expect(user2.isWL).to.equal(false)
  })
  it("Participate to the presales with WL account", async function () {
    
    await presales.__addWLs([accounts[1].address], "500000000000000000000")
    let presalesContractAsAccount1 = presales.connect(accounts[1])
    let paymentTokenAsAccount1 = paymentToken.connect(accounts[1])
    
    await expect(presalesContractAsAccount1.privateSale("5000000000000000000000")).to.be.revertedWith("You exceeded the authorized amount")

    await paymentTokenAsAccount1.approve(presales.address, "5000000000000000000000")
    let amount = 500000000000000000000

    await presalesContractAsAccount1.privateSale(String(amount))
    let paidAmount = (await presales.getUser(accounts[1].address)).paidAmount

    await expect(paidAmount).to.equal(String(amount))
  })
});

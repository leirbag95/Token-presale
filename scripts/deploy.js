// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Presales = await hre.ethers.getContractFactory("Presales");
  const PaymentERC20 = await hre.ethers.getContractFactory("ERC20Test");
  const PresaleERC20 = await hre.ethers.getContractFactory("ERC20Test");
  const paymentToken = await PaymentERC20.deploy("100000000000000000000000000000000000000000000000000", "Dai", "DAI");
  const presaleToken = await PresaleERC20.deploy("100000000000000000000000000000000000000000000000000", "YourToken", "YT");
  console.log(paymentToken.address)
  console.log(presaleToken.address)
  // We get const for deploying main contract
  const priNum = "225"
  const priDen = "100"
  const pubNum = "250"
  const pubDen = "100"
  const vestedDuration = String(86400 * 2)
  const MAX_WALLET = "2500000000000000000000";

  const presales = await Presales.deploy(
    presaleToken.address,
    paymentToken.address,
    String(Date.now()+86400),
    priNum,
    priDen,
    pubNum,
    pubDen,
    vestedDuration,
    MAX_WALLET
  );

  await presales.deployed();

  console.log("Presales deployed to:", presales.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

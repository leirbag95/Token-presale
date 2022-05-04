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
  const Token1 = "YOUR TOKEN"
  const Token2 = "YOUR TOKEN"

  // We get const for deploying main contract
  const num = "2250"
  const den = "1000"
  const presaleDuration = 86400
  const vestedDuration = String(604800)
  const hardcap = "500000000000000000000000"
  const MAX_WALLET = "1000000000000000000000";

  const presales = await Presales.deploy(
    Token1,
    Token2,
    String(Math.round(Date.now() / 1000) + presaleDuration),
    num,
    den,
    vestedDuration,
    hardcap,
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

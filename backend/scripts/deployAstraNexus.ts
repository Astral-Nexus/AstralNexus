import hre from "hardhat";
import "@nomicfoundation/hardhat-ethers";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy AstralNexusToken (Initial supply of 1,000,000,000 tokens)
  console.log("Deploying AstralNexusToken...");
  const AstralNexusToken = await hre.ethers.getContractFactory("AstralNexusToken");
  const token = await AstralNexusToken.deploy(1000000000); // Replace with your initial supply
  await token.waitForDeployment();
  console.log("AstralNexusToken deployed to:", token.target);

  // Deploy AstralNexusItems
  console.log("Deploying AstralNexusItems...");
  const AstralNexusItems = await hre.ethers.getContractFactory("AstralNexusItems");
  const items = await AstralNexusItems.deploy();
  await items.waitForDeployment();
  console.log("AstralNexusItems deployed to:", items.target);

  // Deploy AstralNexusCharacter
  console.log("Deploying AstralNexusCharacter...");
  const AstralNexusCharacter = await hre.ethers.getContractFactory("AstralNexusCharacter");
  const character = await AstralNexusCharacter.deploy();
  await character.waitForDeployment();
  console.log("AstralNexusCharacter deployed to:", character.target);

  // Deploy AstralNexusExchange
  console.log("Deploying AstralNexusExchange...");
  const AstralNexusExchange = await hre.ethers.getContractFactory("AstralNexusExchange");
  const exchange = await AstralNexusExchange.deploy(
    token.target,                 // Address of AstralNexusToken
    "0x51eF9Ae8f376A39A8fd18D96888c7Dc05C703747",      // Replace with EDU token address
    1000,                         // Game-to-EDU conversion rate
    100                           // EDU-to-Game conversion rate
  );
  await exchange.waitForDeployment();
  console.log("AstralNexusExchange deployed to:", exchange.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

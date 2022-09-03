const hre = require("hardhat");
const fs = require('fs');

async function main() {

  const CoinToss = await ethers.getContractFactory("CoinToss");
  const coinTossContract = await CoinToss.deploy();

  fs.writeFileSync('./config.js', `
  export const coinTossContractAddress = "${coinTossContract.address}"`)

  console.log("CoinToss deployed to:", coinTossContract.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
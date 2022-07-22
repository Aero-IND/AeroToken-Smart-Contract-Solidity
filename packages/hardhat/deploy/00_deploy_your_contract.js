// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");
const hre = require("hardhat");
require("hardhat-ethernal");

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy("AeroToken", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [
      "0x0C18c23BA67d0324564a2Bedf0cd7200b3406BA3",
      "0x0C18c23BA67d0324564a2Bedf0cd7200b3406BA3",
    ],
    log: true,
    waitConfirmations: 5,
  });

  // Getting a previously deployed contract
  const AeroToken = await ethers.getContract("AeroToken", deployer);

  // Sync Artefacts with https://app.tryethernal.com/
  await hre.ethernal.push({
    name: "AeroToken",
    address: AeroToken.address,
  });
  /*  await AeroToken.setPurpose("Hello");
  
    // To take ownership of AeroToken using the ownable library uncomment next line and add the 
    // address you want to be the owner. 
    
    await AeroToken.transferOwnership(
      "ADDRESS_HERE"
    );

    //const AeroToken = await ethers.getContractAt('AeroToken', "0xaAC799eC2d00C013f1F11c37E654e59B0429DF6A") //<-- if you want to instantiate a version of a contract at a specific address!
  */

  /*
  //If you want to send value to an address from the deployer
  const deployerWallet = ethers.provider.getSigner()
  await deployerWallet.sendTransaction({
    to: "0x34aA3F359A9D614239015126635CE7732c18fDF3",
    value: ethers.utils.parseEther("0.001")
  })
  */

  /*
  //If you want to send some ETH to a contract on deploy (make your constructor payable!)
  const AeroToken = await deploy("AeroToken", [], {
  value: ethers.utils.parseEther("0.05")
  });
  */

  /*
  //If you want to link a library into your contract:
  // reference: https://github.com/austintgriffith/scaffold-eth/blob/using-libraries-example/packages/hardhat/scripts/deploy.js#L19
  const AeroToken = await deploy("AeroToken", [], {}, {
   LibraryName: **LibraryAddress**
  });
  */

  // Verify from the command line by running `yarn verify`

  // You can also Verify your contracts with Etherscan here...
  // You don't want to verify on localhost
  // try {
  //   if (chainId !== localChainId) {
  //     await run("verify:verify", {
  //       address: AeroToken.address,
  //       contract: "contracts/AeroToken.sol:AeroToken",
  //       constructorArguments: [],
  //     });
  //   }
  // } catch (error) {
  //   console.error(error);
  // }
};
module.exports.tags = ["AeroToken"];

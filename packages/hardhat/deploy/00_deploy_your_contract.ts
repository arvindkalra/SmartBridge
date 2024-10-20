import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys a contract named "SmartBridge" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deploySmartBridge: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network sepolia`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("SmartBridge", {
    from: deployer,
    // Contract constructor arguments
    // args: ["0x9E12AD42c4E4d2acFBADE01a96446e48e6764B98", "0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff"], // For Morph HoleSky
    args: ["0x9aA40Cc99973d8407a2AE7B2237d26E615EcaFd2", "0x6EDCE65403992e310A62460808c4b910D972f10f"], // For Arbitrum Sepolia
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });

  // Get the deployed contract to interact with it after deploying.
  // const SmartBridge = await hre.ethers.getContract<Contract>("SmartBridge", deployer);
  // console.log("👋 Initial greeting:", await SmartBridge.greeting());
};

export default deploySmartBridge;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags SmartBridge
deploySmartBridge.tags = ["SmartBridge"];

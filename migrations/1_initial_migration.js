const config = require("../config.json");
const upgrade = require("@openzeppelin/truffle-upgrades");
const { dsConfigWrite } = require("../ds-lib/ds-config");

async function deployGldmNft(deployer) {
  const gldmNFT = artifacts.require("GoldMintNFT");
  console.log("[NFT] deploying ...");
  const contract = await upgrade.deployProxy(
    gldmNFT, 
    [
      "GolMint NFT",
      "GNFT",
      "ipfs://bafybeiflyp3kisaiwebgc52m5brucvu62cqzuaxfgxyzxckcsamelvcoya/",
      10,
      "0x27e0C3c11F2184C323d8c16129b3A26CC5c7b382"
    ], 
    {deployer, initializer: "initialize"});
  console.log("admin = ", await upgrade.erc1967.getAdminAddress(contract.address));
  console.log("implementation = ", await upgrade.erc1967.getImplementationAddress(contract.address));
  console.log("proxy = ", contract.address);
  return contract.address;
}

module.exports = async function (deployer, network) {
  console.log(`migrating on ${network}`);
  let targetNet = config.networks[network];
  targetNet.GLDM_NFT = await deployGldmNft(deployer);
  config.networks[network] = targetNet;
  dsConfigWrite(config, "../config.json");
};

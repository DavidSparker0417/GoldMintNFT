let config = require("../config.json");
const argv = require("minimist")(process.argv.slice(2), {string:["old-addr"]});
const upgrade = require("@openzeppelin/truffle-upgrades");
const { dsConfigWrite } = require("../ds-lib/ds-config");

module.exports = async function (deployer, network) {
  let oldAddr = argv["old-addr"];
  const gldmNft = artifacts.require("GoldMintNFT");
  oldAddr = (await gldmNft.deployed()).address;
  let impl = await upgrade.erc1967.getImplementationAddress(oldAddr);
  console.log(`Upgrading proxy : ${oldAddr}, impl: ${impl} ...`);
  
  const contract = await upgrade.upgradeProxy(
    oldAddr, 
    gldmNft, 
    {
      deployer,
      // call: {
      //   fn: "init",
      //   args: [
      //     "0x27e0C3c11F2184C323d8c16129b3A26CC5c7b382",
      //     "https://api.mybae.io/tokens/",
      //     10,
      //   ]
      // }
    }
  );

  console.log("new implementation = ",
    await upgrade.erc1967.getImplementationAddress(contract.address))
  config.networks[network].gldmNft = contract.address;
  dsConfigWrite(config, "./config.json");
}
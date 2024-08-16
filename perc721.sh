#!/bin/bash

print_blue() {
    echo -e "\033[34m$1\033[0m"
}

print_red() {
    echo -e "\033[31m$1\033[0m"
}

print_green() {
    echo -e "\033[32m$1\033[0m"
}

print_pink() {
    echo -e "\033[95m$1\033[0m"
}

prompt_for_input() {
    read -p "$1" input
    echo $input
}

echo "Installing dependencies..."
npm install --save-dev hardhat
npm install dotenv
npm install @swisstronik/utils
npm install @openzeppelin/contracts
echo "Installation completed."

print_blue "Installing Hardhat and necessary dependencies..."
echo
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
echo

print_blue "Removing default package.json file..."
echo
rm package.json
echo

print_blue "Creating package.json file again..."
echo
cat <<EOL > package.json
{
  "name": "hardhat-project",
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^3.0.0",
    "hardhat": "^2.17.1"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@swisstronik/utils": "^1.2.1"
  }
}
EOL

print_blue "Initializing Hardhat project..."
npx hardhat
echo
print_blue "Removing the default Hardhat configuration file..."
echo
rm hardhat.config.js
echo
read -p "Enter your wallet private key: " PRIVATE_KEY

if [[ $PRIVATE_KEY != 0x* ]]; then
  PRIVATE_KEY="0x$PRIVATE_KEY"
fi

cat <<EOL > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/",
      accounts: ["$PRIVATE_KEY"],
    },
  },
};
EOL

print_blue "Hardhat configuration file has been updated."
echo

rm -f contracts/Lock.sol
sleep 2

echo
print_pink "Enter NFT NAME:"
read -p "" NFT_NAME
echo
print_pink "Enter NFT SYMBOL:"
read -p "" NFT_SYMBOL
echo
cat <<EOL > contracts/NFT.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrivateNFT is ERC721, ERC721Burnable, Ownable {
    constructor(address initialOwner)
        ERC721("$NFT_NAME","$NFT_SYMBOL")
        Ownable(initialOwner)
    {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return super.balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = super.ownerOf(tokenId);
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return owner;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = super.ownerOf(tokenId);
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return super.tokenURI(tokenId);
    }
}
EOL
echo "PrivateNFT.sol contract created."

echo "Compiling the contract..."
npx hardhat compile
echo "Contract compiled."

echo "Creating deploy.js script..."
mkdir -p scripts
cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PrivateNFT");
  const contract = await contractFactory.deploy(deployer.address);
  await contract.waitForDeployment();
  const deployedContract = await contract.getAddress();
  fs.writeFileSync("contract.txt", deployedContract);
  console.log(\`Contract deployed to \${deployedContract}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "deploy.js script created."

echo "Deploying the contract..."
npx hardhat run scripts/deploy.js --network swisstronik
echo "Contract deployed."

echo "Creating mint.js script..."
cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PrivateNFT");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "safeMint";
  const safeMintTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, [signer.address, 1]),
    0
  );
  await safeMintTx.wait();
  console.log("Transaction Receipt: ", \`Minting NFT has been success! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${safeMintTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "mint.js script created."

echo "Minting NFT..."
npx hardhat run scripts/mint.js --network swisstronik
echo "NFT minted."

echo
print_green "Copy the above Tx URL and save it somewhere, you need to submit it on Testnet page"
echo
sed -i 's/0x[0-9a-fA-F]*,\?\s*//g' hardhat.config.js
echo
print_blue "PRIVATE_KEY has been removed from hardhat.config.js."
echo
print_blue "Pushing these files to your github Repo link"
git add . && git commit -m "Initial commit" && git push origin main
echo

echo -e ' ##   ##   ######  #####    #####    #######  ##    ## '
echo -e ' ##   ##     ##    ##  ##   ##  ##   ##       ###   ## '
echo -e ' ##   ##     ##    ##   ##  ##   ##  ##       ## #  ## '
echo -e ' #######     ##    ##   ##  ##   ##  #####    ##  # ## '
echo -e ' ##   ##     ##    ##   ##  ##   ##  ##       ##   ### '
echo -e ' ##   ##     ##    ##  ##   ##  ##   ##       ##    ## '
echo -e ' ##   ##   ######  #####    #####    #######  ##    ## '
                                                      
echo -e '        #####     #######  ##     ## '
echo -e '       ##   ##    ##       ###   ### ' 
echo -e '       ##         ##       ## # # ## '  
echo -e '       ##  #####  #####    ##  #  ## '  
echo -e '       ##   ## #  ##       ##     ## '  
echo -e '       ##   ## #  ##       ##     ## '  
echo -e '        #####     #######  ##     ## '

echo -e ' Wellcome To Hidden Gem Node Running Installation Guide '

echo -e '\e[0m'

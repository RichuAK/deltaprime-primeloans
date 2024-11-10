const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');

async function main() {
    // Replace 'YourContract' with the name of your contract
    const contractSubPath = 'facets';
    const contractName = 'OwnershipFacet';

    // Construct the path to the contract artifact
    const artifactPath = path.join(
        __dirname,
        `../../artifacts/contracts/${contractSubPath}/${contractName}.sol/${contractName}.json`
    );

    // Read and parse the contract artifact
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    const abi = artifact.abi;

    // Create an Interface instance from the ABI
    const iface = new ethers.utils.Interface(abi);

    // Iterate over each function in the ABI
    for (const func of Object.values(iface.functions)) {
        // Get the function selector
        const selector = iface.getSighash(func);

        // Log the function signature and its selector
        console.log(`${func.format()} : ${selector}`);
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});

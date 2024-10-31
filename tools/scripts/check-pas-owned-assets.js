const ethers = require("ethers");

const jsonRPC = {
    "avalanche": "https://api.avax.network/ext/bc/C/rpc",
    "arbitrum": "https://arb1.arbitrum.io/rpc"
};

const factoryAddress = {
    "avalanche": "0x3Ea9D480295A73fd2aF95b4D96c2afF88b21B03D",
    "arbitrum": "0xFf5e3dDaefF411a1dC6CcE00014e4Bca39265c20"
};

const DiamondLoupeAbi = [
    'function getAllLoans() external view returns (address[] memory)',
];

const OwnedAssetsAbi = [
    {
        "inputs": [],
        "name": "getAllOwnedAssets",
        "outputs": [
            {
                "internalType": "bytes32[]",
                "name": "result",
                "type": "bytes32[]"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
];

async function main(chain = "avalanche") {
    const provider = new ethers.providers.JsonRpcProvider(jsonRPC[chain]);
    const factory = new ethers.Contract(factoryAddress[chain], DiamondLoupeAbi, provider);

    const loanAddresses = await factory.getAllLoans();
    console.log(`Total loan addresses fetched: ${loanAddresses.length}`);

    const batchSize = 100; // You can change this value as needed

    const assetNamesLookup = ["arbSnrLLP", "arbMzeLLP", "arbJnrLLP", "LVL"]; // Replace with the asset names you're looking for

    const findings = [];

    // Process in batches
    for (let i = 0; i < loanAddresses.length; i += batchSize) {
        const batch = loanAddresses.slice(i, i + batchSize);
        console.log(`Processing batch ${i / batchSize + 1}: addresses ${i} to ${i + batch.length - 1}`);

        const batchPromises = batch.map(async (address) => {
            try {
                const primeAccountContract = new ethers.Contract(address, OwnedAssetsAbi, provider);
                const ownedAssetsBytes32 = await primeAccountContract.getAllOwnedAssets();

                // Convert bytes32[] to string[]
                const ownedAssets = ownedAssetsBytes32.map(assetBytes32 => ethers.utils.parseBytes32String(assetBytes32));

                const matchingAssets = ownedAssets.filter(assetName => assetNamesLookup.includes(assetName));

                if (matchingAssets.length > 0) {
                    return {
                        loanAddress: address,
                        matchingAssets: matchingAssets
                    };
                } else {
                    return null;
                }
            } catch (error) {
                console.error(`Error processing loan address ${address}:`, error);
                return null;
            }
        });

        const results = await Promise.all(batchPromises);

        findings.push(...results.filter((result) => result !== null));
    }

    console.log("Findings:");
    console.dir(findings, { depth: null });
}

// Run the script with the desired chain
main("arbitrum");

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

const PASStakingAbi = [
    {
        "inputs": [],
        "name": "getStakedPositions",
        "outputs": [
            {
                "components": [
                    {
                        "internalType": "address",
                        "name": "asset",
                        "type": "address"
                    },
                    {
                        "internalType": "bytes32",
                        "name": "symbol",
                        "type": "bytes32"
                    },
                    {
                        "internalType": "bytes32",
                        "name": "identifier",
                        "type": "bytes32"
                    },
                    {
                        "internalType": "bytes4",
                        "name": "balanceSelector",
                        "type": "bytes4"
                    },
                    {
                        "internalType": "bytes4",
                        "name": "unstakeSelector",
                        "type": "bytes4"
                    }
                ],
                "internalType": "struct IStakingPositions.StakedPosition[]",
                "name": "_positions",
                "type": "tuple[]"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
];

async function main(chain = "avalanche") {
    const provider = new ethers.providers.JsonRpcProvider(jsonRPC[chain]);
    const factory = new ethers.Contract(factoryAddress[chain], DiamondLoupeAbi, provider);

    const loanAddresses = await factory.getAllLoans();
    console.log(`Total loan addresses fetched: ${loanAddresses.length}`);

    const batchSize = 50; // You can change this value as needed

    const stakedPositionSymbolLookup = ["arbSnrLLP", "arbMzeLLP", "arbJnrLLP", "LVL"]; // Replace with the symbol you're looking for

    const findings = [];

    // Process in batches
    for (let i = 0; i < loanAddresses.length; i += batchSize) {
        const batch = loanAddresses.slice(i, i + batchSize);
        console.log(`Processing batch ${i / batchSize + 1}: addresses ${i} to ${i + batch.length - 1}`);

        const batchPromises = batch.map(async (address) => {
            try {
                const primeAccountContract = new ethers.Contract(address, PASStakingAbi, provider);
                const stakedPositions = await primeAccountContract.getStakedPositions();

                const matchingPositions = stakedPositions.filter((position) => {
                    const symbol = ethers.utils.parseBytes32String(position.symbol);
                    return stakedPositionSymbolLookup.includes(symbol);
                });

                if (matchingPositions.length > 0) {
                    return {
                        loanAddress: address,
                        matchingPositions: matchingPositions.map((position) => ({
                            asset: position.asset,
                            symbol: ethers.utils.parseBytes32String(position.symbol),
                            identifier: ethers.utils.parseBytes32String(position.identifier),
                            balanceSelector: position.balanceSelector,
                            unstakeSelector: position.unstakeSelector,
                        })),
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

const { ethers } = require('ethers');
const fs = require('fs');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

// ABI for the Diamond Loupe interface
const DIAMOND_LOUPE_ABI = [
    "function facets() external view returns (tuple(address facetAddress, bytes4[] functionSelectors)[])",
    "function facetFunctionSelectors(address _facet) external view returns (bytes4[])",
    "function facetAddresses() external view returns (address[])",
    "function facetAddress(bytes4 _functionSelector) external view returns (address)"
];

// Configuration
const config = {
    avalanche: {
        rpc: "https://api.avax.network/ext/bc/C/rpc",
        diamondAddress: "0x2916B3bf7C35bd21e63D01C93C62FB0d4994e56D",
        blockNumber: "52928212" // Can be "latest" or a specific number
    },
    arbitrum: {
        rpc: "https://arb.nirvanalabs.xyz/arbitrum_aws?apikey=284d7cde-5c20-46a9-abee-2e3932cdb771",
        diamondAddress: "0x62Cf82FB0484aF382714cD09296260edc1DC0c6c",
        blockNumber: "273282892" // Can be "latest" or a specific number
    }
};


// Generate timestamp
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

// Create CSV writers for each chain
function createChainCsvWriter(chainName) {
    const filename = `diamond_facets_${chainName}_${timestamp}.csv`;
    return {
        writer: createCsvWriter({
            path: filename,
            header: [
                {id: 'selector', title: 'SELECTOR'},
                {id: 'facetAddress', title: 'FACET ADDRESS'},
                {id: 'blockNumber', title: 'BLOCK NUMBER'},
                {id: 'facetName', title: 'FACET NAME'},
                {id: 'methodName', title: 'METHOD NAME'}
            ]
        }),
        filename: filename
    };
}

async function getBlockNumber(provider, requestedBlock) {
    if (requestedBlock === "latest") {
        return await provider.getBlockNumber();
    }
    return parseInt(requestedBlock);
}

async function scanDiamond(chainName, rpcUrl, diamondAddress, requestedBlock) {
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const blockNumber = await getBlockNumber(provider, requestedBlock);

    // Create contract instance with override for specific block
    const diamond = new ethers.Contract(diamondAddress, DIAMOND_LOUPE_ABI, provider);
    const records = [];

    try {
        // Get all facets at specific block
        const facets = await diamond.facets({ blockTag: blockNumber });

        for (const facet of facets) {
            const facetAddress = facet.facetAddress;
            const selectors = facet.functionSelectors;

            // Add each selector to records
            for (const selector of selectors) {
                records.push({
                    selector: selector,
                    facetAddress: facetAddress,
                    blockNumber: blockNumber,
                    facetName: 'TBD', // Placeholder
                    methodName: 'TBD'  // Placeholder
                });
            }
        }

        console.log(`Successfully scanned ${chainName} at block ${blockNumber}`);
        return records;
    } catch (error) {
        console.error(`Error scanning ${chainName} at block ${blockNumber}:`, error);
        return [];
    }
}

async function processChain(chainName, chainConfig) {
    const csvHandler = createChainCsvWriter(chainName);

    const records = await scanDiamond(
        chainName,
        chainConfig.rpc,
        chainConfig.diamondAddress,
        chainConfig.blockNumber
    );

    if (records.length > 0) {
        await csvHandler.writer.writeRecords(records);
        console.log(`CSV file "${csvHandler.filename}" has been written successfully with ${records.length} records`);
    } else {
        console.log(`No records found for ${chainName}`);
    }

    return records.length;
}

async function main() {
    try {
        // Process each chain independently
        const results = await Promise.all([
            processChain('avalanche', config.avalanche),
            processChain('arbitrum', config.arbitrum)
        ]);

        console.log('\nSummary:');
        console.log(`Avalanche facets processed: ${results[0]}`);
        console.log(`Arbitrum facets processed: ${results[1]}`);
        console.log(`Total facets processed: ${results[0] + results[1]}`);

    } catch (error) {
        console.error('Error in main execution:', error);
    }
}

// Check if block numbers are provided as command line arguments
if (process.argv.length > 2) {
    const avalancheBlock = process.argv[2];
    const arbitrumBlock = process.argv[3] || "latest";

    config.avalanche.blockNumber = avalancheBlock;
    config.arbitrum.blockNumber = arbitrumBlock;
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
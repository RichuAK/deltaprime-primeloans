const jsonRPC = {
    "avalanche": "https://api.avax.network/ext/bc/C/rpc",
    "arbitrum": "https://arb1.arbitrum.io/rpc"
}

const ethers = require("ethers");
const diamondAddress = {
    "avalanche": "0x2916B3bf7C35bd21e63D01C93C62FB0d4994e56D",
    "arbitrum": "0x62Cf82FB0484aF382714cD09296260edc1DC0c6c"
}
const DiamondLoupeAbi = [
    'function facetAddress(bytes4 _functionSelector) external view returns (address)',
    'function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_)',
]


function selectorsAreUnique(selectors) {
    let uniqueSelectors = new Set(selectors);
    return uniqueSelectors.size === selectors.length;
}

async function main(chain = "avalanche") {
    let activeSelectors = []
    let inactiveSelectors = []
    let provider = new ethers.providers.JsonRpcProvider(jsonRPC[chain]);
    let facetsContainingSelectors = [];
    let allSelectorsFromRelevantFacets = new Set();
    let diamondLoupeContract = new ethers.Contract(diamondAddress[chain], DiamondLoupeAbi, provider);
    let selectorsToCheck = [
        "0x79ba5097"
    ]

    if (!selectorsAreUnique(selectorsToCheck)) {
        throw new Error("Selectors must be unique");
    }

    console.log(`Checking selectors (${selectorsToCheck}) for Diamond contract at address: ${diamondAddress[chain]}`);

    for(const selector of selectorsToCheck) {
        let facetAddress = await diamondLoupeContract.facetAddress(selector);
        console.log(`Selector: ${selector} - Facet Address: ${facetAddress}`);

        if (facetAddress === ethers.constants.AddressZero) {
            inactiveSelectors.push(selector);
        } else {
            activeSelectors.push(selector);
            if(!facetsContainingSelectors.includes(facetAddress)) {
                facetsContainingSelectors.push(facetAddress);
            }
        }
    }

    for(const facet of facetsContainingSelectors) {
        console.log(`Additionally checking selectors for facet at address: ${facet}`);
        let diamondLoupeContract = new ethers.Contract(diamondAddress[chain], DiamondLoupeAbi, provider);
        let facetSelectors = await diamondLoupeContract.facetFunctionSelectors(facet);
        for(const selector of facetSelectors) {
            allSelectorsFromRelevantFacets.add(selector);
        }
    }

    console.log(`Active Selectors (${activeSelectors.length}): ${activeSelectors}`);
    console.log(`Inactive Selectors (${inactiveSelectors.length}): ${inactiveSelectors}`);

    // selectors in allSelectorsFromRelevantFacets that are not in selectorsToCheck
    let missingSelectors = Array.from(allSelectorsFromRelevantFacets).filter(x => !selectorsToCheck.includes(x));
    console.log(`Missing Selectors (${missingSelectors.length}): ${missingSelectors}`);
}
main("avalanche");

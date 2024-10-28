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
]


function selectorsAreUnique(selectors) {
    let uniqueSelectors = new Set(selectors);
    return uniqueSelectors.size === selectors.length;
}

async function main(chain = "avalanche") {
    let activeSelectors = []
    let inactiveSelectors = []
    let provider = new ethers.providers.JsonRpcProvider(jsonRPC[chain]);
    let diamondLoupeContract = new ethers.Contract(diamondAddress[chain], DiamondLoupeAbi, provider);
    let selectorsToCheck = [
        "0x571a6ade",
        "0x1c0de81a",
        "0x22f071b7",
        "0x58d48fbc",
        "0xa4f2e3ef",
        "0x27123874",
        "0x2ae387cb",
        "0x12ae43b3",
        "0xd5fe1426",
        "0x76695ca9",
        "0x4f5a254a",
        "0xc1313fcb",
        "0x3abaf890",
        "0x48c2851d",
        "0x116bb1cb",
        "0x3436f6b8",
        "0xfdc520c5",
        "0x3ddfb065",
        "0xe5cda91a",
        "0xe42454e7",
        "0x778c13bc",
        "0x7f7cc4ae",
        "0xe4a4e63b",
        "0x828e8d8d",
        "0x7e94ea73",
        "0x18c9991c",
        "0xf0094cdc",
        "0xf4d054b4",
        "0x974d510b",
        "0x57126d0d",
        "0x14604744",
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
        }
    }

    console.log(`Active Selectors (${activeSelectors.length}): ${activeSelectors}`);
    console.log(`Inactive Selectors (${inactiveSelectors.length}): ${inactiveSelectors}`);
}
main("arbitrum");

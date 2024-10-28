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



async function getPoolHistoricalTVL(poolName, poolAddress, blockNumber){
    const provider = new ethers.providers.JsonRpcProvider(jsonRPC);
    const poolContract = new ethers.Contract(poolAddress, PoolAbi, provider);
    const poolDecimals = await poolContract.decimals();
    let historicalTVL = await poolContract.totalSupply({blockTag: blockNumber});
    historicalTVL = ethers.utils.formatUnits(historicalTVL, poolDecimals);

    return historicalTVL;
}

let tokensWithdrawnAfterExploitPerPool = {
    "BtcPoolTUP": [
        0.00165829,
        0.00052189,
        0.01,
        0.00142474,
        0.001,
        0.002,
        0.0005,

    ],
    "DaiPoolTUP": [0],
    "UsdcPoolTUP": [
        9335.304003,
        21.689466,
        380.492177,
        346.273414,
        10047,
        100,
        500,
        1000,
        1000,
        1310.649946,
        0.011158,
        0.476889,
        581.02563,
        5060.582367,
        1,
        765.294367,
        10,
        10000,
        10000,
        5,
        1000,
        20000,
        5000,
        1000,
        1000,
        3.032029,
        584.850968,
        1000,
        400,
        200,
        100,
        50,
        40,
        1,
        65,
        64,
        63,
        62,
        47
    ],
    "WethPoolTUP": [
        0.01,
        2.1416970338537067,
        1.5605058508524177,
        0.6,
        14.389068010620907,
        0.030351847739811113,
        4.020350579614076,
        7.078472240745223,
        2.2265439833370126,
        2.2567446505922146,
        1.3186797866642066,
        2.613600314085689,
        0.5296755335863058,
        1.7097140004988285,
        1.232730438845738,
        0.9513550152797303,
        0.1581649507779418,
        0.013329417636149978,
        0.21088653926993117,
        0.06382765362998064,
        0.10547723029449034,
        1,
        0.3,
        0.0004,
        0.01,
        0.1,
        0.05,
        0.11,
        0.02,
        0.03,
        0.00199999,
        0.05,
        0.02,
        0.002,
        0.001,
        0.005,
        0.00275924315869511,
    ],
    "ArbPoolTUP": [
        1055.6085165600016,
        643.6630540679483,
        1640,
        643.6726835489847,
        0.1,
        937.0356392551819,
        448.65637736093777,
        236.42229376320952,
        0.000000000000000648,
        400,
        5,
        0.47,
        513.6513971789642,
        862.6459215491665,
        23.072749240848875,
        2430.1747258551122,
        242,
        4.681077945866865,
        939.0312699312071,
        8
    ],
}

function getTotalTokensWithdrawnAfterExploit(poolName){
    let totalTokensWithdrawn = 0;
    for (let i = 0; i < tokensWithdrawnAfterExploitPerPool[poolName].length; i++) {
        totalTokensWithdrawn += tokensWithdrawnAfterExploitPerPool[poolName][i];
    }

    return totalTokensWithdrawn;
}

async function getPoolCurrentTVL(poolName, poolAddress){
    const provider = new ethers.providers.JsonRpcProvider(jsonRPC);
    const poolContract = new ethers.Contract(poolAddress, PoolAbi, provider);
    const poolDecimals = await poolContract.decimals();
    let currentTVL = await poolContract.totalSupply();
    currentTVL = ethers.utils.formatUnits(currentTVL, poolDecimals);

    return currentTVL;
}

function selectorsAreUnique(selectors) {
    let uniqueSelectors = new Set(selectors);
    return uniqueSelectors.size === selectors.length;
}

async function main() {
    let activeSelectors = []
    let inactiveSelectors = []
    let provider = new ethers.providers.JsonRpcProvider(jsonRPC["avalanche"]);
    let diamondLoupeContract = new ethers.Contract(diamondAddress["avalanche"], DiamondLoupeAbi, provider);
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
main();

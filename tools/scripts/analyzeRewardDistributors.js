const {ethers} = require('ethers');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

function getProvider() {
    return new ethers.providers.JsonRpcProvider('https://avax.nirvanalabs.xyz/avalanche_aws/ext/bc/C/rpc?apikey=284d7cde-5c20-46a9-abee-2e3932cdb771');
}

async function getTxs(url) {
    return fetch(url).then((res) => {
        return res.json()
    });
}

function secondsToString(seconds) {
    const days = Math.floor(seconds / 86400);
    seconds = seconds % 86400;
    const hours = Math.floor(seconds / 3600);
    seconds = seconds % 3600;
    const minutes = Math.floor(seconds / 60);
    seconds = seconds % 60;

    let str = `${days} days`;
    if (hours > 0) {
        str += ` ${hours} hours`;
    }
    if (minutes > 0) {
        str += ` ${minutes} minutes`;
    }
    if (seconds > 0) {
        str += ` ${seconds} seconds`;
    }

    return str;
}

async function analyzeRewardDistributor(rewardDistributor, startBlock, rewardTokenSymbol, rewardToken) {
    const provider = getProvider();

    const endBlock = await provider.getBlockNumber();

    const txPerPage = 100;
    let explorerRPC = 'https://api.snowtrace.io';

    let txs = [];
    let page = 1;
    while(true) {
        let url = `${explorerRPC}/api?module=account&action=txlist` +
            `&address=${rewardDistributor}` +
            `&startblock=${startBlock}` +
            `&endblock=${endBlock}` +
            `&page=${page}` +
            `&offset=${txPerPage}` +
            `&sort=asc`

        let apiResult = await getTxs(url);
        let partialResult = apiResult['result'];
        if(apiResult.length === 0){
            break;
        }
        txs.push(...partialResult);
        if(partialResult.length < txPerPage){
            break;
        }
        page += 1;
    }

    let setRewardsDurationTxs = txs.filter(tx => tx['functionName'].includes('setRewardsDuration')).filter(tx => tx['isError'] !== '1')
    console.log(`Found ${setRewardsDurationTxs.length} setRewardsDuration() txs`)

    let notifyRewardAmountTxs = txs.filter(tx => tx['functionName'].includes('notifyRewardAmount')).filter(tx => tx['isError'] !== '1')
    console.log(`Found ${notifyRewardAmountTxs.length} notifyRewardAmount() txs`)

    let events = [];

    setRewardsDurationTxs.map(tx => {
        const [secondsInWei] = new ethers.utils.AbiCoder().decode(['uint256'], '0x' + tx.input.slice(10));
        const seconds = parseFloat(secondsInWei.toString());
        events.push({
            timestamp: parseFloat(tx.timeStamp),
            message: `setRewardsDuration ${seconds} seconds${seconds >= 86400 ? ` (${secondsToString(seconds)})` : ''}`
        })
    })

    let totalNotifyAmount = 0;
    notifyRewardAmountTxs.map(tx => {
        const [rewardInWei] = new ethers.utils.AbiCoder().decode(['uint256'], '0x' + tx.input.slice(10));
        const reward = parseFloat(ethers.utils.formatEther(rewardInWei));
        events.push({
            timestamp: parseFloat(tx.timeStamp),
            message: `notifyRewardsAmounts ${reward} ${rewardTokenSymbol}`
        })
        totalNotifyAmount += reward;
    })

    txs = [];
    page = 1;
    let next;
    while(true) {
        let url = `https://api.routescan.io/v2/network/mainnet/evm/43114/address/${rewardDistributor}/erc20-transfers?ecosystem=avalanche&includedChainIds=43114` +
            `&direction=received` +
            `&limit=${txPerPage}`
        if (next) {
            url += `&next=${next}`;
        }

        let apiResult = await getTxs(url);
        let partialResult = apiResult['items'];
        txs.push(...partialResult);
        next = apiResult['link']['nextToken'];

        if (!next) {
            break;
        }
    }

    const addressMapping = {
        // TODO: add address name mapping here
        '0x18c244c62372df1b933cd455769f9b4ddb820f0c': 'DeltaPrime',
        '0x6cafe2f3a293736dc13a08a03a272d1dd36affd1': 'Avalanche',
    };

    console.log(`Fund txs:`)
    console.log(txs.map(el => el.txHash));

    const rewardTokenReceiveTxs = txs.filter(tx => tx.tokenAddress.toLowerCase() === rewardToken.toLowerCase());
    const totalTokensSentPerAddress = {}

    rewardTokenReceiveTxs.map(tx => {
        const from = tx.from.toLowerCase();
        const rewardInWei = ethers.BigNumber.from(tx.amount);
        const reward = parseFloat(ethers.utils.formatEther(rewardInWei));
        events.push({
            timestamp: Math.floor(new Date(tx.timestamp).getTime() / 1000),
            message: `${addressMapping[from] || from} FUND with ${reward} ${rewardTokenSymbol}`
        })
        totalTokensSentPerAddress[addressMapping[from] || from] = (totalTokensSentPerAddress[addressMapping[from] || from] || 0) + reward;
    })

    const totalTokensFunded = Object.values(totalTokensSentPerAddress).reduce((acc, val) => acc + val, 0);

    events = events.sort((e1, e2) => e1.timestamp - e2.timestamp);
    events = events.map(evt => ({
        timestamp: new Date(evt.timestamp * 1000).toLocaleString(),
        message: evt.message
    }))
    console.log('Events', events);
    console.log('Total tokens sent per address', totalTokensSentPerAddress);
    console.log('Total tokens funded', totalTokensFunded);
    console.log(`Unused tokens: ${totalTokensFunded - totalNotifyAmount}`)
    console.log(`Used tokens: ${totalNotifyAmount}`)
}

// OLD ONES
// analyzeRewardDistributor('0x6d149Fcc150A3B097D7647408345898fe9db1ded', 47509821, 'sAVAX', '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE');
// analyzeRewardDistributor('0x3750F8d6Df82699ada6bBd1463C4E91fCf37005D', 47509886, 'sAVAX', '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE');
// analyzeRewardDistributor('0xB913aC229910d705297DEB1c168af3dA1416B227', 47509939, 'ggAVAX', '0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3');
// analyzeRewardDistributor('0x50b0b59f14bA882BD511Fe08d1cdc975807a94A4', 47510076, 'ggAVAX', '0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3');

// NEW ONES
// analyzeRewardDistributor('0x6373122eD8Eda8ECA439415709318DCB6ddC1af3', 47509821, 'sAVAX', '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE'); // AVAX
// analyzeRewardDistributor('0xBC6Ef309f2eC71698eA310D62FF2E0543472D965', 47509886, 'sAVAX', '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE'); // USDT
// analyzeRewardDistributor('0x596f6EFD98daF650CF98A1E62A53AB2a44e7E875', 47509939, 'ggAVAX', '0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3'); // USDC
// analyzeRewardDistributor('0x3FE9BE379eD15962AFAbE01c002B8c433C6Af4ec', 47510076, 'ggAVAX', '0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3'); // BTC
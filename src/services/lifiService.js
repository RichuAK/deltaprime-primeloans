import { Subject } from 'rxjs';
import { LiFi } from "@lifi/sdk";
import { formatUnits, parseUnits } from '@/utils/calculate';
import { ethers } from 'ethers';
import axios from 'axios';
import config from '../config';
import { switchChain } from '../utils/blockchain';

export default class LifiService {
  lifi$ = new Subject();

  emitLifi(lifiData) {
    this.lifi$.next(lifiData);
  }

  observeLifi() {
    return this.lifi$.asObservable();
  }

  cachedBalances = {};

  async setupLifi() {
    const lifiConfig = {
      integrator: "deltaprime"
    }

    const lifi = new LiFi(lifiConfig);

    try {
      const [chains, tokens] = await Promise.all([
        axios.get('https://li.quest/v1/chains'),
        axios.get('https://li.quest/v1/tokens')
      ]);

      this.emitLifi({
        lifi,
        chains: chains.data.chains,
        tokens: tokens.data.tokens
      });
    } catch(error) {
      console.log(`lifi - fetching chains and tokens failed. Error: ${error}`);
    }
  }

  async getTokenBalancesForChainWithRetry(lifi, address, chainId, tokens, depth = 0) {
    try {
      const tokenBalances = await lifi.getTokenBalancesForChains(
        address,
        { [chainId]: tokens }
      );

      if (!Array.from(tokenBalances).every((token) => token.blockNumber)) {
        if (depth > 10) {
          console.warn('Token balance backoff depth exceeded.');
          return undefined;
        }

        await new Promise((resolve) => {
          setTimeout(resolve, 1.5 ** depth * 100);
        });

        return this.getTokenBalancesForChainWithRetry(lifi, address, chainId, tokens, depth + 1);
      }

      return tokenBalances[chainId];;
    }
    catch (error) {
      console.log(`fetching token balances failed. ${chainId}. Error: ${error}`);
    }
  };

  async fetchTokenBalancesForChain(lifi, address, chainId, tokens, refresh = false) {
    // return cached balances data if already exists
    if (!refresh && chainId in this.cachedBalances && this.cachedBalances[chainId].length == tokens.length) {
      return this.cachedBalances[chainId];
    }

    const balances = await this.getTokenBalancesForChainWithRetry(lifi, address, chainId, tokens);
    this.cachedBalances[chainId] = balances;

    return balances;
  }

  async getBestRoute(lifi, routesRequest, assetDecimals) {
    try {
      const fromAmount = routesRequest.fromAmount.toFixed(assetDecimals);
      const request = {
        ...routesRequest,
        fromAmount: parseUnits(fromAmount, assetDecimals).toString()
      };

      const result = await lifi.getRoutes(request);
      console.log(result.routes);

      return result.routes;
    } catch(error) {
      console.log(`lifi - fetching routes failed. Error: ${error}`);
      return;
    }
  }

  async bridgeAndDeposit({ bridgeRequest: {
    lifi,
    chosenRoute,
    depositNativeToken,
    signer,
    depositFunc,
    targetSymbol
  } }) {

    const updateRouteHook = (updatedRoute) => {
      console.log('Route updated', updatedRoute);
    }

    const switchChainHook = async (requiredChainId) => {
      if (!signer) {
        return signer;
      }

      const currentChainId = await signer.getChainId();
  
      if (currentChainId !== requiredChainId) {
        const ethereum = window.ethereum;
        if (typeof ethereum === 'undefined') return;

        await ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: '0x' + requiredChainId.toString(16) }],
        });

        const newProvider = new ethers.providers.Web3Provider(window.ethereum, 'any');

        return newProvider.getSigner();
      }
    }

    const updateGasConfig = async (txRequest) => {
      return txRequest;
    }

    const acceptExchangeRateUpdate = async (params) => {
      return params;
    }

    const route = await lifi.executeRoute(signer, chosenRoute, {
      updateRouteHook,
      switchChainHook,
      updateTransactionRequestHook: updateGasConfig,
      acceptExchangeRateUpdateHook: acceptExchangeRateUpdate
    });
    console.log('bridge completed.');

    if (!route.steps || route.steps.length === 0) {
      console.log("something wrong with bridge.");
      return;
    }

    await switchChain(config.chainId, signer);

    const executionStep = route.steps[0];

    const depositRequest = {
      assetSymbol: targetSymbol,
      amount: formatUnits(executionStep.execution.toAmount, executionStep.execution.toToken.decimals),
      depositNativeToken: depositNativeToken
    };

    console.log(depositRequest);

    await depositFunc({ depositRequest: depositRequest });
  }
}
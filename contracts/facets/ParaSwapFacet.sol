// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: 19d9982858f4feeff1ca98cbf31b07304a79ac7f;
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../ReentrancyGuardKeccak.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {DiamondStorageLib} from "../lib/DiamondStorageLib.sol";
import "../lib/SolvencyMethods.sol";
import "./SmartLoanLiquidationFacet.sol";
import "../interfaces/ITokenManager.sol";

//This path is updated during deployment
import "../lib/local/DeploymentConstants.sol";

import "hardhat/console.sol";

contract ParaSwapFacet is ReentrancyGuardKeccak, SolvencyMethods {
    using TransferHelper for address;

    address private constant PARA_TRANSFER_PROXY = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;
    ///@dev paraSwap v6.2 router
    address private constant PARA_ROUTER = 0x6A000F20005980200259B80c5102003040001068;

    
    ///@notice selectors for paraSwapV2 data decoding
    bytes4 private constant DIRECT_UNI_V3_SELECTOR = 0xa6886da9;
    bytes4 private constant SIMPLESWAP_SELECTOR = 0x54e3f31b;
    bytes4 private constant MULTISWAP_SELECTOR = 0xa94e78ef;

    ///@notice selectors for paraSwapV6 data decoding
    bytes4 private constant SWAP_EXACT_AMOUNT_IN_SELECTOR = 0xe3ead59e;
    
    struct SwapTokensDetails {
        bytes32 tokenSoldSymbol;
        bytes32 tokenBoughtSymbol;
        IERC20Metadata soldToken;
        IERC20Metadata boughtToken;
        uint256 initialSoldTokenBalance;
        uint256 initialBoughtTokenBalance;
    }

    ////////////////////****** PARASWAPV6 STRUCTS *////////////////////


    /*//////////////////////////////////////////////////////////////
                            GENERIC SWAP DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct containg data for generic swapExactAmountIn/swapExactAmountOut
    /// @param srcToken The token to swap from
    /// @param destToken The token to swap to
    /// @param fromAmount The amount of srcToken to swap
    /// = amountIn for swapExactAmountIn and maxAmountIn for swapExactAmountOut
    /// @param toAmount The minimum amount of destToken to receive
    /// = minAmountOut for swapExactAmountIn and amountOut for swapExactAmountOut
    /// @param quotedAmount The quoted expected amount of destToken/srcToken
    /// = quotedAmountOut for swapExactAmountIn and quotedAmountIn for swapExactAmountOut
    /// @param metadata Packed uuid and additional metadata
    /// @param beneficiary The address to send the swapped tokens to
    /// @dev GenericData size: since all elements are lefPadded to 32 bytes, size is 32*7 = 224
    struct GenericData {
        address srcToken;       // changing IERC20 to address for possible ease of decoding
        address destToken;      // changing IERC20 to address for possible ease of decoding
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    /// @notice struct constructed from swapExactAmountIn interface from developer docs
    /// https://developers.paraswap.network/augustus-swapper/augustus-v6.2
    struct SwapExactAmountIn{
        address executor;
        GenericData swapData;
        uint256 partnerAndFee;
        bytes permit;
        bytes executorData;
    }

    
    
    function getInitialTokensDetails(
        address _soldTokenAddress,
        address _boughtTokenAddress
    ) internal view returns (SwapTokensDetails memory) {
        ITokenManager tokenManager = DeploymentConstants.getTokenManager();

        if (_boughtTokenAddress == 0xaE64d55a6f09E4263421737397D1fdFA71896a69) {
            _boughtTokenAddress = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
        }

        if (_soldTokenAddress == 0xaE64d55a6f09E4263421737397D1fdFA71896a69) {
            _soldTokenAddress = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
        }

        bytes32 _tokenSoldSymbol = tokenManager.tokenAddressToSymbol(
            _soldTokenAddress
        );
        bytes32 _tokenBoughtSymbol = tokenManager.tokenAddressToSymbol(
            _boughtTokenAddress
        );

        require(
            tokenManager.isTokenAssetActive(_boughtTokenAddress),
            "Asset not supported."
        );

        IERC20Metadata _soldToken = IERC20Metadata(_soldTokenAddress);
        IERC20Metadata _boughtToken = IERC20Metadata(_boughtTokenAddress);

        return
            SwapTokensDetails({
                tokenSoldSymbol: _tokenSoldSymbol,
                tokenBoughtSymbol: _tokenBoughtSymbol,
                soldToken: _soldToken,
                boughtToken: _boughtToken,
                initialSoldTokenBalance: _soldToken.balanceOf(address(this)),
                initialBoughtTokenBalance: _boughtToken.balanceOf(address(this))
            });
    }

    function paraSwapBeforeLiquidation(
        bytes4 selector,
        bytes memory data,
        address fromToken,
        uint256 fromAmount,
        address toToken,
        uint256 minOut
    )
    external
    nonReentrant
    onlyWhitelistedLiquidators
    noBorrowInTheSameBlock
    {
        require(!_isSolvent(), "Cannot perform on a solvent account");

        SwapTokensDetails memory swapTokensDetails = getInitialTokensDetails(
            fromToken,
            toToken
        );
        require(swapTokensDetails.initialSoldTokenBalance >= fromAmount, "Insufficient balance");
        require(minOut > 0, "minOut needs to be > 0");
        require(fromAmount > 0, "Amount of tokens to sell has to be greater than 0");

        address(swapTokensDetails.soldToken).safeApprove(PARA_TRANSFER_PROXY, 0);
        address(swapTokensDetails.soldToken).safeApprove(
            PARA_TRANSFER_PROXY,
            fromAmount
        );

        (bool success, ) = PARA_ROUTER.call((abi.encodePacked(selector, data)));
        require(success, "Swap failed");

        uint256 boughtTokenFinalAmount = swapTokensDetails.boughtToken.balanceOf(
            address(this)
        ) - swapTokensDetails.initialBoughtTokenBalance;
        require(boughtTokenFinalAmount >= minOut, "Too little received");

        uint256 soldTokenFinalAmount = swapTokensDetails.initialSoldTokenBalance - swapTokensDetails.soldToken.balanceOf(
            address(this)
        );
        require(soldTokenFinalAmount == fromAmount, "Too much sold");

        ITokenManager tokenManager = DeploymentConstants.getTokenManager();
        _decreaseExposure(tokenManager, fromToken, soldTokenFinalAmount);
        _increaseExposure(tokenManager, toToken, boughtTokenFinalAmount);

        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = swapTokensDetails.tokenSoldSymbol;
        symbols[1] = swapTokensDetails.tokenBoughtSymbol;
        uint256[] memory prices = getPrices(symbols);

        uint256 soldTokenDollarValue = prices[0] * soldTokenFinalAmount * 10**10 / 10 ** swapTokensDetails.soldToken.decimals();
        uint256 boughtTokenDollarValue = prices[1] * boughtTokenFinalAmount * 10**10 / 10 ** swapTokensDetails.boughtToken.decimals();
        if(soldTokenDollarValue > boughtTokenDollarValue) {
            // If the sold token is more valuable than the bought token, we need to check the slippage
            // If the slippage is too high, we revert the transaction
            // Slippage = (soldTokenDollarValue - boughtTokenDollarValue) * 100 / soldTokenDollarValue
            uint256 slippage = (soldTokenDollarValue - boughtTokenDollarValue) * 100 / soldTokenDollarValue;
            require(slippage < 2, "Slippage too high"); // MAX 2% slippage
        }
    }

    function paraSwapV2(
        bytes4 selector,
        bytes calldata data,  ///@dev changing data from memory to calldata for slicing
        address fromToken,
        uint256 fromAmount,
        address toToken,
        uint256 minOut
    )
        external
        nonReentrant
        onlyOwner
        noBorrowInTheSameBlock
        remainsSolvent
    {
        SwapTokensDetails memory swapTokensDetails = getInitialTokensDetails(
            fromToken,
            toToken
        );

        require(swapTokensDetails.soldToken.balanceOf(address(this)) >= fromAmount, "Insufficient balance");
        require(minOut > 0, "minOut needs to be > 0");
        require(fromAmount > 0, "Amount of tokens to sell has to be greater than 0");

        console.log("Inside ParaSwapV2 Method");
        bytes memory selectorBytes = abi.encodePacked(selector);
        console.log("Selector: ");
        console.logBytes(selectorBytes);
        
        if(selector == SWAP_EXACT_AMOUNT_IN_SELECTOR){
            console.log("Got SwapExactAmountIn Selector!");
            console.log("Data length: ");
            console.log(data.length);
            // console.log("Data: ");            
            // console.logBytes(data);
            // _decodeGenericData(data);
            _decodeSwapExactAmountInData(data);
        } else {
            console.log("Not My Selector!");
        }

        
        // address(swapTokensDetails.soldToken).safeApprove(PARA_TRANSFER_PROXY, 0);
        // address(swapTokensDetails.soldToken).safeApprove(
        //     PARA_TRANSFER_PROXY,
        //     fromAmount
        // );

        
        
        (bool success, ) = PARA_ROUTER.call((abi.encodePacked(selector, data)));
        require(success, "Swap failed");
        
        

        uint256 boughtTokenFinalAmount = swapTokensDetails.boughtToken.balanceOf(
            address(this)
        ) - swapTokensDetails.initialBoughtTokenBalance;
        require(boughtTokenFinalAmount >= minOut, "Too little received");

        uint256 soldTokenFinalAmount = swapTokensDetails.initialSoldTokenBalance -
                swapTokensDetails.soldToken.balanceOf(address(this));

        ITokenManager tokenManager = DeploymentConstants.getTokenManager();
        _decreaseExposure(tokenManager, address(swapTokensDetails.soldToken), soldTokenFinalAmount);
        _increaseExposure(tokenManager, address(swapTokensDetails.boughtToken), boughtTokenFinalAmount);

        emit Swap(
            msg.sender,
            swapTokensDetails.tokenSoldSymbol,
            swapTokensDetails.tokenBoughtSymbol,
            soldTokenFinalAmount,
            boughtTokenFinalAmount,
            block.timestamp
        );
    }

    function _decodeSwapExactAmountInData(bytes calldata _data) internal pure {
        
        
        
        
        
        
        
        console.log("Inside _decodeSwapExactAmountInData, about to decode with SwapExactAmountIn");
        address executor;
        bytes memory executorBytes = _data[:32];
        (executor) = abi.decode(executorBytes, (address));
        console.log("Executor Address: ");
        console.log(executor);
        /// @dev generic data size is 224. So the entire struct would be from 32 to 224+32 positions
        bytes memory genericDataBytes = _data[32:256];
        _decodeGenericData(genericDataBytes);
        // SwapExactAmountIn memory swapExactAmountIn = abi.decode(_data, (SwapExactAmountIn));
        // console.log("swapExactAmountIn Struct Decoded ");
        // console.log("Executor Address: ");
        // console.log(swapExactAmountIn.executor);
        // console.log("Partner And Fee Together as Int:");
        // console.log(swapExactAmountIn.partnerAndFee);
        // bytes memory permit = abi.encodePacked(swapExactAmountIn.permit);
        // console.logBytes(permit);
        // console.log("Executor Data: ");
        // bytes memory executorData = abi.encodePacked(swapExactAmountIn.executorData);
        // console.logBytes(executorData);
        // console.log("Generic Data Being Sent to Another Internal Function! ");
        // _decodeGenericData(abi.encode(swapExactAmountIn.swapData));

    }

    function _decodeGenericData(bytes memory _data) internal pure {
        GenericData memory genericData = abi.decode(_data, (GenericData));
        console.log("genericData Struct Decoded ");
        console.log("Source Token: ");
        console.log(genericData.srcToken);
        console.log("Destination Token: ");
        console.log(genericData.destToken);
        console.log("From Amount: ");
        console.log(genericData.fromAmount);
        console.log("To Amount: ");
        console.log(genericData.toAmount);
        console.log("Quoted Amount: ");
        console.log(genericData.quotedAmount);
        console.log("Metadata: ");
        bytes memory metadata = abi.encodePacked(genericData.metadata);
        console.logBytes(metadata);
        console.log("Beneficiary: ");
        console.log(genericData.beneficiary);
    }


    modifier onlyOwner() {
        DiamondStorageLib.enforceIsContractOwner();
        _;
    }

    modifier onlyWhitelistedLiquidators() {
        // External call in order to execute this method in the SmartLoanDiamondBeacon contract storage
        require(SmartLoanLiquidationFacet(DeploymentConstants.getDiamondAddress()).isLiquidatorWhitelisted(msg.sender), "Only whitelisted liquidators can execute this method");
        _;
    }

    /**
     * @dev emitted after a swap of assets
     * @param user the address of user making the purchase
     * @param soldAsset sold by the user
     * @param boughtAsset bought by the user
     * @param amountSold amount of tokens sold
     * @param amountBought amount of tokens bought
     * @param timestamp time of the swap
     **/
    event Swap(
        address indexed user,
        bytes32 indexed soldAsset,
        bytes32 indexed boughtAsset,
        uint256 amountSold,
        uint256 amountBought,
        uint256 timestamp
    );
}

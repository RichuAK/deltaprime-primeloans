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

    address private constant PARA_TRANSFER_PROXY =
        0x216B4B4Ba9F3e719726886d34a177484278Bfcae;
    address private constant PARA_ROUTER =
        0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    
    ///@notice selectors for paraSwapV2 data decoding
    bytes4 private constant DIRECT_UNI_V3_SELECTOR = 0xa6886da9;
    bytes4 private constant SIMPLESWAP_SELECTOR = 0x54e3f31b;
    bytes4 private constant MULTISWAP_SELECTOR = 0xa94e78ef;
    
    struct SwapTokensDetails {
        bytes32 tokenSoldSymbol;
        bytes32 tokenBoughtSymbol;
        IERC20Metadata soldToken;
        IERC20Metadata boughtToken;
        uint256 initialSoldTokenBalance;
        uint256 initialBoughtTokenBalance;
    }

    
    ///@notice struct for directUniV3Swap method for ParaSwapRouter, derived manually from real transaction data onchain.
    ///@dev successfully decodes data in test. Selector is 0xa6886da9
    struct DirectUniswapV3SwapData {
        address fromToken;
        address toToken;
        address exchange;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 expectedAmount;
        uint256 feePercent;
        uint256 deadline;
        address partner;
        bool isApproved;
        address beneficiary;
        bytes path;
        bytes permit;
        bytes16 uuid;
    }

    /// @notice simpleSwap data Struct from ParaSwapRouter, manually derived from real transaction data onchain.
    /// @dev test passes, data gets decoded. Selector is 0x54e3f31b
    struct SimpleSwapData{
        address fromToken; 
        address toToken; 
        uint256 fromAmount; 
        uint256 toAmount; 
        uint256 expectedAmount; 
        address[] callees; 
        bytes exchangeData;
        uint256[] startIndexes; 
        uint256[] values; 
        address beneficiary; 
        address partner; 
        uint256 feePercent; 
        bytes permit; 
        uint256 deadline; 
        bytes16 uuid;
    }

    ///@notice multiSwap data Struct from ParaSwap Github
    /// https://github.com/paraswap/augustus-v5/blob/d297477b8fc7be65c337b0cf2bc21f4f7f925b68/contracts/routers/MultiPath.sol#L43
    /// https://github.com/paraswap/augustus-v5/blob/d297477b8fc7be65c337b0cf2bc21f4f7f925b68/contracts/lib/Utils.sol#L61
    /// @dev test passes, but haven't decoded the actual args yet due to lack of object being returned by API. Selector is 0xa94e78ef
    //////******* MultiSwap Structs Begin *******//////// 
    /**
     * @param fromToken Address of the source token
     * @param fromAmount Amount of source tokens to be swapped
     * @param toAmount Minimum destination token amount expected out of this swap
     * @param expectedAmount Expected amount of destination tokens without slippage
     * @param beneficiary Beneficiary address
     * 0 then 100% will be transferred to beneficiary. Pass 10000 for 100%
     * @param path Route to be taken for this swap to take place
     */
    struct SellData {
        address fromToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 expectedAmount;
        address payable beneficiary;
        Path[] path;
        address payable partner;
        uint256 feePercent;
        bytes permit;
        uint256 deadline;
        bytes16 uuid;
    }

    struct Path {
        address to;
        uint256 totalNetworkFee; //NOT USED - Network fee is associated with 0xv3 trades
        Adapter[] adapters;
    }

    struct Adapter {
        address payable adapter;
        uint256 percent;
        uint256 networkFee; //NOT USED
        Route[] route;
    }

    struct Route {
        uint256 index; //Adapter at which index needs to be used
        address targetExchange;
        uint256 percent;
        bytes payload;
        uint256 networkFee; //NOT USED - Network fee is associated with 0xv3 trades
    }

    //////******* MultiSwap Struct End *******//////// 

    /// SellData cut in half to  avoid stack too deep///
    ///@dev Forsaken Path[], only caring about the other args
    struct SellDataOne{
        address fromToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 expectedAmount;
        address payable beneficiary;
        // Path[] path;
    }

    struct SellDataTwo{
        address payable partner;
        uint256 feePercent;
        bytes permit;
        uint256 deadline;
        bytes16 uuid;
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

        console.log("Inside ParaSwap v2");
        bytes memory selectorBytes = abi.encodePacked(selector);
        console.log("Selector: ");
        console.logBytes(selectorBytes);
        /// @dev would need to slice the data before decoding, I think
        // {

        //     bytes memory firstThreeAddresses = data[:96];
        //     address fromTokenFromData;
        //     address toTokenFromData;
        //     address exchangeFromData;
        //     (fromTokenFromData, toTokenFromData, exchangeFromData) = abi.decode(
        //         firstThreeAddresses,
        //         (address, address, address)
        //     );
        //     console.log("FromToken: ");
        //     console.log(fromTokenFromData);
        //     console.log("ToToken: ");
        //     console.log(toTokenFromData);
        //     console.log("Exchange: ");
        //     console.log(exchangeFromData);
        // }

        ///@dev special scoping to avoid stack too deep error. Update: scoping inside if else statements, still valid
        /// https://stackoverflow.com/questions/74578910/how-to-fix-compilererror-stack-too-deep-try-compiling-with-via-ir-cli
        /// UniSwap does the same apparently: https://ethereum.stackexchange.com/questions/6061/error-while-compiling-stack-too-deep
        
        if(selector == DIRECT_UNI_V3_SELECTOR){
            _decodeDirectUniV3SwapData(data);
        } else if(selector == SIMPLESWAP_SELECTOR){
            _decodeSimpleSwapData(data);
        } else if(selector == MULTISWAP_SELECTOR){
            _decodeMultiSwapData(data);
            // console.log("MultiSwap PlaceHolder");
        } else {
            console.log("Not My Selector!");
        }

        // {
        //     DecodedData memory decodedData = abi.decode(data, (DecodedData));
        //     console.log("Beneficiary:");
        //     console.log(decodedData.beneficiaryData);
        //     console.log("Path:");
        //     console.logBytes(decodedData.pathData);
        //     console.log("Permit:");
        //     console.logBytes(decodedData.permitData);
        //     bytes memory uuidBytes = abi.encodePacked(decodedData.uuidData);
        //     console.log("UUID:");
        //     console.logBytes(uuidBytes);
        // }
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

    function _decodeDirectUniV3SwapData(bytes memory _data) internal pure{
        DirectUniswapV3SwapData memory decodedData = abi.decode(_data, (DirectUniswapV3SwapData));
            console.log("Decoding directUniV3Swap Data");
            console.log("From Token:");
            console.log(decodedData.fromToken);
            console.log("To Token:");
            console.log(decodedData.toToken);
            console.log("Exchange:");
            console.log(decodedData.exchange);
            console.log("From Amount:");
            console.log(decodedData.fromAmount);
            console.log("To Amount:");
            console.log(decodedData.toAmount);
            console.log("Expected Amount:");
            console.log(decodedData.expectedAmount);
            console.log("Fee Percent:");
            console.log(decodedData.feePercent);
            console.log("Deadline:");
            console.log(decodedData.deadline);
            console.log("Partner:");
            console.log(decodedData.partner);
            console.log("Is Approved:");
            console.log(decodedData.isApproved);
            // console.log("Beneficiary:");
            // console.log(decodedData.beneficiaryData);
            // console.log("Path:");
            // console.logBytes(decodedData.pathData);
            // console.log("Permit:");
            // console.logBytes(decodedData.permitData);
            // bytes memory uuidBytes = abi.encodePacked(decodedData.uuidData);
            // console.log("UUID:");
            // console.logBytes(uuidBytes);

    }

    function _decodeSimpleSwapData(bytes memory _data) internal pure{
        SimpleSwapData memory decodedData = abi.decode(_data, (SimpleSwapData));
            console.log("Decoding SimpleSwap Data");
            console.log("From Token:");
            console.log(decodedData.fromToken);
            console.log("To Token:");
            console.log(decodedData.toToken);
            // console.log("Exchange:");
            // console.log(decodedData.exchangeData);
            console.log("From Amount:");
            console.log(decodedData.fromAmount);
            console.log("To Amount:");
            console.log(decodedData.toAmount);
            console.log("Expected Amount:");
            console.log(decodedData.expectedAmount);
            console.log("Exchange Data:");
            bytes memory exchangeDataBytes = abi.encodePacked(decodedData.exchangeData);
            console.logBytes(exchangeDataBytes);
            console.log("Fee Percent:");
            console.log(decodedData.feePercent);
            console.log("Deadline:");
            console.log(decodedData.deadline);
            console.log("Partner:");
            console.log(decodedData.partner);
            console.log("Beneficiary:");
            console.log(decodedData.beneficiary);
    }

    function _decodeMultiSwapData(bytes calldata _data) internal pure {
            // SellData memory decodedData = abi.decode(_data, (SellData));
            ///@dev forsaking Path[] dynamic array to avoid stack too deep error
            console.log("Decoding MultiSwap Data");
            SellDataOne memory decodedDataOne;
            decodedDataOne = abi.decode(_data[:160], (SellDataOne));
            console.log("Decoded the First Struct!");
            console.log("From Token:");
            console.log(decodedDataOne.fromToken);
            console.log("From Amount:");
            console.log(decodedDataOne.fromAmount);
            console.log("To Amount:");
            console.log(decodedDataOne.toAmount);
            console.log("Expected Amount:");
            console.log(decodedDataOne.expectedAmount);
            console.log("Beneficiary:");
            console.log(decodedDataOne.beneficiary);
            SellDataTwo memory decodedDataTwo;
            ///@dev getting the first half
            ///@dev SellDataTwo struct has five elements, with 32 bytes each. So the latter half is 160 bytes long
            uint256 dataSliceSecondHalfBeginning = _data.length - 192;
            ///@dev getting the second half 
            decodedDataTwo = abi.decode(_data[dataSliceSecondHalfBeginning:], (SellDataTwo));
            // (decodedDataOne,decodedDataTwo) = abi.decode(_data, (SellDataOne,SellDataTwo));
            console.log("Fee Percent:");
            console.log(decodedDataTwo.feePercent);
            console.log("Deadline:");
            console.log(decodedDataTwo.deadline);
            console.log("Partner:");
            console.log(decodedDataTwo.partner);
            console.log("Permit:");
            console.logBytes(decodedDataTwo.permit);
            bytes memory uuidBytes = abi.encodePacked(decodedDataTwo.uuid);
            console.log("UUID:");
            console.logBytes(uuidBytes);
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

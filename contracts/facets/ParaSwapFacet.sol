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

    struct SwapTokensDetails {
        bytes32 tokenSoldSymbol;
        bytes32 tokenBoughtSymbol;
        IERC20Metadata soldToken;
        IERC20Metadata boughtToken;
        uint256 initialSoldTokenBalance;
        uint256 initialBoughtTokenBalance;
    }

    struct DecodedData {
        address fromTokenData;
        address toTokenData;
        address exchangeData;
        uint256 fromAmountData;
        uint256 toAmountData;
        uint256 expectedAmountData;
        uint256 feePercentData;
        uint256 deadlineData;
        address partnerData;
        bool isApprovedData;
        address beneficiaryData;
        bytes pathData;
        bytes permitData;
        bytes16 uuidData;
    }

    // (address fromToken, address toToken, address exchange, uint256 fromAmount, uint256 toAmount, 
    // uint256 expectedAmount, uint256 feePercent, uint256 deadline, 
    // address partner, bool isApproved, address beneficiary, bytes path, bytes permit, bytes16 uuid)

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
        bytes memory data,  ///@dev changing data from memory to calldata for slicing
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

        /// @dev would need to slice the data before decoding, I think
        // {
        //     console.log("Inside ParaSwap v2");
        //     bytes memory selectorBytes = abi.encodePacked(selector);
        //     console.log("Selector: ");
        //     console.logBytes(selectorBytes);

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

        ///@dev special scoping here to avoid stack too deep error
        /// https://stackoverflow.com/questions/74578910/how-to-fix-compilererror-stack-too-deep-try-compiling-with-via-ir-cli
        /// UniSwap does the same apparently: https://ethereum.stackexchange.com/questions/6061/error-while-compiling-stack-too-deep
        {
            DecodedData memory decodedData = abi.decode(data, (DecodedData));
            console.log("From Token:");
            console.log(decodedData.fromTokenData);
            console.log("To Token:");
            console.log(decodedData.toTokenData);
            console.log("Exchange:");
            console.log(decodedData.exchangeData);
            console.log("From Amount:");
            console.log(decodedData.fromAmountData);
            console.log("To Amount:");
            console.log(decodedData.toAmountData);
            console.log("Expected Amount:");
            console.log(decodedData.expectedAmountData);
            console.log("Fee Percent:");
            console.log(decodedData.feePercentData);
            console.log("Deadline:");
            console.log(decodedData.deadlineData);
            console.log("Partner:");
            console.log(decodedData.partnerData);
            console.log("Is Approved:");
            console.log(decodedData.isApprovedData);
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

        {
            DecodedData memory decodedData = abi.decode(data, (DecodedData));
            console.log("Beneficiary:");
            console.log(decodedData.beneficiaryData);
            console.log("Path:");
            console.logBytes(decodedData.pathData);
            console.log("Permit:");
            console.logBytes(decodedData.permitData);
            bytes memory uuidBytes = abi.encodePacked(decodedData.uuidData);
            console.log("UUID:");
            console.logBytes(uuidBytes);
        }
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

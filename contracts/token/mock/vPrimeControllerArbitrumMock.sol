// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: ;
pragma solidity 0.8.17;

import {vPrimeControllerArbitrum} from "../vPrimeControllerArbitrum.sol";
import "@redstone-finance/evm-connector/contracts/mocks/AuthorisedMockSignersBase.sol";

contract vPrimeControllerArbitrumMock is vPrimeControllerArbitrum, AuthorisedMockSignersBase {
    uint256 constant DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS = 15 minutes; // Test sometimes be slow

    uint256 internal constant MIN_TIMESTAMP_MILLISECONDS = 1654353400000;

    function getAuthorisedSignerIndex(address signerAddress)
    public
    view
    virtual
    override
    returns (uint8)
    {
        return getAuthorisedMockSignerIndex(signerAddress);
    }

    function validateTimestamp(uint256 receivedTimestampMilliseconds) public view virtual override {
        // Always pass
    }
}
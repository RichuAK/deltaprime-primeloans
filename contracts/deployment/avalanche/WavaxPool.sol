// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: a8f526aa333c0839a46e38e0edf0d2a47ade01ae;
pragma solidity 0.8.17;

import "../../WrappedNativeTokenPool.sol";


/**
 * @title WavaxPool
 * @dev Contract allowing user to deposit to and borrow WAVAX from a dedicated user account
 */
contract WavaxPool is WrappedNativeTokenPool {
    // Returns max. acceptable pool utilisation after borrow action
    function getMaxPoolUtilisationForBorrowing() override public view returns (uint256) {
        return 0.925e18;
    }

    function name() public virtual override pure returns(string memory _name){
        _name = "DeltaPrimeWrappedAVAX";
    }

    function symbol() public virtual override pure returns(string memory _symbol){
        _symbol = "DPWAVAX";
    }

    function decimals() public virtual override pure returns(uint8 decimals){
        decimals = 18;
    }
}
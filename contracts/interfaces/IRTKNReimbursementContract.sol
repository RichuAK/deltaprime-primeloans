// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: ;
pragma solidity 0.8.17;

/**
 * @title IRTKNReimbursementContract
 */
interface IRTKNReimbursementContract {
    function isRTKNTransferEnabled() external view returns (bool);
}

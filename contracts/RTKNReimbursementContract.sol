// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: 2f8ed44459fc99825919d399c3e4350b61551b67;
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RTKNReimbursementContract is Initializable, OwnableUpgradeable {
    // TODO: Change address to interface once available
    bool private rTKNTransferEnabled;

    constructor(){
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    function isRTKNTransferEnabled() public view returns (bool) {
        return rTKNTransferEnabled;
    }

    function setRTKNTransferEnabled(bool _rTKNTransferEnabled) public onlyOwner {
        rTKNTransferEnabled = _rTKNTransferEnabled;
        emit SetRTKNTransferEnabled(rTKNTransferEnabled);
    }

    event SetRevenueDistributionContract(address previousRevenueDistributionContract, address newRevenueDistributionContract);

    event SetRTKNTransferEnabled(bool rTKNTransferEnabled);
}
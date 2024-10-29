// SPDX-License-Identifier: BUSL-1.1
// Last deployed from commit: 2f8ed44459fc99825919d399c3e4350b61551b67;
pragma solidity ^0.8.17;

import "./interfaces/IRTKNReimbursementContract.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract RTKNDP is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    IRTKNReimbursementContract public reimbursementDistributionContract;
    mapping(address => uint256) public cTKNBalance;
    mapping(address => uint256) public dTKNBalance;

    constructor(){
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("ReimbursementTokenDeltaPrime", "rTKNDP");
        __Ownable_init();
    }

    function setReimbursementDistributionContract(address _reimbursementDistributionContract) public onlyOwner {
        address previousReimbursementDistributionContract = reimbursementDistributionContract;
        reimbursementDistributionContract = _reimbursementDistributionContract;
        emit SetReimbursementDistributionContract(previousReimbursementDistributionContract, reimbursementDistributionContract);
    }

    // before token transfer
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(reimbursementDistributionContract.isRTKNTransferEnabled(), "RTKN transfer is not enabled");

        // transfer cTKNs if from/to is neither zero address or a contract
        if (
            from != address(0)
            && from != address(this)
            && !AddressUpgradeable.isContract(from)
            && to != address(0)
            && to != address(this)
            && !AddressUpgradeable.isContract(to)
        ) {
            uint256 cTKNAmount = amount * cTKNBalance[from] / balanceOf(from);
            cTKNBalance[from] -= cTKNAmount;
            cTKNBalance[to] += cTKNAmount;
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function mintCTKN(address[] calldata accounts, uint256[] calldata amounts) public onlyReimbursementDistributionContract {
        require(accounts.length == amounts.length, "Array lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            cTKNBalance[accounts[i]] += amounts[i];
            emit CTKNMinted(accounts[i], amounts[i]);
        }
    }
    
    function burnCTKN(address[] calldata accounts, uint256[] calldata amounts) public onlyReimbursementDistributionContract {
        require(accounts.length == amounts.length, "Array lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            require(cTKNBalance[accounts[i]] >= amounts[i], "Insufficient cTKN balance to burn");
            cTKNBalance[accounts[i]] -= amounts[i];
            emit CTKNBurned(accounts[i], amounts[i]);
        }
    }

    function mintDTKN(address[] calldata accounts, uint256[] calldata amounts) public onlyReimbursementDistributionContract {
        require(accounts.length == amounts.length, "Array lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            dTKNBalance[accounts[i]] += amounts[i];
            emit dTKNMinted(accounts[i], amounts[i]);
        }
    }

    function burnDTKN(address[] calldata accounts, uint256[] calldata amounts) public onlyReimbursementDistributionContract {
        require(accounts.length == amounts.length, "Array lengths do not match");
        for (uint256 i = 0; i < accounts.length; i++) {
            require(dTKNBalance[accounts[i]] >= amounts[i], "Insufficient dTKN balance to burn");
            dTKNBalance[accounts[i]] -= amounts[i];
            emit dTKNBurned(accounts[i], amounts[i]);
        }
    }

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    
    
    modifier onlyReimbursementDistributionContract() {
        require(msg.sender == address(reimbursementDistributionContract), "Caller is not the ReimbursementDistributionContract");
        _;
    }


    // Event to log the change in the ReimbursementDistributionContract
    event SetReimbursementDistributionContract(address previousReimbursementDistributionContract, address newReimbursementDistributionContract);

    // Event to log the minting of cTKNs
    event CTKNMinted(address account, uint256 amount);

    // Event to log the burning of cTKNs
    event CTKNBurned(address account, uint256 amount);

    // Event to log the minting of dTKNs
    event dTKNMinted(address account, uint256 amount);

    // Event to log the burning of dTKNs
    event dTKNBurned(address account, uint256 amount);
}
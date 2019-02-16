/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import {Ownable} from "./Ownable.sol";
import {Servable} from "./Servable.sol";
import {Configurable} from "./Configurable.sol";
import {BalanceTrackable} from "./BalanceTrackable.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {MonetaryTypesLib} from "./MonetaryTypesLib.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";
import {SettlementTypesLib} from "./SettlementTypesLib.sol";

/**
 * @title NullSettlementChallengeState
 * @notice Where null settlements challenge state is managed
 */
contract NullSettlementChallengeState is Ownable, Servable, Configurable, BalanceTrackable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Constants
    // -----------------------------------------------------------------------------------------------------------------
    // TODO Register NullSettlementChallengeByTrade, NullSettlementDisputeByTrade, NullSettlementChallengeByPayment and NullSettlementDisputeByPayment as services and enable actions
    string constant public SET_PROPOSAL_EXPIRATION_TIME_ACTION = "set_proposal_expiration_time";
    string constant public SET_PROPOSAL_STATUS_ACTION = "set_proposal_status";
    string constant public ADD_PROPOSAL_ACTION = "add_proposal";
    string constant public DISQUALIFY_PROPOSAL_ACTION = "disqualify_proposal";
    string constant public QUALIFY_PROPOSAL_ACTION = "qualify_proposal";

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    uint256 public nonce;

    SettlementTypesLib.Proposal[] public proposals;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public proposalIndexByWalletCurrency;
    mapping(address => uint256[]) public proposalIndicesByWallet;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SetProposalExpirationTimeEvent(address wallet, MonetaryTypesLib.Currency currency,
        uint256 expirationTime);
    event SetProposalStatusEvent(address wallet, MonetaryTypesLib.Currency currency,
        SettlementTypesLib.Status status);
    event AddProposalEvent(address wallet, int256 stageAmount, int256 targetBalanceAmount,
        MonetaryTypesLib.Currency currency, uint256 nonce, uint256 blockNumber, bool balanceReward);
    event DisqualifyProposalEvent(address challengedWallet, MonetaryTypesLib.Currency currency,
        address challengerWallet, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType);
    event QualifyProposalEvent(address challengedWallet, MonetaryTypesLib.Currency currency,
        address challengerWallet, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Get the number of proposals
    /// @return The number of proposals
    function proposalsCount()
    public
    view
    returns (uint256)
    {
        return proposals.length;
    }

    /// @notice Gauge whether the proposal for the given wallet and currency has expired
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return true if proposal has expired, else false
    function hasProposalExpired(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (bool)
    {
        // 1-based index
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        return (
        0 == index ||
        0 == proposals[index - 1].nonce ||
        block.timestamp >= proposals[index - 1].expirationTime
        );
    }

    /// @notice Get the challenge nonce of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The challenge nonce
    function proposalNonce(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].nonce;
    }

    /// @notice Get the settlement proposal block number of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal block number
    function proposalBlockNumber(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].blockNumber;
    }

    /// @notice Get the settlement proposal end time of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal end time
    function proposalExpirationTime(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].expirationTime;
    }

    /// @notice Get the challenge status of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The challenge status
    function proposalStatus(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (SettlementTypesLib.Status)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].status;
    }

    /// @notice Get the settlement proposal stage amount of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal stage amount
    function proposalStageAmount(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (int256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].stageAmount;
    }

    /// @notice Get the settlement proposal target balance amount of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal target balance amount
    function proposalTargetBalanceAmount(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (int256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].targetBalanceAmount;
    }

    /// @notice Get the balance reward of the given wallet's settlement proposal
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The balance reward of the settlement proposal
    function proposalBalanceReward(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (bool)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].balanceReward;
    }

    /// @notice Get the disqualification challenger of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The challenger of the settlement disqualification
    function proposalDisqualificationChallenger(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (address)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].disqualification.challenger;
    }

    /// @notice Get the disqualification block number of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The block number of the settlement disqualification
    function proposalDisqualificationBlockNumber(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].disqualification.blockNumber;
    }

    /// @notice Get the disqualification candidate type of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The candidate type of the settlement disqualification
    function proposalDisqualificationCandidateType(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (SettlementTypesLib.CandidateType)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].disqualification.candidateType;
    }

    /// @notice Get the disqualification candidate hash of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The candidate hash of the settlement disqualification
    function proposalDisqualificationCandidateHash(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (bytes32)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        return proposals[index - 1].disqualification.candidateHash;
    }

    /// @notice Set settlement proposal end time property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @param expirationTime The end time value
    function setProposalExpirationTime(address wallet, MonetaryTypesLib.Currency currency,
        uint256 expirationTime)
    public
    onlyEnabledServiceAction(SET_PROPOSAL_EXPIRATION_TIME_ACTION)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        proposals[index - 1].expirationTime = expirationTime;

        // Emit event
        emit SetProposalExpirationTimeEvent(wallet, currency, expirationTime);
    }

    /// @notice Set settlement proposal status property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @param status The status value
    function setProposalStatus(address wallet, MonetaryTypesLib.Currency currency,
        SettlementTypesLib.Status status)
    public
    onlyEnabledServiceAction(SET_PROPOSAL_STATUS_ACTION)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);
        proposals[index - 1].status = status;

        // Emit event
        emit SetProposalStatusEvent(wallet, currency, status);
    }

    /// @notice Add proposal
    /// @param wallet The address of the concerned challenged wallet
    /// @param stageAmount The proposal stage amount
    /// @param targetBalanceAmount The proposal target balance amount
    /// @param currency The concerned currency
    /// @param blockNumber The proposal block number
    /// @param balanceReward The candidate balance reward
    function addProposal(address wallet, int256 stageAmount, int256 targetBalanceAmount,
        MonetaryTypesLib.Currency currency, uint256 blockNumber,
        bool balanceReward)
    public
    onlyEnabledServiceAction(ADD_PROPOSAL_ACTION)
    {
        // Require that wallet has no overlap with active proposal
        require(hasProposalExpired(wallet, currency));

        // Add proposal
        _addProposal(
            wallet, stageAmount, targetBalanceAmount,
            currency, blockNumber, balanceReward
        );

        // Emit event
        emit AddProposalEvent(
            wallet, stageAmount, targetBalanceAmount, currency, nonce,
            blockNumber, balanceReward
        );
    }

    /// @notice Disqualify a proposal
    /// @dev A call to this function will intentionally override previous disqualifications if existent
    /// @param challengedWallet The address of the concerned challenged wallet
    /// @param currency The concerned currency
    /// @param challengerWallet The address of the concerned challenger wallet
    /// @param blockNumber The disqualification block number
    /// @param candidateHash The candidate hash
    /// @param candidateType The candidate type
    function disqualifyProposal(address challengedWallet, MonetaryTypesLib.Currency currency, address challengerWallet,
        uint256 blockNumber, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType)
    public
    onlyEnabledServiceAction(DISQUALIFY_PROPOSAL_ACTION)
    {
        // Get the proposal index
        uint256 index = proposalIndexByWalletCurrency[challengedWallet][currency.ct][currency.id];
        require(0 != index);

        // Update proposal
        proposals[index - 1].status = SettlementTypesLib.Status.Disqualified;
        proposals[index - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        proposals[index - 1].disqualification.challenger = challengerWallet;
        proposals[index - 1].disqualification.blockNumber = blockNumber;
        proposals[index - 1].disqualification.candidateHash = candidateHash;
        proposals[index - 1].disqualification.candidateType = candidateType;

        // Emit event
        emit DisqualifyProposalEvent(
            challengedWallet, currency, challengerWallet, candidateHash, candidateType
        );
    }

    /// @notice (Re)Qualify a proposal
    /// @param wallet The address of the concerned challenged wallet
    /// @param currency The concerned currency
    function qualifyProposal(address wallet, MonetaryTypesLib.Currency currency)
    public
    onlyEnabledServiceAction(QUALIFY_PROPOSAL_ACTION)
    {
        // Get the proposal index
        uint256 index = proposalIndexByWalletCurrency[wallet][currency.ct][currency.id];
        require(0 != index);

        // Emit event
        emit QualifyProposalEvent(
            wallet, currency,
            proposals[index - 1].disqualification.challenger,
            proposals[index - 1].disqualification.candidateHash,
            proposals[index - 1].disqualification.candidateType
        );

        // Update proposal
        proposals[index - 1].status = SettlementTypesLib.Status.Qualified;
        proposals[index - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        delete proposals[index - 1].disqualification;
    }

    //
    // Private functions
    // -----------------------------------------------------------------------------------------------------------------
    function _addProposal(address wallet, int256 stageAmount, int256 targetBalanceAmount,
        MonetaryTypesLib.Currency currency, uint256 blockNumber,
        bool balanceReward)
    private
    returns (SettlementTypesLib.Proposal storage)
    {
        // Require that stage and target balance amounts are positive
        require(stageAmount.isPositiveInt256());
        require(targetBalanceAmount.isPositiveInt256());

        // Create proposal
        proposals.length++;

        // Populate proposal
        proposals[proposals.length - 1].wallet = wallet;
        proposals[proposals.length - 1].nonce = ++nonce;
        proposals[proposals.length - 1].blockNumber = blockNumber;
        proposals[proposals.length - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        proposals[proposals.length - 1].status = SettlementTypesLib.Status.Qualified;
        proposals[proposals.length - 1].currency = currency;
        proposals[proposals.length - 1].stageAmount = stageAmount;
        proposals[proposals.length - 1].targetBalanceAmount = targetBalanceAmount;
        proposals[proposals.length - 1].balanceReward = balanceReward;

        // Store proposal index
        proposalIndexByWalletCurrency[wallet][currency.ct][currency.id] = proposals.length;
        proposalIndicesByWallet[wallet].push(proposals.length);

        return proposals[proposals.length - 1];
    }

    function _activeBalanceLogEntry(address wallet, address currencyCt, uint256 currencyId)
    private
    view
    returns (int256 amount, uint256 blockNumber)
    {
        // Get last log record of deposited and settled balances
        (int256 depositedAmount, uint256 depositedBlockNumber) = balanceTracker.lastFungibleRecord(
            wallet, balanceTracker.depositedBalanceType(), currencyCt, currencyId
        );
        (int256 settledAmount, uint256 settledBlockNumber) = balanceTracker.lastFungibleRecord(
            wallet, balanceTracker.settledBalanceType(), currencyCt, currencyId
        );

        // Set amount as the sum of deposited and settled
        amount = depositedAmount.add(settledAmount);

        // Set block number as the latest of deposited and settled
        blockNumber = depositedBlockNumber > settledBlockNumber ? depositedBlockNumber : settledBlockNumber;
    }
}

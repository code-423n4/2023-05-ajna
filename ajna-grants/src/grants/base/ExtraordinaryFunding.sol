// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IERC20 }   from "@oz/token/ERC20/IERC20.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";

import { Funding } from "./Funding.sol";

import { IExtraordinaryFunding } from "../interfaces/IExtraordinaryFunding.sol";

import { Maths } from "../libraries/Maths.sol";

abstract contract ExtraordinaryFunding is Funding, IExtraordinaryFunding {

    /*****************/
    /*** Constants ***/
    /*****************/

    /**
     * @notice The maximum length of a proposal's voting period, in blocks.
     */
    uint256 internal constant MAX_EFM_PROPOSAL_LENGTH = 216_000; // number of blocks in one month

    /**
     * @notice Keccak hash of a prefix string for extraordinary funding mechanism
     */
    bytes32 internal constant DESCRIPTION_PREFIX_HASH_EXTRAORDINARY = keccak256(bytes("Extraordinary Funding: "));

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     * @notice Mapping of extant extraordinary funding proposals.
     * @dev proposalId => ExtraordinaryFundingProposal.
     */
    mapping (uint256 => ExtraordinaryFundingProposal) internal _extraordinaryFundingProposals;

    /**
     * @notice The list of extraordinary funding proposalIds that have been executed.
     */
    uint256[] internal _fundedExtraordinaryProposals;

    /**
     * @notice Mapping checking if a voter has voted on a given proposal.
     * @dev proposalId => address => bool.
     */
    mapping(uint256 => mapping(address => bool)) public hasVotedExtraordinary;

    /**************************/
    /*** Proposal Functions ***/
    /**************************/

    /// @inheritdoc IExtraordinaryFunding
    function executeExtraordinary(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) external nonReentrant override returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(targets_, values_, calldatas_, keccak256(abi.encode(DESCRIPTION_PREFIX_HASH_EXTRAORDINARY, descriptionHash_)));

        ExtraordinaryFundingProposal storage proposal = _extraordinaryFundingProposals[proposalId_];

        // since we are casting from uint128 to uint256, we can safely assume that the value will not overflow
        uint256 tokensRequested = uint256(proposal.tokensRequested);

        // check proposal is succesful and hasn't already been executed
        if (proposal.executed || !_extraordinaryProposalSucceeded(proposalId_, tokensRequested)) revert ExecuteExtraordinaryProposalInvalid();

        _fundedExtraordinaryProposals.push(proposalId_);

        // update proposal state
        proposal.executed = true;

        // update treasury
        treasury -= tokensRequested;

        // execute proposal's calldata
        _execute(proposalId_, targets_, values_, calldatas_);
    }

    /// @inheritdoc IExtraordinaryFunding
    function proposeExtraordinary(
        uint256 endBlock_,
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        string memory description_) external override returns (uint256 proposalId_) {

        proposalId_ = _hashProposal(targets_, values_, calldatas_, keccak256(abi.encode(DESCRIPTION_PREFIX_HASH_EXTRAORDINARY, keccak256(bytes(description_)))));

        ExtraordinaryFundingProposal storage newProposal = _extraordinaryFundingProposals[proposalId_];

        // check if proposal already exists (proposal id not 0)
        if (newProposal.proposalId != 0) revert ProposalAlreadyExists();

        // check proposal length is within limits of 1 month maximum
        if (block.number + MAX_EFM_PROPOSAL_LENGTH < endBlock_) revert InvalidProposal();

        uint128 totalTokensRequested = _validateCallDatas(targets_, values_, calldatas_);

        // check tokens requested are available for claiming from the treasury
        if (uint256(totalTokensRequested) > _getSliceOfTreasury(Maths.WAD - _getMinimumThresholdPercentage())) revert InvalidProposal();

        // store newly created proposal
        newProposal.proposalId      = proposalId_;
        newProposal.startBlock      = SafeCast.toUint128(block.number);
        newProposal.endBlock        = SafeCast.toUint128(endBlock_);
        newProposal.tokensRequested = totalTokensRequested;

        emit ProposalCreated(
            proposalId_,
            msg.sender,
            targets_,
            values_,
            new string[](targets_.length),
            calldatas_,
            block.number,
            endBlock_,
            description_
        );
    }

    /************************/
    /*** Voting Functions ***/
    /************************/

    /// @inheritdoc IExtraordinaryFunding
    function voteExtraordinary(
        uint256 proposalId_
    ) external override returns (uint256 votesCast_) {
        // revert if msg.sender already voted on proposal
        if (hasVotedExtraordinary[proposalId_][msg.sender]) revert AlreadyVoted();

        ExtraordinaryFundingProposal storage proposal = _extraordinaryFundingProposals[proposalId_];
        // revert if proposal is inactive
        if (proposal.startBlock > block.number || proposal.endBlock < block.number || proposal.executed) {
            revert ExtraordinaryFundingProposalInactive();
        }

        // check voting power at snapshot block and update proposal votes
        votesCast_ = _getVotesExtraordinary(msg.sender, proposalId_);
        proposal.votesReceived += SafeCast.toUint120(votesCast_);

        // record that voter has voted on this extraordinary funding proposal
        hasVotedExtraordinary[proposalId_][msg.sender] = true;

        emit VoteCast(
            msg.sender,
            proposalId_,
            1,
            votesCast_,
            ""
        );
    }

    /**
     * @notice Check if a proposal for extraordinary funding has succeeded.
     * @param  proposalId_ The ID of the proposal being checked.
     * @return Boolean indicating whether the proposal has succeeded.
     */
    function _extraordinaryProposalSucceeded(
        uint256 proposalId_,
        uint256 tokensRequested_
    ) internal view returns (bool) {
        uint256 votesReceived          = uint256(_extraordinaryFundingProposals[proposalId_].votesReceived);
        uint256 minThresholdPercentage = _getMinimumThresholdPercentage();

        return
            // succeeded if proposal's votes received doesn't exceed the minimum threshold required
            (votesReceived >= tokensRequested_ + _getSliceOfNonTreasury(minThresholdPercentage))
            &&
            // succeeded if tokens requested are available for claiming from the treasury
            (tokensRequested_ <= _getSliceOfTreasury(Maths.WAD - minThresholdPercentage))
        ;
    }

    /********************************/
    /*** Internal View Functions ****/
    /********************************/

    /**
     * @notice Get the current ProposalState of a given proposal.
     * @dev    Used by GrantFund.state() for analytics compatability purposes.
     * @param  proposalId_ The ID of the proposal being checked.
     * @return The proposals status in the ProposalState enum.
     */
    function _getExtraordinaryProposalState(uint256 proposalId_) internal view returns (ProposalState) {
        ExtraordinaryFundingProposal memory proposal = _extraordinaryFundingProposals[proposalId_];

        bool voteSucceeded = _extraordinaryProposalSucceeded(proposalId_, uint256(proposal.tokensRequested));

        if (proposal.executed)                                        return ProposalState.Executed;
        else if (proposal.endBlock >= block.number && !voteSucceeded) return ProposalState.Active;
        else if (voteSucceeded)                                       return ProposalState.Succeeded;
        else                                                          return ProposalState.Defeated;
    }

    /**
     * @notice Get the minimum percentage of ajna tokens required for a proposal to pass.
     * @dev    The minimum threshold increases according to the number of funded EFM proposals.
     * @return The minimum threshold percentage, as a WAD.
     */
    function _getMinimumThresholdPercentage() internal view returns (uint256) {
        // default minimum threshold is 50
        if (_fundedExtraordinaryProposals.length == 0) {
            return 0.5 * 1e18;
        }
        // minimum threshold increases according to the number of funded EFM proposals
        else {
            return 0.5 * 1e18 + (_fundedExtraordinaryProposals.length * (0.05 * 1e18));
        }
    }

    /**
     * @notice Get the number of ajna tokens equivalent to a given percentage.
     * @param percentage_ The percentage of the Non treasury to retrieve, in WAD.
     * @return The number of tokens, in WAD.
     */
    function _getSliceOfNonTreasury(
        uint256 percentage_
    ) internal view returns (uint256) {
        uint256 totalAjnaSupply = IERC20(ajnaTokenAddress).totalSupply();
        return Maths.wmul(totalAjnaSupply - treasury, percentage_);
    }

    /**
     * @notice Get the number of ajna tokens equivalent to a given percentage.
     * @param percentage_ The percentage of the treasury to retrieve, in WAD.
     * @return The number of tokens, in WAD.
     */
    function _getSliceOfTreasury(
        uint256 percentage_
    ) internal view returns (uint256) {
        return Maths.wmul(treasury, percentage_);
    }

    /**
     * @notice Get the voting power available to a voter for a given proposal.
     * @param  account_        The address of the voter to check.
     * @param  proposalId_     The ID of the proposal being voted on.
     * @return votes_          The number of votes available to be cast in voteExtraordinary.
     */
    function _getVotesExtraordinary(address account_, uint256 proposalId_) internal view returns (uint256 votes_) {
        if (proposalId_ == 0) revert ExtraordinaryFundingProposalInactive();

        uint256 startBlock = _extraordinaryFundingProposals[proposalId_].startBlock;

        votes_ = _getVotesAtSnapshotBlocks(
            account_,
            startBlock - VOTING_POWER_SNAPSHOT_DELAY,
            startBlock
        );
    }

    /********************************/
    /*** External View Functions ****/
    /********************************/

    /// @inheritdoc IExtraordinaryFunding
    function getMinimumThresholdPercentage() external view returns (uint256) {
        return _getMinimumThresholdPercentage();
    }

    /// @inheritdoc IExtraordinaryFunding
    function getSliceOfNonTreasury(
        uint256 percentage_
    ) external view override returns (uint256) {
        return _getSliceOfNonTreasury(percentage_);
    }

    /// @inheritdoc IExtraordinaryFunding
    function getSliceOfTreasury(
        uint256 percentage_
    ) external view override returns (uint256) {
        return _getSliceOfTreasury(percentage_);
    }

    /// @inheritdoc IExtraordinaryFunding
    function getExtraordinaryProposalInfo(
        uint256 proposalId_
    ) external view override returns (uint256, uint128, uint128, uint128, uint120, bool) {
        return (
            _extraordinaryFundingProposals[proposalId_].proposalId,
            _extraordinaryFundingProposals[proposalId_].startBlock,
            _extraordinaryFundingProposals[proposalId_].endBlock,
            _extraordinaryFundingProposals[proposalId_].tokensRequested,
            _extraordinaryFundingProposals[proposalId_].votesReceived,
            _extraordinaryFundingProposals[proposalId_].executed
        );
    }

    /// @inheritdoc IExtraordinaryFunding
    function getExtraordinaryProposalSucceeded(uint256 proposalId_) external view override returns (bool) {
        // since we are casting from uint128 to uint256, we can safely assume that the value will not overflow
        uint256 tokensRequested = uint256(_extraordinaryFundingProposals[proposalId_].tokensRequested);

        return _extraordinaryProposalSucceeded(proposalId_, tokensRequested);
    }

    /// @inheritdoc IExtraordinaryFunding
    function getVotesExtraordinary(address account_, uint256 proposalId_) external view override returns (uint256) {
        if (hasVotedExtraordinary[proposalId_][account_]) return 0;
        return _getVotesExtraordinary(account_, proposalId_);
    }

}

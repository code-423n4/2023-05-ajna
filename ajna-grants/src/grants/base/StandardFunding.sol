// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IERC20 }    from "@oz/token/ERC20/IERC20.sol";
import { SafeCast }  from "@oz/utils/math/SafeCast.sol";
import { SafeERC20 } from "@oz/token/ERC20/utils/SafeERC20.sol";

import { Funding } from "./Funding.sol";

import { IStandardFunding } from "../interfaces/IStandardFunding.sol";

import { Maths } from "../libraries/Maths.sol";

abstract contract StandardFunding is Funding, IStandardFunding {

    using SafeERC20 for IERC20;

    /*****************/
    /*** Constants ***/
    /*****************/

    /**
     * @notice Maximum percentage of tokens that can be distributed by the treasury in a quarter.
     * @dev Stored as a Wad percentage.
     */
    uint256 internal constant GLOBAL_BUDGET_CONSTRAINT = 0.03 * 1e18;

    /**
     * @notice Length of the challengephase of the distribution period in blocks.
     * @dev    Roughly equivalent to the number of blocks in 7 days.
     * @dev    The period in which funded proposal slates can be checked in updateSlate.
     */
    uint256 internal constant CHALLENGE_PERIOD_LENGTH = 50400;

    /**
     * @notice Length of the distribution period in blocks.
     * @dev    Roughly equivalent to the number of blocks in 90 days.
     */
    uint48 internal constant DISTRIBUTION_PERIOD_LENGTH = 648000;

    /**
     * @notice Length of the funding phase of the distribution period in blocks.
     * @dev    Roughly equivalent to the number of blocks in 10 days.
     */
    uint256 internal constant FUNDING_PERIOD_LENGTH = 72000;

    /**
     * @notice Keccak hash of a prefix string for standard funding mechanism
     */
    bytes32 internal constant DESCRIPTION_PREFIX_HASH_STANDARD = keccak256(bytes("Standard Funding: "));

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     * @notice ID of the current distribution period.
     * @dev Used to access information on the status of an ongoing distribution.
     * @dev Updated at the start of each quarter.
     * @dev Monotonically increases by one per period.
     */
    uint24 internal _currentDistributionId = 0;

    /**
     * @notice Mapping of quarterly distributions from the grant fund.
     * @dev distributionId => QuarterlyDistribution
     */
    mapping(uint24 => QuarterlyDistribution) internal _distributions;

    /**
     * @dev Mapping of all proposals that have ever been submitted to the grant fund for screening.
     * @dev proposalId => Proposal
     */
    mapping(uint256 => Proposal) internal _standardFundingProposals;

    /**
     * @dev Mapping of distributionId to a sorted array of 10 proposalIds with the most votes in the screening period.
     * @dev distribution.id => proposalId[]
     * @dev A new array is created for each distribution period
     */
    mapping(uint256 => uint256[]) internal _topTenProposals;

    /**
     * @notice Mapping of a hash of a proposal slate to a list of funded proposals.
     * @dev slate hash => proposalId[]
     */
    mapping(bytes32 => uint256[]) internal _fundedProposalSlates;

    /**
     * @notice Mapping of quarterly distributions to voters to a Quadratic Voter info struct.
     * @dev distributionId => voter address => QuadraticVoter 
     */
    mapping(uint256 => mapping(address => QuadraticVoter)) internal _quadraticVoters;

    /**
     * @notice Mapping of distributionId to whether surplus funds from distribution updated into treasury
     * @dev distributionId => bool
    */
    mapping(uint256 => bool) internal _isSurplusFundsUpdated;

    /**
     * @notice Mapping of distributionId to user address to whether user has claimed his delegate reward
     * @dev distributionId => address => bool
    */
    mapping(uint256 => mapping(address => bool)) public hasClaimedReward;

    /**
     * @notice Mapping of distributionId to user address to total votes cast on screening stage proposals.
     * @dev distributionId => address => uint256
    */
    mapping(uint256 => mapping(address => uint256)) public screeningVotesCast;

    /**************************************************/
    /*** Distribution Management Functions External ***/
    /**************************************************/

    /// @inheritdoc IStandardFunding
    function startNewDistributionPeriod() external override returns (uint24 newDistributionId_) {
        uint24  currentDistributionId       = _currentDistributionId;
        uint256 currentDistributionEndBlock = _distributions[currentDistributionId].endBlock;

        // check that there isn't currently an active distribution period
        if (block.number <= currentDistributionEndBlock) revert DistributionPeriodStillActive();

        // update Treasury with unused funds from last two distributions
        {
            // Check if any last distribution exists and its challenge stage is over
            if (currentDistributionId > 0 && (block.number > _getChallengeStageEndBlock(currentDistributionEndBlock))) {
                // Add unused funds from last distribution to treasury
                _updateTreasury(currentDistributionId);
            }

            // checks if any second last distribution exist and its unused funds are not added into treasury
            if (currentDistributionId > 1 && !_isSurplusFundsUpdated[currentDistributionId - 1]) {
                // Add unused funds from second last distribution to treasury
                _updateTreasury(currentDistributionId - 1);
            }
        }

        // set the distribution period to start at the current block
        uint48 startBlock = SafeCast.toUint48(block.number);
        uint48 endBlock = startBlock + DISTRIBUTION_PERIOD_LENGTH;

        // set new value for currentDistributionId
        newDistributionId_ = _setNewDistributionId();

        // create QuarterlyDistribution struct
        QuarterlyDistribution storage newDistributionPeriod = _distributions[newDistributionId_];
        newDistributionPeriod.id              = newDistributionId_;
        newDistributionPeriod.startBlock      = startBlock;
        newDistributionPeriod.endBlock        = endBlock;
        uint256 gbc                           = Maths.wmul(treasury, GLOBAL_BUDGET_CONSTRAINT);
        newDistributionPeriod.fundsAvailable  = SafeCast.toUint128(gbc);

        // decrease the treasury by the amount that is held for allocation in the new distribution period
        treasury -= gbc;

        emit QuarterlyDistributionStarted(
            newDistributionId_,
            startBlock,
            endBlock
        );
    }

    /**************************************************/
    /*** Distribution Management Functions Internal ***/
    /**************************************************/

    /**
     * @notice Get the block number at which this distribution period's challenge stage ends.
     * @param  endBlock_ The end block of quarterly distribution to get the challenge stage end block for.
     * @return The block number at which this distribution period's challenge stage ends.
    */
    function _getChallengeStageEndBlock(
        uint256 endBlock_
    ) internal pure returns (uint256) {
        return endBlock_ + CHALLENGE_PERIOD_LENGTH;
    }

    /**
     * @notice Get the block number at which this distribution period's screening stage ends.
     * @param  endBlock_ The end block of quarterly distribution to get the screening stage end block for.
     * @return The block number at which this distribution period's screening stage ends.
    */
    function _getScreeningStageEndBlock(
        uint256 endBlock_
    ) internal pure returns (uint256) {
        return endBlock_ - FUNDING_PERIOD_LENGTH;
    }

    /**
     * @notice Updates Treasury with surplus funds from distribution.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length of at most 10.
     * @param distributionId_ distribution Id of updating distribution 
     */
    function _updateTreasury(
        uint24 distributionId_
    ) private {
        bytes32 fundedSlateHash = _distributions[distributionId_].fundedSlateHash;
        uint256 fundsAvailable  = _distributions[distributionId_].fundsAvailable;

        uint256[] memory fundingProposalIds = _fundedProposalSlates[fundedSlateHash];

        uint256 totalTokensRequested;
        uint256 numFundedProposals = fundingProposalIds.length;

        for (uint i = 0; i < numFundedProposals; ) {
            Proposal memory proposal = _standardFundingProposals[fundingProposalIds[i]];

            totalTokensRequested += proposal.tokensRequested;

            unchecked { ++i; }
        }

        // readd non distributed tokens to the treasury
        treasury += (fundsAvailable - totalTokensRequested);

        _isSurplusFundsUpdated[distributionId_] = true;
    }

    /**
     * @notice Set a new DistributionPeriod Id.
     * @dev    Increments the previous Id nonce by 1.
     * @return newId_ The new distribution period Id.
     */
    function _setNewDistributionId() private returns (uint24 newId_) {
        newId_ = _currentDistributionId += 1;
    }

    /************************************/
    /*** Delegation Rewards Functions ***/
    /************************************/

    /// @inheritdoc IStandardFunding
    function claimDelegateReward(
        uint24 distributionId_
    ) external override returns(uint256 rewardClaimed_) {
        // Revert if delegatee didn't vote in screening stage
        if(screeningVotesCast[distributionId_][msg.sender] == 0) revert DelegateRewardInvalid();

        QuarterlyDistribution memory currentDistribution = _distributions[distributionId_];

        // Check if Challenge Period is still active
        if(block.number < _getChallengeStageEndBlock(currentDistribution.endBlock)) revert ChallengePeriodNotEnded();

        // check rewards haven't already been claimed
        if(hasClaimedReward[distributionId_][msg.sender]) revert RewardAlreadyClaimed();

        QuadraticVoter memory voter = _quadraticVoters[distributionId_][msg.sender];

        // calculate rewards earned for voting
        rewardClaimed_ = _getDelegateReward(currentDistribution, voter);

        hasClaimedReward[distributionId_][msg.sender] = true;

        emit DelegateRewardClaimed(
            msg.sender,
            distributionId_,
            rewardClaimed_
        );

        // transfer rewards to delegatee
        IERC20(ajnaTokenAddress).safeTransfer(msg.sender, rewardClaimed_);
    }

    /**
     * @notice Calculate the delegate rewards that have accrued to a given voter, in a given distribution period.
     * @dev    Voter must have voted in both the screening and funding stages, and is proportional to their share of votes across the stages.
     * @param  currentDistribution_ Struct of the distribution period to calculat rewards for.
     * @param  voter_               Struct of the funding stages voter.
     * @return rewards_             The delegate rewards accrued to the voter.
     */
    function _getDelegateReward(
        QuarterlyDistribution memory currentDistribution_,
        QuadraticVoter memory voter_
    ) internal pure returns (uint256 rewards_) {
        // calculate the total voting power available to the voter that was allocated in the funding stage
        uint256 votingPowerAllocatedByDelegatee = voter_.votingPower - voter_.remainingVotingPower;

        // if none of the voter's voting power was allocated, they receive no rewards
        if (votingPowerAllocatedByDelegatee == 0) return 0;

        // calculate reward
        // delegateeReward = 10 % of GBC distributed as per delegatee Voting power allocated
        rewards_ = Maths.wdiv(
            Maths.wmul(
                currentDistribution_.fundsAvailable,
                votingPowerAllocatedByDelegatee
            ),
            currentDistribution_.fundingVotePowerCast
        ) / 10;
    }

    /***********************************/
    /*** Proposal Functions External ***/
    /***********************************/

    /// @inheritdoc IStandardFunding
    function updateSlate(
        uint256[] calldata proposalIds_,
        uint24 distributionId_
    ) external override returns (bool newTopSlate_) {
        QuarterlyDistribution storage currentDistribution = _distributions[distributionId_];

        // store number of proposals for reduced gas cost of iterations
        uint256 numProposalsInSlate = proposalIds_.length;

        // check the each proposal in the slate is valid, and get the sum of the proposals fundingVotesReceived
        uint256 sum = _validateSlate(distributionId_, currentDistribution.endBlock, currentDistribution.fundsAvailable, proposalIds_, numProposalsInSlate);

        // get pointers for comparing proposal slates
        bytes32 currentSlateHash = currentDistribution.fundedSlateHash;
        bytes32 newSlateHash     = keccak256(abi.encode(proposalIds_));

        // check if slate of proposals is better than the existing slate, and is thus the new top slate
        newTopSlate_ = currentSlateHash == 0 ||
            (currentSlateHash!= 0 && sum > _sumProposalFundingVotes(_fundedProposalSlates[currentSlateHash]));

        // if slate of proposals is new top slate, update state
        if (newTopSlate_) {
            uint256[] storage existingSlate = _fundedProposalSlates[newSlateHash];

            for (uint i = 0; i < numProposalsInSlate; ) {

                // update list of proposals to fund
                existingSlate.push(proposalIds_[i]);

                unchecked { ++i; }
            }

            // update hash to point to the new leading slate of proposals
            currentDistribution.fundedSlateHash = newSlateHash;

            emit FundedSlateUpdated(
                distributionId_,
                newSlateHash
            );
        }
    }

    /// @inheritdoc IStandardFunding
    function executeStandard(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) external nonReentrant override returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(targets_, values_, calldatas_, keccak256(abi.encode(DESCRIPTION_PREFIX_HASH_STANDARD, descriptionHash_)));
        Proposal storage proposal = _standardFundingProposals[proposalId_];

        uint24 distributionId = proposal.distributionId;

        // check that the distribution period has ended, and one week has passed to enable competing slates to be checked
        if (block.number <= _getChallengeStageEndBlock(_distributions[distributionId].endBlock)) revert ExecuteProposalInvalid();

        // check proposal is succesful and hasn't already been executed
        if (!_standardFundingVoteSucceeded(proposalId_) || proposal.executed) revert ProposalNotSuccessful();

        proposal.executed = true;

        _execute(proposalId_, targets_, values_, calldatas_);
    }

    /// @inheritdoc IStandardFunding
    function proposeStandard(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        string memory description_
    ) external override returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(targets_, values_, calldatas_, keccak256(abi.encode(DESCRIPTION_PREFIX_HASH_STANDARD, keccak256(bytes(description_)))));

        Proposal storage newProposal = _standardFundingProposals[proposalId_];

        // check for duplicate proposals
        if (newProposal.proposalId != 0) revert ProposalAlreadyExists();

        QuarterlyDistribution memory currentDistribution = _distributions[_currentDistributionId];

        // cannot add new proposal after end of screening period
        // screening period ends 72000 blocks before end of distribution period, ~ 80 days.
        if (block.number > _getScreeningStageEndBlock(currentDistribution.endBlock)) revert ScreeningPeriodEnded();

        // store new proposal information
        newProposal.proposalId      = proposalId_;
        newProposal.distributionId  = currentDistribution.id;
        newProposal.tokensRequested = _validateCallDatas(targets_, values_, calldatas_); // check proposal parameters are valid and update tokensRequested

        // revert if proposal requested more tokens than are available in the distribution period
        if (newProposal.tokensRequested > (currentDistribution.fundsAvailable * 9 / 10)) revert InvalidProposal();

        emit ProposalCreated(
            proposalId_,
            msg.sender,
            targets_,
            values_,
            new string[](targets_.length),
            calldatas_,
            block.number,
            currentDistribution.endBlock,
            description_
        );
    }

    /***********************************/
    /*** Proposal Functions Internal ***/
    /***********************************/

    /**
     * @notice Check the validity of a potential slate of proposals to execute, and sum the slate's fundingVotesReceived.
     * @dev    Only iterates through a maximum of 10 proposals that made it through both voting stages.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param  distributionId_                   Id of the distribution period to check the slate for.
     * @param  endBlock                          End block of the distribution period.
     * @param  distributionPeriodFundsAvailable_ Funds available for distribution in the distribution period.
     * @param  proposalIds_                      Array of proposal Ids to check.
     * @param  numProposalsInSlate_              Number of proposals in the slate.
     * @return sum_                              The total funding votes received by all proposals in the proposed slate.
     */
    function _validateSlate(uint24 distributionId_, uint256 endBlock, uint256 distributionPeriodFundsAvailable_, uint256[] calldata proposalIds_, uint256 numProposalsInSlate_) internal view returns (uint256 sum_) {
        // check that the function is being called within the challenge period
        if (block.number <= endBlock || block.number > _getChallengeStageEndBlock(endBlock)) {
            revert InvalidProposalSlate();
        }

        // check that the slate has no duplicates
        if (_hasDuplicates(proposalIds_)) revert InvalidProposalSlate();

        uint256 gbc = distributionPeriodFundsAvailable_;
        uint256 totalTokensRequested = 0;

        // check each proposal in the slate is valid
        for (uint i = 0; i < numProposalsInSlate_; ) {
            Proposal memory proposal = _standardFundingProposals[proposalIds_[i]];

            // check if Proposal is in the topTenProposals list
            if (_findProposalIndex(proposalIds_[i], _topTenProposals[distributionId_]) == -1) revert InvalidProposalSlate();

            // account for fundingVotesReceived possibly being negative
            if (proposal.fundingVotesReceived < 0) revert InvalidProposalSlate();

            // update counters
            sum_ += uint128(proposal.fundingVotesReceived); // since we are converting from int128 to uint128, we can safely assume that the value will not overflow
            totalTokensRequested += proposal.tokensRequested;

            // check if slate of proposals exceeded budget constraint ( 90% of GBC )
            if (totalTokensRequested > (gbc * 9 / 10)) {
                revert InvalidProposalSlate();
            }

            unchecked { ++i; }
        }
    }

    /**
     * @notice Check an array of proposalIds for duplicate IDs.
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param  proposalIds_ Array of proposal Ids to check.
     * @return Boolean indicating the presence of a duplicate. True if it has a duplicate; false if not.
     */
    function _hasDuplicates(
        uint256[] calldata proposalIds_
    ) internal pure returns (bool) {
        uint256 numProposals = proposalIds_.length;

        for (uint i = 0; i < numProposals; ) {
            for (uint j = i + 1; j < numProposals; ) {
                if (proposalIds_[i] == proposalIds_[j]) return true;

                unchecked { ++j; }
            }

            unchecked { ++i; }

        }
        return false;
    }

    /**
     * @notice Calculates the sum of funding votes allocated to a list of proposals.
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length of at most 10.
     * @param  proposalIdSubset_ Array of proposal Ids to sum.
     * @return sum_ The sum of the funding votes across the given proposals.
     */
    function _sumProposalFundingVotes(
        uint256[] memory proposalIdSubset_
    ) internal view returns (uint128 sum_) {
        for (uint i = 0; i < proposalIdSubset_.length;) {
            // since we are converting from int128 to uint128, we can safely assume that the value will not overflow
            sum_ += uint128(_standardFundingProposals[proposalIdSubset_[i]].fundingVotesReceived);

            unchecked { ++i; }
        }
    }

    /**
     * @notice Get the current ProposalState of a given proposal.
     * @dev    Used by GrantFund.state() for analytics compatability purposes.
     * @param  proposalId_ The ID of the proposal being checked.
     * @return The proposals status in the ProposalState enum.
     */
    function _standardProposalState(uint256 proposalId_) internal view returns (ProposalState) {
        Proposal memory proposal = _standardFundingProposals[proposalId_];

        if (proposal.executed)                                                     return ProposalState.Executed;
        else if (_distributions[proposal.distributionId].endBlock >= block.number) return ProposalState.Active;
        else if (_standardFundingVoteSucceeded(proposalId_))                      return ProposalState.Succeeded;
        else                                                                       return ProposalState.Defeated;
    }

    /*********************************/
    /*** Voting Functions External ***/
    /*********************************/

    /// @inheritdoc IStandardFunding
    function fundingVote(
        FundingVoteParams[] memory voteParams_
    ) external override returns (uint256 votesCast_) {
        uint24 currentDistributionId = _currentDistributionId;

        QuarterlyDistribution storage currentDistribution = _distributions[currentDistributionId];
        QuadraticVoter        storage voter               = _quadraticVoters[currentDistributionId][msg.sender];

        uint256 endBlock = currentDistribution.endBlock;

        uint256 screeningStageEndBlock = _getScreeningStageEndBlock(endBlock);

        // check that the funding stage is active
        if (block.number <= screeningStageEndBlock || block.number > endBlock) revert InvalidVote();

        uint128 votingPower = voter.votingPower;

        // if this is the first time a voter has attempted to vote this period,
        // set initial voting power and remaining voting power
        if (votingPower == 0) {

            // calculate the voting power available to the voting power in this funding stage
            uint128 newVotingPower = SafeCast.toUint128(_getVotesFunding(msg.sender, votingPower, voter.remainingVotingPower, screeningStageEndBlock));

            voter.votingPower          = newVotingPower;
            voter.remainingVotingPower = newVotingPower;
        }

        uint256 numVotesCast = voteParams_.length;

        for (uint256 i = 0; i < numVotesCast; ) {
            Proposal storage proposal = _standardFundingProposals[voteParams_[i].proposalId];

            // check that the proposal is part of the current distribution period
            if (proposal.distributionId != currentDistributionId) revert InvalidVote();

            // check that the proposal being voted on is in the top ten screened proposals
            if (_findProposalIndex(voteParams_[i].proposalId, _topTenProposals[currentDistributionId]) == -1) revert InvalidVote();

            // cast each successive vote
            votesCast_ += _fundingVote(
                currentDistribution,
                proposal,
                msg.sender,
                voter,
                voteParams_[i]
            );

            unchecked { ++i; }
        }
    }

    /// @inheritdoc IStandardFunding
    function screeningVote(
        ScreeningVoteParams[] memory voteParams_
    ) external override returns (uint256 votesCast_) {
        QuarterlyDistribution memory currentDistribution = _distributions[_currentDistributionId];

        // check screening stage is active
        if (block.number < currentDistribution.startBlock || block.number > _getScreeningStageEndBlock(currentDistribution.endBlock)) revert InvalidVote();

        uint256 numVotesCast = voteParams_.length;

        for (uint256 i = 0; i < numVotesCast; ) {
            Proposal storage proposal = _standardFundingProposals[voteParams_[i].proposalId];

            // check that the proposal is part of the current distribution period
            if (proposal.distributionId != currentDistribution.id) revert InvalidVote();

            uint256 votes = voteParams_[i].votes;

            // cast each successive vote
            votesCast_ += votes;
            _screeningVote(msg.sender, proposal, votes);

            unchecked { ++i; }
        }
    }

    /*********************************/
    /*** Voting Functions Internal ***/
    /*********************************/

    /**
     * @notice Vote on a proposal in the funding stage of the Distribution Period.
     * @dev    Votes can be allocated to multiple proposals, quadratically, for or against.
     * @param  currentDistribution_  The current distribution period.
     * @param  proposal_             The current proposal being voted upon.
     * @param  account_              The voting account.
     * @param  voter_                The voter data struct tracking available votes.
     * @param  voteParams_           The amount of votes being allocated to the proposal. Not squared. If less than 0, vote is against.
     * @return incrementalVotesUsed_ The amount of funding stage votes allocated to the proposal.
     */
    function _fundingVote(
        QuarterlyDistribution storage currentDistribution_,
        Proposal storage proposal_,
        address account_,
        QuadraticVoter storage voter_,
        FundingVoteParams memory voteParams_
    ) internal returns (uint256 incrementalVotesUsed_) {
        uint8  support = 1;
        uint256 proposalId = proposal_.proposalId;

        // determine if voter is voting for or against the proposal
        voteParams_.votesUsed < 0 ? support = 0 : support = 1;

        uint128 votingPower = voter_.votingPower;

        // the total amount of voting power used by the voter before this vote executes
        uint128 voterPowerUsedPreVote = votingPower - voter_.remainingVotingPower;

        FundingVoteParams[] storage votesCast = voter_.votesCast;

        // check that the voter hasn't already voted on a proposal by seeing if it's already in the votesCast array 
        int256 voteCastIndex = _findProposalIndexOfVotesCast(proposalId, votesCast);

        // voter had already cast a funding vote on this proposal
        if (voteCastIndex != -1) {
            // since we are converting from int256 to uint256, we can safely assume that the value will not overflow
            FundingVoteParams storage existingVote = votesCast[uint256(voteCastIndex)];

            // can't change the direction of a previous vote
            if (support == 0 && existingVote.votesUsed > 0 || support == 1 && existingVote.votesUsed < 0) {
                // if the vote is in the opposite direction of a previous vote,
                // and the proposal is already in the votesCast array, revert can't change direction
                revert FundingVoteWrongDirection();
            }
            else {
                // update the votes cast for the proposal
                existingVote.votesUsed += voteParams_.votesUsed;
            }
        }
        // first time voting on this proposal, add the newly cast vote to the voter's votesCast array
        else {
            votesCast.push(voteParams_);
        }

        // calculate the cumulative cost of all votes made by the voter
        // and check that attempted votes cast doesn't overflow uint128
        uint256 sumOfTheSquareOfVotesCast = _sumSquareOfVotesCast(votesCast);
        if (sumOfTheSquareOfVotesCast > type(uint128).max) revert InsufficientVotingPower();
        uint128 cumulativeVotePowerUsed = SafeCast.toUint128(sumOfTheSquareOfVotesCast);

        // check that the voter has enough voting power remaining to cast the vote
        if (cumulativeVotePowerUsed > votingPower) revert InsufficientVotingPower();

        // update voter voting power accumulator
        voter_.remainingVotingPower = votingPower - cumulativeVotePowerUsed;

        // calculate the change in voting power used by the voter in this vote in order to accurately track the total voting power used in the funding stage
        // since we are moving from uint128 to uint256, we can safely assume that the value will not overflow
        uint256 incrementalVotingPowerUsed = uint256(cumulativeVotePowerUsed - voterPowerUsedPreVote);

        // update accumulator for total voting power used in the funding stage in order to calculate delegate rewards
        currentDistribution_.fundingVotePowerCast += incrementalVotingPowerUsed;

        // update proposal vote tracking
        proposal_.fundingVotesReceived += SafeCast.toInt128(voteParams_.votesUsed);

        // the incremental additional votes cast on the proposal to be used as a return value and emit value
        incrementalVotesUsed_ = SafeCast.toUint256(Maths.abs(voteParams_.votesUsed));

        // emit VoteCast instead of VoteCastWithParams to maintain compatibility with Tally
        // emits the amount of incremental votes cast for the proposal, not the voting power cost or total votes on a proposal
        emit VoteCast(
            account_,
            proposalId,
            support,
            incrementalVotesUsed_,
            ""
        );
    }

    /**
     * @notice Vote on a proposal in the screening stage of the Distribution Period.
     * @param account_  The voting account.
     * @param proposal_ The current proposal being voted upon.
     * @param votes_    The amount of votes being cast.
     */
    function _screeningVote(
        address account_,
        Proposal storage proposal_,
        uint256 votes_
    ) internal {
        uint24 distributionId = proposal_.distributionId;

        // check that the voter has enough voting power to cast the vote
        if (screeningVotesCast[distributionId][account_] + votes_ > _getVotesScreening(distributionId, account_)) revert InsufficientVotingPower();

        uint256[] storage currentTopTenProposals = _topTenProposals[distributionId];
        uint256 proposalId = proposal_.proposalId;

        // update proposal votes counter
        proposal_.votesReceived += SafeCast.toUint128(votes_);

        // check if proposal was already screened
        int indexInArray = _findProposalIndex(proposalId, currentTopTenProposals);
        uint256 screenedProposalsLength = currentTopTenProposals.length;

        // check if the proposal should be added to the top ten list for the first time
        if (screenedProposalsLength < 10 && indexInArray == -1) {
            currentTopTenProposals.push(proposalId);

            // sort top ten proposals
            _insertionSortProposalsByVotes(currentTopTenProposals, screenedProposalsLength);
        }
        else {
            // proposal is already in the array
            if (indexInArray != -1) {
                // re-sort top ten proposals to account for new vote totals
                _insertionSortProposalsByVotes(currentTopTenProposals, uint256(indexInArray));
            }
            // proposal isn't already in the array
            else if(_standardFundingProposals[currentTopTenProposals[screenedProposalsLength - 1]].votesReceived < proposal_.votesReceived) {
                // replace the least supported proposal with the new proposal
                currentTopTenProposals.pop();
                currentTopTenProposals.push(proposalId);

                // sort top ten proposals
                _insertionSortProposalsByVotes(currentTopTenProposals, screenedProposalsLength - 1);
            }
        }

        // record voters vote
        screeningVotesCast[proposal_.distributionId][account_] += votes_;

        // emit VoteCast instead of VoteCastWithParams to maintain compatibility with Tally
        emit VoteCast(
            account_,
            proposalId,
            1,
            votes_,
            ""
        );
    }

    /**
     * @notice Identify where in an array of proposalIds the proposal exists.
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param  proposalId_ The proposalId to search for.
     * @param  array_      The array of proposalIds to search.
     * @return index_      The index of the proposalId in the array, else -1.
     */
    function _findProposalIndex(
        uint256 proposalId_,
        uint256[] memory array_
    ) internal pure returns (int256 index_) {
        index_ = -1; // default value indicating proposalId not in the array
        int256 arrayLength = int256(array_.length);

        for (int256 i = 0; i < arrayLength;) {
            //slither-disable-next-line incorrect-equality
            if (array_[uint256(i)] == proposalId_) {
                index_ = i;
                break;
            }

            unchecked { ++i; }
        }
    }

    /**
     * @notice Identify where in an array of FundingVoteParams structs the proposal exists.
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param proposalId_ The proposalId to search for.
     * @param voteParams_ The array of FundingVoteParams structs to search.
     * @return index_ The index of the proposalId in the array, else -1.
     */
    function _findProposalIndexOfVotesCast(
        uint256 proposalId_,
        FundingVoteParams[] memory voteParams_
    ) internal pure returns (int256 index_) {
        index_ = -1; // default value indicating proposalId not in the array

        // since we are converting from uint256 to int256, we can safely assume that the value will not overflow
        int256 numVotesCast = int256(voteParams_.length);
        for (int256 i = 0; i < numVotesCast; ) {
            //slither-disable-next-line incorrect-equality
            if (voteParams_[uint256(i)].proposalId == proposalId_) {
                index_ = i;
                break;
            }

            unchecked { ++i; }
        }
    }

    /**
     * @notice Sort the 10 proposals which will make it through screening and move on to the funding round.
     * @dev    Implements the descending insertion sort algorithm.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @dev    Since we are converting from int256 to uint256, we can safely assume that the values will not overflow.
     * @param proposals_        The array of proposals to sort by votes received.
     * @param targetProposalId_ The targeted proposal id to insert.
     */
    function _insertionSortProposalsByVotes(
        uint256[] storage proposals_,
        uint256 targetProposalId_
    ) internal {
        while (
            targetProposalId_ != 0
            &&
            _standardFundingProposals[proposals_[targetProposalId_]].votesReceived > _standardFundingProposals[proposals_[targetProposalId_ - 1]].votesReceived
        ) {
            // swap values if left item < right item
            uint256 temp = proposals_[targetProposalId_ - 1];

            proposals_[targetProposalId_ - 1] = proposals_[targetProposalId_];
            proposals_[targetProposalId_] = temp;

            unchecked { --targetProposalId_; }
        }
    }

    /**
     * @notice Sum the square of each vote cast by a voter.
     * @dev    Used to calculate if a voter has enough voting power to cast their votes.
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param  votesCast_           The array of votes cast by a voter.
     * @return votesCastSumSquared_ The sum of the square of each vote cast.
     */
    function _sumSquareOfVotesCast(
        FundingVoteParams[] memory votesCast_
    ) internal pure returns (uint256 votesCastSumSquared_) {
        uint256 numVotesCast = votesCast_.length;

        for (uint256 i = 0; i < numVotesCast; ) {
            votesCastSumSquared_ += Maths.wpow(SafeCast.toUint256(Maths.abs(votesCast_[i].votesUsed)), 2);

            unchecked { ++i; }
        }
    }

    /**
     * @notice Check to see if a proposal is in the current funded slate hash of proposals.
     * @param  proposalId_ The proposalId to check.
     * @return             True if the proposal is in the it's distribution period's slate hash.
     */
    function _standardFundingVoteSucceeded(
        uint256 proposalId_
    ) internal view returns (bool) {
        uint24 distributionId = _standardFundingProposals[proposalId_].distributionId;
        return _findProposalIndex(proposalId_, _fundedProposalSlates[_distributions[distributionId].fundedSlateHash]) != -1;
    }

    /**
     * @notice Retrieve the number of votes available to an account in the current screening stage.
     * @param  account_ The account to retrieve votes for.
     * @return votes_   The number of votes available to an account in this screening stage.
     */
    function _getVotesScreening(uint24 distributionId_, address account_) internal view returns (uint256 votes_) {
        uint256 startBlock = _distributions[distributionId_].startBlock;

        // calculate voting weight based on the number of tokens held at the snapshot blocks of the screening stage
        votes_ = _getVotesAtSnapshotBlocks(
            account_,
            startBlock - VOTING_POWER_SNAPSHOT_DELAY,
            startBlock
        );
    }

    /**
     * @notice Retrieve the number of votes available to an account in the current funding stage.
     * @param  account_                The address of the voter to check.
     * @param  votingPower_            The voter's voting power in the funding round. Equal to the square of their tokens in the voting snapshot.
     * @param  remainingVotingPower_   The voter's remaining quadratic voting power in the given distribution period's funding round.
     * @param  screeningStageEndBlock_ The block number at which the screening stage ends.
     * @return votes_          The number of votes available to an account in this funding stage.
     */
    function _getVotesFunding(
        address account_,
        uint256 votingPower_,
        uint256 remainingVotingPower_,
        uint256 screeningStageEndBlock_
    ) internal view returns (uint256 votes_) {
        // voter has already allocated some of their budget this period
        if (votingPower_ != 0) {
            votes_ = remainingVotingPower_;
        }
        // voter hasn't yet called _castVote in this period
        else {
            votes_ = Maths.wpow(
            _getVotesAtSnapshotBlocks(
                account_,
                screeningStageEndBlock_ - VOTING_POWER_SNAPSHOT_DELAY,
                screeningStageEndBlock_
            ), 2);
        }
    }

    /*******************************/
    /*** External View Functions ***/
    /*******************************/

    /// @inheritdoc IStandardFunding
    function getDelegateReward(
        uint24 distributionId_,
        address voter_
    ) external view override returns (uint256 rewards_) {
        QuarterlyDistribution memory currentDistribution = _distributions[distributionId_];
        QuadraticVoter        memory voter               = _quadraticVoters[distributionId_][voter_];

        rewards_ = _getDelegateReward(currentDistribution, voter);
    }

    /// @inheritdoc IStandardFunding
    function getDistributionId() external view override returns (uint24) {
        return _currentDistributionId;
    }

    /// @inheritdoc IStandardFunding
    function getDistributionPeriodInfo(
        uint24 distributionId_
    ) external view override returns (uint24, uint48, uint48, uint128, uint256, bytes32) {
        return (
            _distributions[distributionId_].id,
            _distributions[distributionId_].startBlock,
            _distributions[distributionId_].endBlock,
            _distributions[distributionId_].fundsAvailable,
            _distributions[distributionId_].fundingVotePowerCast,
            _distributions[distributionId_].fundedSlateHash
        );
    }

    /// @inheritdoc IStandardFunding
    function getFundedProposalSlate(
        bytes32 slateHash_
    ) external view override returns (uint256[] memory) {
        return _fundedProposalSlates[slateHash_];
    }

    /// @inheritdoc IStandardFunding
    function getFundingPowerVotes(
        uint256 votingPower_
    ) external pure override returns (uint256) {
        return Maths.wsqrt(votingPower_);
    }

    /// @inheritdoc IStandardFunding
    function getFundingVotesCast(uint24 distributionId_, address account_) external view override returns (FundingVoteParams[] memory) {
        return _quadraticVoters[distributionId_][account_].votesCast;
    }

    /// @inheritdoc IStandardFunding
    function getProposalInfo(
        uint256 proposalId_
    ) external view override returns (uint256, uint24, uint128, uint128, int128, bool) {
        return (
            _standardFundingProposals[proposalId_].proposalId,
            _standardFundingProposals[proposalId_].distributionId,
            _standardFundingProposals[proposalId_].votesReceived,
            _standardFundingProposals[proposalId_].tokensRequested,
            _standardFundingProposals[proposalId_].fundingVotesReceived,
            _standardFundingProposals[proposalId_].executed
        );
    }

    /// @inheritdoc IStandardFunding
    function getSlateHash(
        uint256[] calldata proposalIds_
    ) external pure override returns (bytes32) {
        return keccak256(abi.encode(proposalIds_));
    }

    /// @inheritdoc IStandardFunding
    function getTopTenProposals(
        uint24 distributionId_
    ) external view override returns (uint256[] memory) {
        return _topTenProposals[distributionId_];
    }

    /// @inheritdoc IStandardFunding
    function getVoterInfo(
        uint24 distributionId_,
        address account_
    ) external view override returns (uint128, uint128, uint256) {
        return (
            _quadraticVoters[distributionId_][account_].votingPower,
            _quadraticVoters[distributionId_][account_].remainingVotingPower,
            _quadraticVoters[distributionId_][account_].votesCast.length
        );
    }

    /// @inheritdoc IStandardFunding
    function getVotesFunding(
        uint24 distributionId_,
        address account_
    ) external view override returns (uint256 votes_) {
        QuarterlyDistribution memory currentDistribution = _distributions[distributionId_];
        QuadraticVoter        memory voter               = _quadraticVoters[currentDistribution.id][account_];

        uint256 screeningStageEndBlock = _getScreeningStageEndBlock(currentDistribution.endBlock);

        votes_ = _getVotesFunding(account_, voter.votingPower, voter.remainingVotingPower, screeningStageEndBlock);
    }

    /// @inheritdoc IStandardFunding
    function getVotesScreening(
        uint24 distributionId_,
        address account_
    ) external view override returns (uint256 votes_) {
        votes_ = _getVotesScreening(distributionId_, account_);
    }

}

// SPDX-License-Identifier: MIT

//slither-disable-next-line solc-version
pragma solidity 0.8.16;

/**
 * @title Ajna Grant Coordination Fund Standard Proposal flow.
 */
interface IStandardFunding {

    /**************/
    /*** Errors ***/
    /**************/

    /**
     * @notice User attempted to execute a proposal before the distribution period ended.
     */
     error DistributionPeriodStillActive();

    /**
     * @notice User attempted to execute a proposal before the distribution period ended.
     */
     error ExecuteProposalInvalid();

    /**
     * @notice User attempted to change the direction of a subsequent funding vote on the same proposal.
     */
    error FundingVoteWrongDirection();

    /**
     * @notice User attempted to vote with more voting power than was available to them.
     */
    error InsufficientVotingPower();

    /**
     * @notice Delegatee attempted to claim delegate reward before the challenge period ended.
     */
    error ChallengePeriodNotEnded();

    /**
     * @notice User provided a slate of proposalIds that is invalid.
     */
    error InvalidProposalSlate();

    /**
     * @notice Delegatee attempted to claim delegate reward when not voted in screening.
     */
    error DelegateRewardInvalid();

    /**
     * @notice User attempted to vote on a proposal outside of the current distribution period.
     */
    error InvalidVote();

    /**
     * @notice User attempted to propose after screening period ended
     */
    error ScreeningPeriodEnded();

    /**
     * @notice User attempted to Claim delegate reward again
     */
    error RewardAlreadyClaimed();

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @notice Emitted when a new top ten slate is submitted and set as the leading optimized slate.
     *  @param  distributionId  Id of the distribution period.
     *  @param  fundedSlateHash Hash of the proposals to be funded.
     */
    event FundedSlateUpdated(
        uint256 indexed distributionId,
        bytes32 indexed fundedSlateHash
    );

    /**
     *  @notice Emitted at the beginning of a new quarterly distribution period.
     *  @param  distributionId Id of the new distribution period.
     *  @param  startBlock     Block number of the quarterly distrubtions start.
     *  @param  endBlock       Block number of the quarterly distrubtions end.
     */
    event QuarterlyDistributionStarted(
        uint256 indexed distributionId,
        uint256 startBlock,
        uint256 endBlock
    );

    /**
     *  @notice Emitted when delegatee claims his rewards.
     *  @param  delegateeAddress Address of delegatee.
     *  @param  distributionId   Id of distribution period.
     *  @param  rewardClaimed    Amount of Reward Claimed.
     */
    event DelegateRewardClaimed(
        address indexed delegateeAddress,
        uint256 indexed distributionId,
        uint256 rewardClaimed
    );

    /***************/
    /*** Structs ***/
    /***************/

    /**
     * @notice Contains proposals that made it through the screening process to the funding stage.
     */
    struct QuarterlyDistribution {
        uint24  id;                   // id of the current quarterly distribution
        uint48  startBlock;           // block number of the quarterly distributions start
        uint48  endBlock;             // block number of the quarterly distributions end
        uint128 fundsAvailable;       // maximum fund (including delegate reward) that can be taken out that quarter
        uint256 fundingVotePowerCast; // total number of voting power allocated in funding stage that quarter
        bytes32 fundedSlateHash;      // hash of list of proposals to fund
    }

    /**
     * @notice Contains information about proposals in a distribution period.
     */
    struct Proposal {
        uint256 proposalId;           // OZ.Governor compliant proposalId. Hash of proposeStandard inputs
        uint24  distributionId;       // Id of the distribution period in which the proposal was made
        bool    executed;             // whether the proposal has been executed
        uint128 votesReceived;        // accumulator of screening votes received by a proposal
        uint128 tokensRequested;      // number of Ajna tokens requested in the proposal
        int128  fundingVotesReceived; // accumulator of funding votes allocated to the proposal.
    }

    /**
     * @notice Contains information about voters during a vote made by a QuadraticVoter in the Funding stage of a distribution period.
     */
    struct FundingVoteParams {
        uint256 proposalId;
        int256 votesUsed;
    }

    /**
     * @notice Contains information about voters during a vote made during the Screening stage of a distribution period.
     * @dev    Used in screeningVoteMulti().
     */
    struct ScreeningVoteParams {
        uint256 proposalId; // the proposal being voted on
        uint256 votes;      // the number of votes to allocate to the proposal
    }

    /**
     * @notice Contains information about voters during a distribution period's funding stage.
     */
    struct QuadraticVoter {
        uint128 votingPower;           // amount of votes originally available to the voter, equal to the sum of the square of their initial votes
        uint128 remainingVotingPower;  // remaining voting power in the given period
        FundingVoteParams[] votesCast; // array of votes cast by the voter
    }

    /*****************************************/
    /*** Distribution Management Functions ***/
    /*****************************************/

    /**
     * @notice Start a new Distribution Period and reset appropriate state.
     * @dev    Can be kicked off by anyone assuming a distribution period isn't already active.
     * @return newDistributionId_ The new distribution period Id.
     */
    function startNewDistributionPeriod() external returns (uint24 newDistributionId_);

    /************************************/
    /*** Delegation Rewards Functions ***/
    /************************************/

    /**
     * @notice distributes delegate reward based on delegatee Vote share.
     * @dev Can be called by anyone who has voted in both screening and funding period.
     * @param  distributionId_ Id of distribution from whinch delegatee wants to claim his reward.
     * @return rewardClaimed_  Amount of reward claimed by delegatee.
     */
    function claimDelegateReward(
        uint24 distributionId_
    ) external returns(uint256 rewardClaimed_);

    /**************************/
    /*** Proposal Functions ***/
    /**************************/

    /**
     * @notice Execute a proposal that has been approved by the community.
     * @dev    Calls out to Governor.execute().
     * @dev    Check for proposal being succesfully funded or previously executed is handled by Governor.execute().
     * @param  targets_         List of contracts the proposal calldata will interact with. Should be the Ajna token contract for all proposals.
     * @param  values_          List of values to be sent with the proposal calldata. Should be 0 for all proposals.
     * @param  calldatas_       List of calldata to be executed. Should be the transfer() method.
     * @param  descriptionHash_ Hash of proposal's description string.
     * @return proposalId_      The id of the executed proposal.
     */
     function executeStandard(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) external returns (uint256 proposalId_);

    /**
     * @notice Submit a new proposal to the Grant Coordination Fund Standard Funding mechanism.
     * @dev    All proposals can be submitted by anyone. There can only be one value in each array. Interface inherits from OZ.propose().
     * @param  targets_     List of contracts the proposal calldata will interact with. Should be the Ajna token contract for all proposals.
     * @param  values_      List of values to be sent with the proposal calldata. Should be 0 for all proposals.
     * @param  calldatas_   List of calldata to be executed. Should be the transfer() method.
     * @param  description_ Proposal's description string.
     * @return proposalId_  The id of the newly created proposal.
     */
    function proposeStandard(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        string memory description_
    ) external returns (uint256 proposalId_);

    /**
     * @notice Check if a slate of proposals meets requirements, and maximizes votes. If so, update QuarterlyDistribution.
     * @param  proposalIds_    Array of proposal Ids to check.
     * @param  distributionId_ Id of the current quarterly distribution.
     * @return newTopSlate_    Boolean indicating whether the new proposal slate was set as the new top slate for distribution.
     */
    function updateSlate(
        uint256[] calldata proposalIds_,
        uint24 distributionId_
    ) external returns (bool newTopSlate_);

    /************************/
    /*** Voting Functions ***/
    /************************/

    /**
     * @notice Cast an array of funding votes in one transaction.
     * @dev    Calls out to StandardFunding._fundingVote().
     * @dev    Only iterates through a maximum of 10 proposals that made it through the screening round.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param voteParams_ The array of votes on proposals to cast.
     * @return votesCast_ The total number of votes cast across all of the proposals.
     */
    function fundingVote(
        FundingVoteParams[] memory voteParams_
    ) external returns (uint256 votesCast_);

    /**
     * @notice Cast an array of screening votes in one transaction.
     * @dev    Calls out to StandardFunding._screeningVote().
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param  voteParams_ The array of votes on proposals to cast.
     * @return votesCast_  The total number of votes cast across all of the proposals.
     */
    function screeningVote(
        ScreeningVoteParams[] memory voteParams_
    ) external returns (uint256 votesCast_);

    /**********************/
    /*** View Functions ***/
    /**********************/

    /**
     * @notice Retrieve the delegate reward accrued to a voter in a given distribution period.
     * @param  distributionId_ The  to calculate rewards for.
     * @param  voter_          The address of the voter to calculate rewards for.
     * @return rewards_        The rewards earned by the voter for voting in that distribution period.
     */
    function getDelegateReward(
        uint24 distributionId_,
        address voter_
    ) external view returns (uint256 rewards_);

    /**
     * @notice Retrieve the current QuarterlyDistribution distributionId.
     * @return The current distributionId.
     */
    function getDistributionId() external view returns (uint24);

    /**
     * @notice Mapping of distributionId to {QuarterlyDistribution} struct.
     * @param  distributionId_      The distributionId to retrieve the QuarterlyDistribution struct for.
     * @return distributionId       The retrieved struct's distributionId.
     * @return startBlock           The block number of the distribution period's start.
     * @return endBlock             The block number of the distribution period's end.
     * @return fundsAvailable       The maximum amount of funds that can be taken out of the distribution period.
     * @return fundingVotePowerCast The total number of votes cast in the distribution period's funding round.
     * @return fundedSlateHash      The slate hash of the proposals that were funded.
     */
    function getDistributionPeriodInfo(
        uint24 distributionId_
    ) external view returns (uint24, uint48, uint48, uint128, uint256, bytes32);

    /**
     * @notice Get the funded proposal slate for a given distributionId, and slate hash
     * @param  slateHash_      The slateHash to retrieve the funded proposals from.
     * @return                 The array of proposalIds that are in the funded slate hash.
     */
    function getFundedProposalSlate(
        bytes32 slateHash_
    ) external view returns (uint256[] memory);

    /**
     * @notice Get the number of discrete votes that can be cast on proposals given a specified voting power.
     * @dev    This is calculated by taking the square root of the voting power, and adjusting for WAD decimals.
     * @dev    This approach results in precision loss, and prospective users should be careful.
     * @param  votingPower_ The provided voting power to calculate discrete votes for.
     * @return The square root of the votingPower as a WAD.
     */
    function getFundingPowerVotes(
        uint256 votingPower_
    ) external pure returns (uint256);

    /**
     * @notice Get the list of funding votes cast by an account in a given distribution period.
     * @param  distributionId_   The distributionId of the distribution period to check.
     * @param  account_          The address of the voter to check.
     * @return FundingVoteParams The list of FundingVoteParams structs that have been succesfully cast the voter.
     */
    function getFundingVotesCast(uint24 distributionId_, address account_) external view returns (FundingVoteParams[] memory);

    /**
     * @notice Mapping of proposalIds to {Proposal} structs.
     * @param  proposalId_       The proposalId to retrieve the Proposal struct for.
     * @return proposalId        The retrieved struct's proposalId.
     * @return distributionId    The distributionId in which the proposal was submitted.
     * @return votesReceived     The amount of votes the proposal has received in it's distribution period's screening round.
     * @return tokensRequested   The amount of tokens requested by the proposal.
     * @return qvBudgetAllocated The amount of quadratic vote budget allocated to the proposal in it's distribution period's funding round.
     * @return executed          True if the proposal has been executed.
     */
    function getProposalInfo(
        uint256 proposalId_
    ) external view returns (uint256, uint24, uint128, uint128, int128, bool);

    /**
     * @notice Generate a unique hash of a list of proposal Ids for usage as a key for comparing proposal slates.
     * @param  proposalIds_ Array of proposal Ids to hash.
     * @return Bytes32      Hash of the list of proposals.
     */
    function getSlateHash(
        uint256[] calldata proposalIds_
    ) external pure returns (bytes32);

    /**
     * @notice Retrieve the top ten proposals that have received the most votes in a given distribution period's screening round.
     * @dev    It may return less than 10 proposals if less than 10 have been submitted. 
     * @dev    Values are subject to change if the queried distribution period's screening round is ongoing.
     * @param  distributionId_ The distributionId of the distribution period to query.
     * @return topTenProposals Array of the top ten proposal's proposalIds.
     */
    function getTopTenProposals(
        uint24 distributionId_
    ) external view returns (uint256[] memory);

    /**
     * @notice Get the current state of a given voter in the funding stage.
     * @param  distributionId_ The distributionId of the distribution period to check.
     * @param  account_        The address of the voter to check.
     * @return votingPower          The voter's voting power in the funding round. Equal to the square of their tokens in the voting snapshot.
     * @return remainingVotingPower The voter's remaining quadratic voting power in the given distribution period's funding round.
     * @return votesCast            The voter's number of proposals voted on in the funding stage.
     */
    function getVoterInfo(
        uint24 distributionId_,
        address account_
    ) external view returns (uint128, uint128, uint256);

    /**
     * @notice Get the remaining quadratic voting power available to the voter in the funding stage of a distribution period.
     * @dev    This value will be the square of the voter's token balance at the snapshot blocks.
     * @param  distributionId_ The distributionId of the distribution period to check.
     * @param  account_        The address of the voter to check.
     * @return votes_          The voter's remaining quadratic voting power.
     */
    function getVotesFunding(uint24 distributionId_, address account_) external view returns (uint256 votes_);

    /**
     * @notice Get the voter's voting power in the screening stage of a distribution period.
     * @param  distributionId_ The distributionId of the distribution period to check.
     * @param  account_        The address of the voter to check.
     * @return votes_           The voter's voting power.
     */
    function getVotesScreening(uint24 distributionId_, address account_) external view returns (uint256 votes_);

}

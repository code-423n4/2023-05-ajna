// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console } from "@std/console.sol";
import { Test }     from "forge-std/Test.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { Strings }  from "@oz/utils/Strings.sol";

import { GrantFund }        from "../../../src/grants/GrantFund.sol";
import { IStandardFunding } from "../../../src/grants/interfaces/IStandardFunding.sol";
import { Maths }            from "../../../src/grants/libraries/Maths.sol";

import { IAjnaToken }          from "../../utils/IAjnaToken.sol";
import { GrantFundTestHelper } from "../../utils/GrantFundTestHelper.sol";
import { Handler }             from "./Handler.sol";

contract StandardHandler is Handler {

    // proposalId of proposals executed
    uint256[] public proposalsExecuted;

    // number of proposals that recieved a vote in the given stage
    uint256 public screeningVotesCast;
    uint256 public fundingVotesCast;

    // time counter
    uint256 private systemTime = 0;

    struct VotingActor {
        IStandardFunding.FundingVoteParams[] fundingVotes;
        IStandardFunding.ScreeningVoteParams[] screeningVotes;
        uint256 delegationRewardsClaimed;
    }

    struct DistributionState {
        bytes32 currentTopSlate;
        Slate[] topSlates; // assume that the last element in the list is the top slate
    }

    struct Slate {
        uint24 distributionId;
        uint256 updateBlock;
        bytes32 slateHash;
    }

    // list of submitted standard funding proposals by distribution period
    // distributionId => proposalId[]
    mapping(uint24 => uint256[]) public standardFundingProposals;

    mapping(uint24 => DistributionState) public distributionStates;
    mapping(bytes32 => uint256[]) public proposalsInTopSlate;
    mapping(address => mapping(uint24 => VotingActor)) internal votingActors; // actor => distributionId => VotingActor
    mapping(uint256 => TestProposal) public testProposals;

    constructor(
        address payable grantFund_,
        address token_,
        address tokenDeployer_,
        uint256 numOfActors_,
        uint256 tokensToDistribute_,
        address testContract_
    ) Handler(grantFund_, token_, tokenDeployer_, numOfActors_, tokensToDistribute_, testContract_) {}

    /*************************/
    /*** Wrapped Functions ***/
    /*************************/

    function startNewDistributionPeriod(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) returns (uint24 newDistributionId_) {
        numberOfCalls['SFH.startNewDistributionPeriod']++;
        systemTime++;

        try _grantFund.startNewDistributionPeriod() returns (uint24 newDistributionId) {
            newDistributionId_ = newDistributionId;
            vm.roll(block.number + 100);
            vm.rollFork(block.number + 100);
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("DistributionPeriodStillActive()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function proposeStandard(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.proposeStandard']++;
        systemTime++;

        // get a random number between 1 and 5
        uint256 numProposalParams = constrictToRange(randomSeed(), 1, 5);

        // generate list of recipients and tokens requested
        TestProposalParams[] memory testProposalParams = generateTestProposalParams(numProposalParams);

        // generate proposal params
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = generateProposalParams(address(_ajna), testProposalParams);

        try _grantFund.proposeStandard(targets, values, calldatas, description) returns (uint256 proposalId) {
            standardFundingProposals[_grantFund.getDistributionId()].push(proposalId);
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("ProposalAlreadyExists()")) ||
                err == keccak256(abi.encodeWithSignature("ScreeningPeriodEnded()")) ||
                err == keccak256(abi.encodeWithSignature("InvalidProposal()")),
                UNEXPECTED_REVERT
            );
        }

    }

    function screeningVote(uint256 actorIndex_, uint256 proposalsToVoteOn_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.screeningVote']++;
        systemTime++;

        uint24 distributionId = _grantFund.getDistributionId();

        // get a random number less than the number of submitted proposals
        proposalsToVoteOn_ = constrictToRange(proposalsToVoteOn_, 0, standardFundingProposals[distributionId].length);

        vm.roll(block.number + 100);
        // vm.rollFork(block.number + 100);

        // get actor voting power
        uint256 votingPower = _grantFund.getVotesScreening(_grantFund.getDistributionId(), _actor);

        // construct vote params
        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](proposalsToVoteOn_);
        for (uint256 i = 0; i < proposalsToVoteOn_; i++) {
            // get a random proposal
            uint256 proposalId = randomProposal();

            // generate screening vote params
            screeningVoteParams[i] = IStandardFunding.ScreeningVoteParams({
                proposalId: proposalId,
                votes: constrictToRange(randomSeed(), 0, votingPower) // FIXME: account for previously used voting power
            });
        }

        try _grantFund.screeningVote(screeningVoteParams) {
            // update actor screeningVotes if vote was successful
            VotingActor storage actor = votingActors[_actor][distributionId];

            for (uint256 i = 0; i < proposalsToVoteOn_; ) {
                actor.screeningVotes.push(screeningVoteParams[i]);
                screeningVotesCast++;

                ++i;
            }
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("InvalidVote()")) ||
                err == keccak256(abi.encodeWithSignature("InsufficientVotingPower()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function fundingVote(uint256 actorIndex_, uint256 proposalsToVoteOn_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.fundingVote']++;
        systemTime++;

        // check where block is in the distribution period
        uint24 distributionId = _grantFund.getDistributionId();
        (, , uint256 endBlock, , , ) = _grantFund.getDistributionPeriodInfo(distributionId);
        if (block.number < endBlock - 72000) {
                return;
        }

        // bind proposalsToVoteOn_ to the number of proposals
        proposalsToVoteOn_ = bound(proposalsToVoteOn_, 0, standardFundingProposals[distributionId].length);

        // TODO: make happy / chaotic path decision random / dynamic?
        // get the fundingVoteParams for the votes the actor is about to cast
        // take the chaotic path, and cast votes that will likely exceed the actor's voting power
        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = _fundingVoteParams(_actor, proposalsToVoteOn_, false);

        try _grantFund.fundingVote(fundingVoteParams) returns (uint256 votesCast) {
            numberOfCalls['SFH.fundingVote.success']++;

            // TODO: can a proposal have 0 votes cast?
            // assertGt(votesCast, 0);

            // check votesCast is equal to the sum of votes cast
            assertEq(votesCast, SafeCast.toUint256(sumFundingVotes(fundingVoteParams)));

            // update actor funding votes counts
            // find and replace previous vote record for that proposlId, in that distributonId
            VotingActor storage actor = votingActors[_actor][distributionId];
            for (uint256 i = 0; i < proposalsToVoteOn_; ) {

                // update existing proposal voting record as opposed to a new entry in the list
                int256 voteCastIndex = _findProposalIndexOfVotesCast(fundingVoteParams[i].proposalId, actor.fundingVotes);
                // voter had already cast a funding vote on this proposal
                if (voteCastIndex != -1) {
                    actor.fundingVotes[uint256(voteCastIndex)].votesUsed += fundingVoteParams[i].votesUsed;
                }
                else {
                    actor.fundingVotes.push(fundingVoteParams[i]);
                }

                fundingVotesCast++;

                ++i;
            }

        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("InvalidVote()")) ||
                err == keccak256(abi.encodeWithSignature("InsufficientVotingPower()")) ||
                err == keccak256(abi.encodeWithSignature("FundingVoteWrongDirection()")),
                UNEXPECTED_REVERT
            );
        }
    }

    // FIXME: can a proposal slate have no proposals?
    function updateSlate(uint256 actorIndex_, uint256 proposalSeed) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.updateSlate']++;
        systemTime++;

        // check that the distribution period ended
        if (keccak256(getStage()) != keccak256(bytes("Challenge"))) {
            return;
        }

        // if (systemTime > 2800) {
        //     return;
        // }

        uint256 potentialSlateLength = constrictToRange(proposalSeed, 0, 10);
        uint24 distributionId = _grantFund.getDistributionId();

        // get top ten proposals
        uint256[] memory topTen = _grantFund.getTopTenProposals(distributionId);
        // construct potential slate of proposals
        uint256[] memory potentialSlate = new uint256[](potentialSlateLength);

        bool happyPath = true;

        if (happyPath) {
            // get subset of top ten in order
            for (uint i = 0; i < potentialSlateLength; ++i) {
                potentialSlate[i] = topTen[i];
            }
        }
        else {
            // get random potentialSlate of proposals, may contain duplicates
            for (uint i = 0; i < potentialSlateLength; ++i) {
                potentialSlate[i] = topTen[randomSeed() % 10];
            }
        }

        try _grantFund.updateSlate(potentialSlate, distributionId) returns (bool newTopSlate) {
            numberOfCalls['SFH.updateSlate.called']++;
            if (newTopSlate) {
                numberOfCalls['SFH.updateSlate.success']++;

                bytes32 potentialSlateHash = keccak256(abi.encode(potentialSlate));

                Slate memory slate;
                slate.distributionId = distributionId;
                slate.slateHash = potentialSlateHash;
                slate.updateBlock = block.number;

                // update distribution state
                DistributionState storage distribution = distributionStates[distributionId];
                distribution.currentTopSlate = potentialSlateHash;
                distribution.topSlates.push(slate);

                // update list of proposals in top slate
                for (uint i = 0; i < potentialSlateLength; ++i) {
                    proposalsInTopSlate[distribution.currentTopSlate].push(potentialSlate[i]);
                }
            }
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("InvalidProposalSlate()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function executeStandard(uint256 actorIndex_, uint256 proposalToExecute_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.executeStandard']++;
        systemTime++;

        uint24 distributionId = _grantFund.getDistributionId();

        (, , uint256 endBlock, , , bytes32 topSlateHash) = _grantFund.getDistributionPeriodInfo(distributionId);

        if (systemTime >= 500) {
            // skip time to the end of the challenge stage
            vm.roll(endBlock + 50401);
        }

        if (block.number <= endBlock + 50400) return;

        // get a proposal from the current top ten slate
        uint256[] memory topSlateProposalIds = _grantFund.getFundedProposalSlate(topSlateHash);

        if (topSlateProposalIds.length == 0) return;

        uint256 proposalIndex = constrictToRange(proposalToExecute_, 1, topSlateProposalIds.length) -1;

        TestProposal memory proposal = testProposals[topSlateProposalIds[proposalIndex]];

        try _grantFund.executeStandard(proposal.targets, proposal.values, proposal.calldatas, keccak256(bytes(proposal.description))) returns (uint256 proposalId_) {
            assertEq(proposalId_, proposal.proposalId);
            numberOfCalls['SFH.executeStandard.success']++;
            proposalsExecuted.push(proposalId_);
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("ExecuteProposalInvalid()")) ||
                err == keccak256(abi.encodeWithSignature("ProposalNotSuccessful()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function claimDelegateReward(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['SFH.claimDelegateReward']++;
        systemTime++;

        uint24 distributionId = _grantFund.getDistributionId();

        (, , uint256 endBlock, , , ) = _grantFund.getDistributionPeriodInfo(distributionId);

        if (systemTime >= 900) {
            // skip time to the end of the challenge stage
            vm.roll(endBlock + 50401);
        }

        try _grantFund.claimDelegateReward(distributionId) returns (uint256 rewardClaimed_) {
            numberOfCalls['SFH.claimDelegateReward.success']++;

            // should only be able to claim delegation rewards once
            assertEq(votingActors[_actor][distributionId].delegationRewardsClaimed, 0);

            // rewards should be non zero
            assertTrue(rewardClaimed_ > 0);

            // record the newly claimed rewards
            votingActors[_actor][distributionId].delegationRewardsClaimed = rewardClaimed_;
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("DelegateRewardInvalid()"))   ||
                err == keccak256(abi.encodeWithSignature("ChallengePeriodNotEnded()")) ||
                err == keccak256(abi.encodeWithSignature("RewardAlreadyClaimed()")),
                UNEXPECTED_REVERT
            );
        }
    }

    /**********************************/
    /*** External Utility Functions ***/
    /**********************************/

    // create a given number of proposals
    function createProposals(uint256 numProposals) external returns (uint256[] memory proposalIds_) {
        proposalIds_ = _createProposals(numProposals);
    }

    // make each actor cast funding stage votes on a random number of proposals
    function fundingVoteProposals() external {
        for (uint256 i = 0; i < actors.length; ++i) {
            // get an actor who hasn't already voted
            address actor = actors[i];

            // actor votes on random number of proposals
            _fundingVoteProposal(actor, constrictToRange(randomSeed(), 1, 10));
        }
    }

    // make each actor cast screening stage votes on a random number of proposals
    function screeningVoteProposals() external {
        for (uint256 i = 0; i < actors.length; ++i) {
            // get an actor who hasn't already voted
            address actor = actors[i];

            // actor votes on random number of proposals
            _screeningVoteProposal(actor);
        }
    }

    function sumSquareOfVotesCast(
        IStandardFunding.FundingVoteParams[] memory votesCast_
    ) public pure returns (uint256 votesCastSumSquared_) {
        uint256 numVotesCast = votesCast_.length;

        for (uint256 i = 0; i < numVotesCast; ) {
            votesCastSumSquared_ += Maths.wpow(SafeCast.toUint256(Maths.abs(votesCast_[i].votesUsed)), 2);

            unchecked { ++i; }
        }
    }

    /**********************************/
    /*** Internal Utility Functions ***/
    /**********************************/

    function generateTestProposalParams(uint256 numParams_) internal returns (TestProposalParams[] memory testProposalParams_) {
        testProposalParams_ = new TestProposalParams[](numParams_);

        uint256 totalTokensRequested = 0;
        for (uint256 i = 0; i < numParams_; ++i) {
            // get distribution info
            uint24 distributionId = _grantFund.getDistributionId();
            (, , , uint128 fundsAvailable, , ) = _grantFund.getDistributionPeriodInfo(distributionId);

            // account for amount that was previously requested
            uint256 additionalTokensRequested = randomAmount((fundsAvailable * 9 /10) - totalTokensRequested);
            totalTokensRequested += additionalTokensRequested;

            testProposalParams_[i] = TestProposalParams({
                recipient: randomActor(),
                tokensRequested: additionalTokensRequested
            });
        }
    }

    function randomProposal() internal returns (uint256) {
        uint24 distributionId = _grantFund.getDistributionId();
        return standardFundingProposals[distributionId][constrictToRange(randomSeed(), 0, standardFundingProposals[distributionId].length - 1)];
    }

    function getStage() internal view returns (bytes memory stage_) {
        uint24 distributionId = _grantFund.getDistributionId();
        (, , uint256 endBlock, , , ) = _grantFund.getDistributionPeriodInfo(distributionId);
        if (block.number < endBlock - 72000) {
            stage_ = bytes("Screening");
        }
        else if (block.number > endBlock - 72000 && block.number < endBlock) {
            stage_ = bytes("Funding");
        }
        else if (block.number > endBlock) {
            stage_ = bytes("Challenge");
        }
    }

    function _createProposals(uint256 numProposals_) internal returns (uint256[] memory proposalIds_) {
        proposalIds_ = new uint256[](numProposals_);
        for (uint256 i = 0; i < numProposals_; ++i) {
            proposalIds_[i] = _createProposal();
        }
    }

    function _createProposal() internal useRandomActor(randomSeed()) returns (uint256 proposalId_) {
        // TODO: increase randomness of number of params, including potentially randomizing each separate param?
        // get a random number between 1 and 5
        uint256 numProposalParams = constrictToRange(randomSeed(), 1, 5);

        // generate list of recipients and tokens requested
        TestProposalParams[] memory testProposalParams = generateTestProposalParams(numProposalParams);

        // generate proposal params
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = generateProposalParams(address(_ajna), testProposalParams);

        // create proposal
        proposalId_ = _grantFund.proposeStandard(targets, values, calldatas, description);

        // record new proposal
        standardFundingProposals[_grantFund.getDistributionId()].push(proposalId_);

        // FIXME: set recipient and tokensRequested
        // record proposal information
        testProposals[proposalId_] = TestProposal(
            proposalId_,
            targets,
            values,
            calldatas,
            description,
            address(0),
            0
        );
    }

    // TODO: need to add support for different types of param generation -> turn this into a factory
    function _fundingVoteParams(address actor_, uint256 numProposalsToVoteOn_, bool happyPath_) internal returns (IStandardFunding.FundingVoteParams[] memory fundingVoteParams_) {
        uint24 distributionId = _grantFund.getDistributionId();
        uint256 votingPower = _grantFund.getVotesFunding(distributionId, actor_);

        // Take the square root of the voting power to determine how many votes are actually available for casting
        uint256 availableVotes = _grantFund.getFundingPowerVotes(votingPower);

        fundingVoteParams_ = new IStandardFunding.FundingVoteParams[](numProposalsToVoteOn_);

        uint256 votingPowerUsed;

        // generate the array of fundingVoteParams structs
        for (uint256 i = 0; i < numProposalsToVoteOn_; ) {
            // get a random proposal
            uint256 proposalId = randomProposal();

            // get the random number of votes to cast
            int256 votesToCast = int256(constrictToRange(randomSeed(), 0, availableVotes));

            // if we should account for previous votes, then we need to make sure that the votes used are less than the available votes
            // flag is useful for generating vote params for a happy path required for test setup, as well as the chaotic path.
            if (happyPath_) {
                votesToCast = int256(constrictToRange(randomSeed(), 0, _grantFund.getFundingPowerVotes(votingPower - votingPowerUsed)));

                uint256[] memory topTenProposals = _grantFund.getTopTenProposals(distributionId);

                // if taking the happy path, set proposalId to a random proposal in the top ten
                if (_findProposalIndexOfVotesCast(proposalId, fundingVoteParams_) == -1) {
                    proposalId = topTenProposals[constrictToRange(randomSeed(), 0, topTenProposals.length - 1)];
                }

                bool votedPrior = false;

                // FIXME: check prior votes as well as pending votes.
                    // this may not be possible as we don't yet know what the pending votes will be...
                // check for any previous votes on this proposal
                IStandardFunding.FundingVoteParams[] memory priorVotes = votingActors[actor_][distributionId].fundingVotes;
                for (uint256 j = 0; j < priorVotes.length; ++j) {
                    // if we have already voted on this proposal, then we need to update the votes used
                    if (priorVotes[j].proposalId == proposalId) {
                        // votesToCast = int256(constrictToRange(randomSeed(), 0, _grantFund.getFundingPowerVotes(votingPower - votingPowerUsed)));
                        votingPowerUsed += Maths.wpow(uint256(Maths.abs(priorVotes[j].votesUsed + votesToCast)), 2);
                        votedPrior = true;
                        break;
                    }
                }

                if (!votedPrior) {
                    votingPowerUsed += Maths.wpow(uint256(Maths.abs(votesToCast)), 2);
                }

            }

            // TODO: happy path expects non negative? -> reverts with InvalidVote if used
                // Need to account for a proposal prior vote direction in test setup
            // flip a coin to see if should instead use a negative vote
            if (randomSeed() % 2 == 0) {
                numberOfCalls['SFH.negativeFundingVote']++;
                // generate negative vote
                fundingVoteParams_[i] = IStandardFunding.FundingVoteParams({
                    proposalId: proposalId,
                    votesUsed: -1 * votesToCast
                });
                ++i;
                continue;
            }

            // generate funding vote params
            fundingVoteParams_[i] = IStandardFunding.FundingVoteParams({
                proposalId: proposalId,
                votesUsed: votesToCast
            });

            ++i;
        }
    }

    function _fundingVoteProposal(address actor_, uint256 numProposalsToVoteOn_) internal {
        // get the fundingVoteParams for the votes the actor is about to cast
        // take the happy path, and cast votes that wont exceed the actor's voting power
        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = _fundingVoteParams(actor_, numProposalsToVoteOn_, true);

        // cast votes
        changePrank(actor_);
        _grantFund.fundingVote(fundingVoteParams);

        uint24 distributionId = _grantFund.getDistributionId();

        // record cast votes
        VotingActor storage actor = votingActors[actor_][distributionId];
        for (uint256 i = 0; i < numProposalsToVoteOn_; ) {
            actor.fundingVotes.push(fundingVoteParams[i]);
            fundingVotesCast++;

            ++i;
        }
    }

    function _screeningVoteProposal(address actor_) internal {
        uint24 distributionId = _grantFund.getDistributionId();

        uint256 votingPower = _grantFund.getVotesScreening(_grantFund.getDistributionId(), actor_);

        // get random number of proposals to vote on
        uint256 numProposalsToVoteOn = constrictToRange(randomSeed(), 1, 10);

        uint256 totalVotesUsed = 0;

        // calculate which proposals should be voted upon
        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](numProposalsToVoteOn);
        for (uint256 i = 0; i < numProposalsToVoteOn; ++i) {
            // get a random proposal
            uint256 proposalId = randomProposal();

            // account for already used voting power
            uint256 additionalVotesUsed = randomAmount(votingPower - totalVotesUsed);
            totalVotesUsed += additionalVotesUsed;

            // generate screening vote params
            screeningVoteParams[i] = IStandardFunding.ScreeningVoteParams({
                proposalId: proposalId,
                votes: additionalVotesUsed
            });
        }

        // cast votes
        changePrank(actor_);
        _grantFund.screeningVote(screeningVoteParams);

        // record cast votes
        VotingActor storage actor = votingActors[actor_][distributionId];
        for (uint256 i = 0; i < numProposalsToVoteOn; ) {
            actor.screeningVotes.push(screeningVoteParams[i]);
            screeningVotesCast++;

            ++i;
        }
    }

    /**************************/
    /*** Logging Functions ****/
    /**************************/

    function logActorSummary(uint24 distributionId_, bool funding_, bool screening_) external view {
        console.log("\nActor Summary\n");

        console.log("------------------");
        console.log("Number of Actors", getActorsCount());

        // sum proposal votes of each actor
        for (uint256 i = 0; i < getActorsCount(); ++i) {
            address actor = actors[i];

            // get actor info
            (
                IStandardFunding.FundingVoteParams[] memory fundingVoteParams,
                IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams,
                uint256 delegationRewardsClaimed
            ) = getVotingActorsInfo(actor, distributionId_);

            console.log("Actor:                    ", actor);
            console.log("Delegate:                 ", _ajna.delegates(actor));
            console.log("delegationRewardsClaimed: ", delegationRewardsClaimed);
            console.log("\n");

            // log funding info
            if (funding_) {
                console.log("--Funding----------");
                console.log("Funding proposals voted for:     ", fundingVoteParams.length);
                console.log("Sum of squares of fvc:           ", sumSquareOfVotesCast(fundingVoteParams));
                console.log("Funding Votes Cast:              ", uint256(sumFundingVotes(fundingVoteParams)));
                console.log("Negative Funding Votes Cast:     ", countNegativeFundingVotes(fundingVoteParams));
                console.log("------------------");
                console.log("\n");
            }

            if (screening_) {
                console.log("--Screening----------");
                console.log("Screening Voting Power:          ", _grantFund.getVotesScreening(distributionId_, actor));
                console.log("Screening Votes Cast:            ", sumVoterScreeningVotes(actor, distributionId_));
                console.log("Screening proposals voted for:   ", screeningVoteParams.length);
                console.log("------------------");
                console.log("\n");
            }
        }
    }

    function logCallSummary() external view {
        console.log("\nCall Summary\n");
        console.log("--SFM----------");
        console.log("SFH.startNewDistributionPeriod ",  numberOfCalls["SFH.startNewDistributionPeriod"]);
        console.log("SFH.proposeStandard            ",  numberOfCalls["SFH.proposeStandard"]);
        console.log("SFH.screeningVote              ",  numberOfCalls["SFH.screeningVote"]);
        console.log("SFH.fundingVote                ",  numberOfCalls["SFH.fundingVote"]);
        console.log("SFH.updateSlate                ",  numberOfCalls["SFH.updateSlate"]);
        console.log("SFH.executeStandard            ",  numberOfCalls["SFH.executeStandard"]);
        console.log("SFH.claimDelegateReward        ",  numberOfCalls["SFH.claimDelegateReward"]);
        console.log("roll                           ",  numberOfCalls["roll"]);
        console.log("------------------");
        console.log(
            "Total Calls:",
            numberOfCalls["SFH.startNewDistributionPeriod"] +
            numberOfCalls["SFH.proposeStandard"] +
            numberOfCalls["SFH.screeningVote"] +
            numberOfCalls["SFH.fundingVote"] +
            numberOfCalls["SFH.updateSlate"] +
            numberOfCalls["SFH.executeStandard"] +
            numberOfCalls["SFH.claimDelegateReward"] +
            numberOfCalls["roll"]
        );
    }

    function logProposalSummary() external view {
        uint24 distributionId = _grantFund.getDistributionId();
        uint256[] memory proposals = standardFundingProposals[distributionId];

        console.log("\nProposal Summary\n");
        console.log("Number of Proposals", proposals.length);
        for (uint256 i = 0; i < proposals.length; ++i) {
            console.log("------------------");
            (uint256 proposalId, , uint128 votesReceived, uint128 tokensRequested, int128 fundingVotesReceived, bool executed) = _grantFund.getProposalInfo(proposals[i]);
            console.log("proposalId:           ",  proposalId);
            console.log("distributionId:       ",  distributionId);
            console.log("executed:             ",  executed);
            console.log("votesReceived:        ",  votesReceived);
            console.log("tokensRequested:      ",  tokensRequested);
            if (fundingVotesReceived < 0) {
                console.log("Negative fundingVotesReceived: ",  uint256(Maths.abs(fundingVotesReceived)));
            }
            else {
                console.log("Positive fundingVotesReceived: ",  uint256(int256(fundingVotesReceived)));
            }

            console.log("------------------");
        }
        console.log("\n");
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function getDistributionState(uint24 distributionId_) external view returns (DistributionState memory) {
        return distributionStates[distributionId_];
    }

    function getStandardFundingProposals(uint24 distributionId_) external view returns (uint256[] memory) {
        return standardFundingProposals[distributionId_];
    }

    function getProposalsExecuted() external view returns (uint256[] memory) {
        return proposalsExecuted;
    }

    function getVotingActorsInfo(address actor_, uint24 distributionId_) public view returns (IStandardFunding.FundingVoteParams[] memory, IStandardFunding.ScreeningVoteParams[] memory, uint256) {
        return (
            votingActors[actor_][distributionId_].fundingVotes,
            votingActors[actor_][distributionId_].screeningVotes,
            votingActors[actor_][distributionId_].delegationRewardsClaimed
        );
    }

    function sumVoterScreeningVotes(address actor_, uint24 distributionId_) public view returns (uint256 sum_) {
        VotingActor memory actor = votingActors[actor_][distributionId_];
        for (uint256 i = 0; i < actor.screeningVotes.length; ++i) {
            sum_ += actor.screeningVotes[i].votes;
        }
    }

    function sumFundingVotes(IStandardFunding.FundingVoteParams[] memory fundingVotes_) public pure returns (int256 sum_) {
        for (uint256 i = 0; i < fundingVotes_.length; ++i) {
            sum_ += Maths.abs(fundingVotes_[i].votesUsed);
        }
    }

    function countNegativeFundingVotes(IStandardFunding.FundingVoteParams[] memory fundingVotes_) public pure returns (uint256 count_) {
        for (uint256 i = 0; i < fundingVotes_.length; ++i) {
            if (fundingVotes_[i].votesUsed < 0) {
                count_++;
            }
        }
    }

}

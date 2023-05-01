// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console }  from "@std/console.sol";
import { Test }     from "forge-std/Test.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { Strings }  from "@oz/utils/Strings.sol";

import { GrantFund }        from "../../../src/grants/GrantFund.sol";
import { IStandardFunding } from "../../../src/grants/interfaces/IStandardFunding.sol";
import { Maths }            from "../../../src/grants/libraries/Maths.sol";

import { IAjnaToken }          from "../../utils/IAjnaToken.sol";
import { GrantFundTestHelper } from "../../utils/GrantFundTestHelper.sol";
import { Handler }             from "./Handler.sol";

contract ExtraordinaryHandler is Handler {

    /***********************/
    /*** State Variables ***/
    /***********************/

    // proposalId of extraordinary proposals executed
    uint256[] public proposalsExecuted;

    // proposalId of extraordinary proposals submitted
    uint256[] public extraordinaryProposals;

    struct VotingActor {
        ExtraordinaryVoteParams[] votes;
    }

    // TODO: record treasury info at time of vote?
    struct ExtraordinaryVoteParams {
        uint256 proposalId;
        uint256 votesCast;
        uint256 voteBlock;
    }

    mapping(address => VotingActor) internal votingActors; // actor => VotingActor
    mapping(uint256 => TestProposalExtraordinary) public testProposals; // proposalId => TestProposalExtraordinary

    /*******************/
    /*** Constructor ***/
    /*******************/

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

    function proposeExtraordinary(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['EH.proposeExtraordinary']++;

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

        // get random end block time -> happy / chaotic path
        uint256 endBlock = 0;
        if (randomSeed() % 2 == 0) {
            // happy path
            endBlock = constrictToRange(randomSeed(), block.number + 10_000, block.number + 216_000);
        } else {
            // chaotic path set the limit to be much higher than the maximum proposal length
            endBlock = constrictToRange(randomSeed(), block.number, block.number + 10_000_000);
        }

        try _grantFund.proposeExtraordinary(endBlock, targets, values, calldatas, description) returns (uint256 proposalId) {
            // record successfully submitted proposal
            extraordinaryProposals.push(proposalId);

            (
                GeneratedTestProposalParams[] memory params,
                uint256 totalTokensRequested
            ) = _getGeneratedTestProposalParamsFromParams(targets, values, calldatas);

            // record proposal params
            TestProposalExtraordinary storage testProposal = testProposals[proposalId];
            testProposal.proposalId = proposalId;
            testProposal.description = description;
            testProposal.startBlock = block.number;
            testProposal.endBlock = endBlock;
            testProposal.totalTokensRequested = totalTokensRequested;
            testProposal.treasuryBalanceAtSubmission = _grantFund.treasury();
            testProposal.minimumThresholdPercentageAtSubmission = _grantFund.getMinimumThresholdPercentage();
            for (uint i = 0; i < params.length; ++i) {
                testProposal.params.push(params[i]);
            }
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("ProposalAlreadyExists()")) ||
                err == keccak256(abi.encodeWithSignature("InvalidProposal()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function voteExtraordinary(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['EH.voteExtraordinary']++;

        if (extraordinaryProposals.length == 0) return; // no proposals to vote on

        // get a random proposal to vote on
        uint256 proposalId = extraordinaryProposals[constrictToRange(randomSeed(), 0, extraordinaryProposals.length - 1)];

        // get actor voting power
        uint256 votingPower = _grantFund.getVotesExtraordinary(_actor, proposalId);

        try _grantFund.voteExtraordinary(proposalId) {
            // update VotingActor struct if vote was successful
            VotingActor storage actor = votingActors[_actor];
            actor.votes.push(ExtraordinaryVoteParams(proposalId, votingPower, block.number));
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("AlreadyVoted()")) ||
                err == keccak256(abi.encodeWithSignature("ExtraordinaryFundingProposalInactive()")),
                UNEXPECTED_REVERT
            );
        }
    }

    function executeExtraordinary(uint256 actorIndex_) external useCurrentBlock useRandomActor(actorIndex_) {
        numberOfCalls['EH.executeExtraordinary']++;

        if (extraordinaryProposals.length == 0) return; // no proposals to execute

        // get a random proposal to execute
        uint256 proposalId = extraordinaryProposals[constrictToRange(randomSeed(), 0, extraordinaryProposals.length - 1)];

        // retrieve the proposal params
        TestProposalExtraordinary memory testProposal = testProposals[proposalId];
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
        ) = _getParamsFromGeneratedTestProposalParams(_ajna, testProposal.params);

        uint256 treasuryBalanceAtExecution = _grantFund.treasury();
        uint256 ajnaTotalSupplyAtExecution = _ajna.totalSupply();
        uint256 minimumThresholdPercentageAtExecution = _grantFund.getMinimumThresholdPercentage();

        // execute proposal
        try _grantFund.executeExtraordinary(targets, values, calldatas, keccak256(bytes(testProposal.description))) returns (uint256 proposalId_) {
            // add executed proposalId to proposalsExecuted list
            proposalsExecuted.push(proposalId_);
            // record treasury balance at time of execution
            testProposals[proposalId_].treasuryBalanceAtExecution = treasuryBalanceAtExecution;
            testProposals[proposalId_].ajnaTotalSupplyAtExecution = ajnaTotalSupplyAtExecution;
            testProposals[proposalId_].minimumThresholdPercentageAtExecution = minimumThresholdPercentageAtExecution;
        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("ExecuteExtraordinaryProposalInvalid()")),
                UNEXPECTED_REVERT
            );
        }
    }

    /**************************/
    /*** Utility Functions ****/
    /**************************/

    function generateTestProposalParams(uint256 numParams_) internal returns (TestProposalParams[] memory testProposalParams_) {
        testProposalParams_ = new TestProposalParams[](numParams_);
        uint256 treasury = _grantFund.treasury(); // get treasury info

        uint256 totalTokensRequested = 0;
        for (uint256 i = 0; i < numParams_; ++i) {

            // TODO: use happy / chaotic path to determine amount to request
            // account for amount that was previously requested
            uint256 additionalTokensRequested = randomAmount((treasury * 9 /10) - totalTokensRequested);
            totalTokensRequested += additionalTokensRequested;

            testProposalParams_[i] = TestProposalParams({
                recipient: randomActor(),
                tokensRequested: additionalTokensRequested
            });
        }
    }

    /**************************/
    /*** Logging Functions ****/
    /**************************/

    function logActorSummary(bool voteInfo_) external view {
        console.log("\nActor Summary\n");

        console.log("------------------");
        console.log("Number of Actors", getActorsCount());

        // sum proposal votes of each actor
        for (uint256 i = 0; i < getActorsCount(); ++i) {
            address actor = actors[i];

            console.log("------------");
            console.log("Actor:                    ", actor);
            console.log("Delegate:                 ", _ajna.delegates(actor));
            console.log("------------");

            // log actor vote info if requested
            if (voteInfo_) {
                ExtraordinaryVoteParams[] memory extraorindaryVoteParams = getVotingActorsInfo(actor);

                for(uint256 j = 0; j < extraorindaryVoteParams.length; ++j) {
                    ExtraordinaryVoteParams memory voteParams = extraorindaryVoteParams[j];
                    console.log("--Vote----------");
                    console.log("proposalId: ", voteParams.proposalId);
                    console.log("votesCast:  ", voteParams.votesCast);
                    console.log("votesBlock: ", voteParams.voteBlock);
                    console.log("----------------");
                }
            }
            console.log("\n");
        }
    }

    function logCallSummary() external view {
        console.log("\nCall Summary\n");
        console.log("--EH----------");
        console.log("EH.proposeExtraordinary ",  numberOfCalls["EH.proposeExtraordinary"]);
        console.log("EH.voteExtraordinary    ",  numberOfCalls["EH.voteExtraordinary"]);
        console.log("EH.executeExtraordinary ",  numberOfCalls["EH.executeExtraordinary"]);
        console.log("roll                    ",  numberOfCalls["roll"]);
        console.log("------------------");
        console.log(
            "Total Calls:",
            numberOfCalls["EH.proposeExtraordinary"] +
            numberOfCalls["EH.voteExtraordinary"] +
            numberOfCalls["EH.executeExtraordinary"] +
            numberOfCalls["roll"]
        );
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function getVotingActorsInfo(address actor_) public view returns (
        ExtraordinaryVoteParams[] memory
    ) {
        return votingActors[actor_].votes;
    }

    function getVotingActorsProposals(address actor_) public view returns (
        uint256[] memory proposals_
    ) {
        ExtraordinaryVoteParams[] memory votes = votingActors[actor_].votes;
        proposals_ = new uint256[](votes.length);

        for (uint256 i = 0; i < votes.length; ++i) {
            proposals_[i] = votes[i].proposalId;
        }
    }

    function getExtraordinaryProposals() public view returns (uint256[] memory) {
        return extraordinaryProposals;
    }

    function getExecutedExtraordinaryProposals() public view returns (uint256[] memory) {
        return proposalsExecuted;
    }

    function getTestProposal(uint256 proposalId_) public view returns (TestProposalExtraordinary memory) {
        return testProposals[proposalId_];
    }

    function getSumVotesCast(address actor_) public view returns (uint256 sum_) {
        ExtraordinaryVoteParams[] memory votes = votingActors[actor_].votes;

        for (uint256 i = 0; i < votes.length; ++i) {
            sum_ += votes[i].votesCast;
        }
    }

}

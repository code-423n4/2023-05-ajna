// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console }  from "@std/console.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";

import { IExtraordinaryFunding } from "../../src/grants/interfaces/IExtraordinaryFunding.sol";
import { Maths }                 from "../../src/grants/libraries/Maths.sol";

import { ExtraordinaryTestBase } from "./base/ExtraordinaryTestBase.sol";
import { ExtraordinaryHandler }  from "./handlers/ExtraordinaryHandler.sol";

contract ExtraordinaryInvariant is ExtraordinaryTestBase {

    function setUp() public override {
        super.setUp();

        // TODO: need to setCurrentBlock?
        currentBlock = block.number;

        // set the list of function selectors to run
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = _extraordinaryHandler.proposeExtraordinary.selector;
        selectors[1] = _extraordinaryHandler.voteExtraordinary.selector;
        selectors[2] = _extraordinaryHandler.executeExtraordinary.selector;
        selectors[3] = _extraordinaryHandler.roll.selector;

        // ensure utility functions are excluded from the invariant runs
        targetSelector(FuzzSelector({
            addr: address(_extraordinaryHandler),
            selectors: selectors
        }));
    }

    function invariant_PE1_PE2_PE3_EE1_EE2_EE3_EE4() external {
        uint256[] memory proposals = _extraordinaryHandler.getExtraordinaryProposals();

        require(
            !hasDuplicates(_extraordinaryHandler.getExtraordinaryProposals()),
            "invariant PE1: A proposal's proposalId must be unique"
        );

        require(
            !hasDuplicates(_extraordinaryHandler.getExecutedExtraordinaryProposals()),
            "invariant EE1: A proposal can only be executed once"
        );

        for (uint256 i = 0; i < proposals.length; ++i) {
            TestProposalExtraordinary memory proposal = _extraordinaryHandler.getTestProposal(proposals[i]);

            (
                uint256 proposalId,
                ,
                ,
                uint128 tokensRequested,
                uint120 votesReceived,
                bool executed
            ) = _grantFund.getExtraordinaryProposalInfo(proposal.proposalId);

            // check test setup
            assertEq(uint256(tokensRequested), proposal.totalTokensRequested);
            assertEq(proposalId, proposal.proposalId);

            // check proposal end block
            require(
                proposal.endBlock <= proposal.startBlock + 216_000,
                "invariant PE2: A proposal's endBlock must be less than the MAX_EFM_PROPOSAL_LENGTH of 216_000 blocks"
            );

            console.log("grant fund state tokens requested:               %s", tokensRequested);
            console.log("proposal.totalTokensRequested:                   %s", proposal.totalTokensRequested);
            console.log("proposal.treasuryBalanceAtSubmission:            %s", proposal.treasuryBalanceAtSubmission);
            console.log("proposal.minimumThresholdPercentageAtSubmission: %s", proposal.minimumThresholdPercentageAtSubmission);
            console.log("proposal.treasuryBalanceAtExecution:             %s", proposal.treasuryBalanceAtExecution);
            console.log("proposal.minimumThresholdPercentageAtExecution:  %s", proposal.minimumThresholdPercentageAtExecution);
            console.log("proposal.executed:                               %s", executed);
            console.log("votes received:                                  %s", votesReceived);

            require(
                proposal.totalTokensRequested <= Maths.wmul(proposal.treasuryBalanceAtSubmission, Maths.WAD - proposal.minimumThresholdPercentageAtSubmission),
                "invariant PE3: A proposal's tokens requested must be less than treasuryBalance * (1 - minimumThresholdPercentage)"
            );

            // check executed proposals's exceeded required vote thresholds
            if (executed) {
                require(
                    votesReceived >= tokensRequested + Maths.wmul((proposal.ajnaTotalSupplyAtExecution - proposal.treasuryBalanceAtExecution), proposal.minimumThresholdPercentageAtExecution),
                    "invariant EE2: A proposal can only be executed if its votesReceived exceeds its tokensRequested + the minimumThresholdPercentage times the non-treasury token supply at the time of execution"
                );
                require(
                    proposal.totalTokensRequested < Maths.wmul(proposal.treasuryBalanceAtExecution, Maths.WAD - proposal.minimumThresholdPercentageAtExecution),
                    "invariant EE3: A proposal can only be executed if it's tokensRequested is less than treasury * (1 - minimumThresholdPercentage)"
                );
            }
        }

        require(
            _extraordinaryHandler.getExecutedExtraordinaryProposals().length < 10,
            "invariant EE4: Only 9 proposals can be executed"
        );
    }

    function invariant_VE1_VE2_VE3_VE4() external view {
        for (uint256 i = 0; i < _extraordinaryHandler.getActorsCount(); ++i) {
            address actor = _extraordinaryHandler.actors(i);

            // check has no duplicates
            require(
                !hasDuplicates(_extraordinaryHandler.getVotingActorsProposals(actor)),
                "invariant VE1: A proposal can only be voted on once"
            );

            ExtraordinaryHandler.ExtraordinaryVoteParams[] memory voteParams = _extraordinaryHandler.getVotingActorsInfo(actor);
            for (uint256 j = 0; j < voteParams.length; ++j) {
                ExtraordinaryHandler.ExtraordinaryVoteParams memory param = voteParams[j];
                TestProposalExtraordinary memory proposal = _extraordinaryHandler.getTestProposal(param.proposalId);

                // check vote is within the expected range of blocks
                require(
                    param.voteBlock >= proposal.startBlock && param.voteBlock <= proposal.endBlock,
                    "invariant VE2: A proposal can only be voted on if the block number is less than or equal to the proposals end block and the `MAX_EFM_PROPOSAL_LENGTH` of 216_000 blocks."
                );

                require(
                    param.votesCast >= 0,
                    "invariant VE3: Votes cast must always be positive"
                );
            }

            require(
                _extraordinaryHandler.getSumVotesCast(actor) <= _ajna.totalSupply(),
                "invariant VE4: A voter should never be able to cast more votes than the Ajna token supply"
            );
        }
    }

    function invariant_EG1() external view {
        uint256 numberOfProposalsExecuted = _extraordinaryHandler.getExecutedExtraordinaryProposals().length;

        require(
            _grantFund.getMinimumThresholdPercentage() == 0.5 * 1e18 + (numberOfProposalsExecuted * (0.05 * 1e18)),
            "invariant EG1: The `minimumThresholdPercentage` variable increases by 5% for each successive executed proposal"
        );
    }

    function invariant_call_summary() external view {
        _extraordinaryHandler.logCallSummary();
        _extraordinaryHandler.logActorSummary(false);
        _logExtraordinarySummary();
    }

    function _logExtraordinarySummary() internal view {
        console.log("\nExtraordinary Summary\n");
        console.log("------------------");
        console.log("Extraordinary Proposals:  %s", _extraordinaryHandler.getExtraordinaryProposals().length);
        console.log("Extraordinary Executions: %s", _extraordinaryHandler.getExecutedExtraordinaryProposals().length);
    }

}

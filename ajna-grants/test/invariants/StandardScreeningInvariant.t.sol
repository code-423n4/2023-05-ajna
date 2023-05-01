// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console } from "@std/console.sol";

import { IStandardFunding } from "../../src/grants/interfaces/IStandardFunding.sol";

import { StandardTestBase } from "./base/StandardTestBase.sol";
import { StandardHandler }  from "./handlers/StandardHandler.sol";

contract StandardScreeningInvariant is StandardTestBase {

    function setUp() public override {
        super.setUp();

        // set the list of function selectors to run
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = _standardHandler.startNewDistributionPeriod.selector;
        selectors[1] = _standardHandler.proposeStandard.selector;
        selectors[2] = _standardHandler.screeningVote.selector;

        // ensure utility functions are excluded from the invariant runs
        targetSelector(FuzzSelector({
            addr: address(_standardHandler),
            selectors: selectors
        }));

    }

    function invariant_SS1_SS3_SS4_SS5_SS6_SS7() public {
        uint24 distributionId = _grantFund.getDistributionId();
        uint256 standardFundingProposalsSubmitted = _standardHandler.getStandardFundingProposals(distributionId).length;
        uint256[] memory topTenProposals = _grantFund.getTopTenProposals(_grantFund.getDistributionId());

        // invariant SS1: 10 or less proposals should make it through the screening stage
        assertTrue(topTenProposals.length <= 10);
        assertTrue(standardFundingProposalsSubmitted >= topTenProposals.length);

        // check the state of the top ten proposals
        if (topTenProposals.length > 1) {
            for (uint256 i = 0; i < topTenProposals.length - 1; ++i) {
                // check the current proposals votes received against the next proposal in the top ten list
                (, uint24 distributionIdCurr, uint256 votesReceivedCurr, , , ) = _grantFund.getProposalInfo(topTenProposals[i]);
                (, uint24 distributionIdNext, uint256 votesReceivedNext, , , ) = _grantFund.getProposalInfo(topTenProposals[i + 1]);
                require(
                    votesReceivedCurr >= votesReceivedNext,
                    "invariant SS3: proposals should be sorted in descending order"
                );

                require(
                    votesReceivedCurr > 0 && votesReceivedNext > 0,
                    "invariant SS4: votes recieved for a proposal can only be positive"
                );

                require(
                    distributionIdCurr == distributionIdNext && distributionIdCurr == distributionId,
                    "invariant SS5: distribution id for a proposal should be the same as the current distribution id"
                );
            }
        }

        // find the number of screening votes received by the last proposal in the top ten list
        uint256 votesReceivedLast;
        if (topTenProposals.length != 0) {
            (, , votesReceivedLast, , , ) = _grantFund.getProposalInfo(topTenProposals[topTenProposals.length - 1]);
            assertGt(votesReceivedLast, 0);
        }

        // check invariants against all submitted proposals
        for (uint256 j = 0; j < standardFundingProposalsSubmitted; ++j) {
            (, , uint256 votesReceived, , , ) = _grantFund.getProposalInfo(_standardHandler.standardFundingProposals(distributionId, j));
            require(
                votesReceived >= 0,
                "invariant SS4: votes recieved for a proposal can only be positive"
            );

            require(
                votesReceived <= _ajna.totalSupply(),
                "invariant SS7: a proposal should never receive more screening votes than the token supply"
            );

            // invariant SS6: For every proposal, it is included in the top 10 list if, and only if, it has as many or more votes as the last member of the top ten list.
            // if the proposal is not in the top ten list, then it should have received less screening votes than the last in the top 10
            if (_findProposalIndex(_standardHandler.standardFundingProposals(distributionId, j), topTenProposals) == -1) {
                if (votesReceivedLast != 0) {
                    // assertTrue(votesReceived < votesReceivedLast);
                    assertGt(votesReceivedLast, votesReceived);
                }
            }
        }

        // invariant SS6: proposals should be incorporated into the top ten list if, and only if, they have as many or more votes as the last member of the top ten list.
        if (_standardHandler.screeningVotesCast() > 0) {
            assertTrue(topTenProposals.length > 0);
        }

    }

    function invariant_SS2_SS4_SS8() external view {
        uint256 actorCount = _standardHandler.getActorsCount();
        uint24 distributionId = _grantFund.getDistributionId();

        // check invariants for all actors
        for (uint256 i = 0; i < actorCount; ++i) {
            address actor = _standardHandler.actors(i);
            uint256 votingPower = _grantFund.getVotesScreening(distributionId, actor);

            require(
                _standardHandler.sumVoterScreeningVotes(actor, distributionId) <= votingPower,
                "invariant SS2: can only vote up to the amount of voting power at the snapshot blocks"
            );

            // check the screening votes cast by the actor
            ( , IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams, ) = _standardHandler.getVotingActorsInfo(actor, distributionId);
            for (uint256 j = 0; j < screeningVoteParams.length; ++j) {
                require(
                    screeningVoteParams[j].votes > 0,
                    "invariant SS4: can only cast positive votes"
                );

                require(
                    _findProposalIndex(screeningVoteParams[j].proposalId, _standardHandler.getStandardFundingProposals(distributionId)) != -1,
                    "invariant SS8: a proposal can only receive screening votes if it was created via proposeStandard()"
                );
            }
        }
    }

    function invariant_call_summary() external view {
        uint24 distributionId = _grantFund.getDistributionId();

        _standardHandler.logCallSummary();
        _standardHandler.logProposalSummary();
        _standardHandler.logActorSummary(distributionId, false, true);
    }

}

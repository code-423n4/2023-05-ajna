// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console }  from "@std/console.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";

import { IStandardFunding } from "../../src/grants/interfaces/IStandardFunding.sol";
import { Maths }            from "../../src/grants/libraries/Maths.sol";

import { StandardTestBase } from "./base/StandardTestBase.sol";
import { StandardHandler }  from "./handlers/StandardHandler.sol";

contract StandardFinalizeInvariant is StandardTestBase {

    // override setup to start tests in the challenge stage with proposals that have already been screened and funded
    function setUp() public override {
        super.setUp();

        // create 15 proposals
        _standardHandler.createProposals(15);

        // cast screening votes on proposals
        _standardHandler.screeningVoteProposals();

        // skip time into the funding stage
        uint24 distributionId = _grantFund.getDistributionId();
        (, , uint256 endBlock, , , ) = _grantFund.getDistributionPeriodInfo(distributionId);
        uint256 fundingStageStartBlock = endBlock - 72000;
        vm.roll(fundingStageStartBlock + 100);

        // TODO: need to setCurrentBlock?
        currentBlock = fundingStageStartBlock + 100;

        // cast funding votes on proposals
        try _standardHandler.fundingVoteProposals() {

        }
        catch (bytes memory _err){
            bytes32 err = keccak256(_err);
            require(
                err == keccak256(abi.encodeWithSignature("InvalidVote()")) ||
                err == keccak256(abi.encodeWithSignature("InsufficientVotingPower()")) ||
                err == keccak256(abi.encodeWithSignature("FundingVoteWrongDirection()"))
            );
        }

        // skip time into the challenge stage
        vm.roll(endBlock + 100);

        // set the list of function selectors to run
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = _standardHandler.fundingVote.selector;
        selectors[1] = _standardHandler.updateSlate.selector;
        selectors[2] = _standardHandler.executeStandard.selector;
        selectors[3] = _standardHandler.claimDelegateReward.selector;
        selectors[4] = _standardHandler.roll.selector;

        // ensure utility functions are excluded from the invariant runs
        targetSelector(FuzzSelector({
            addr: address(_standardHandler),
            selectors: selectors
        }));
    }

    function invariant_CS1_CS2_CS3_CS4_CS5_CS6() view external {
        uint24 distributionId = _grantFund.getDistributionId();

        (, , uint256 endBlock, uint128 fundsAvailable, , bytes32 topSlateHash) = _grantFund.getDistributionPeriodInfo(distributionId);

        uint256[] memory topSlateProposalIds = _grantFund.getFundedProposalSlate(topSlateHash);

        uint256[] memory topTenScreenedProposalIds = _grantFund.getTopTenProposals(distributionId);

        require(
            topSlateProposalIds.length <= 10,
            "invariant CS2: top slate should have 10 or less proposals"
        );

        // check proposal state of the constituents of the top slate
        uint256 totalTokensRequested = 0;
        for (uint256 i = 0; i < topSlateProposalIds.length; ++i) {
            uint256 proposalId = topSlateProposalIds[i];
            (, , , uint128 tokensRequested, int128 fundingVotesReceived, ) = _grantFund.getProposalInfo(proposalId);
            totalTokensRequested += tokensRequested;

            require(
                fundingVotesReceived >= 0,
                "invariant CS3: Proposal slate should never contain a proposal with negative funding votes received"
            );

            require(
                _findProposalIndex(proposalId, topTenScreenedProposalIds) != -1,
                "invariant CS4: Proposal slate should never contain a proposal that wasn't in the top ten in the funding stage."
            );
        }

        require(
            totalTokensRequested <= uint256(fundsAvailable) * 9 / 10,
            "invariant CS1: total tokens requested should be <= 90% of fundsAvailable"
        );

        require(
            !_standardHandler.hasDuplicates(topSlateProposalIds),
            "invariant CS5: proposal slate should never contain duplicate proposals"
        );

        // check DistributionState for top slate updates
        StandardHandler.DistributionState memory state = _standardHandler.getDistributionState(distributionId);
        for (uint i = 0; i < state.topSlates.length; ++i) {
            StandardHandler.Slate memory slate = state.topSlates[i];

            require(
                slate.updateBlock >= endBlock && slate.updateBlock <= endBlock + 50400,
                "invariant CS6: Funded proposal slate's can only be updated during a distribution period's challenge stage"
            );
        }
    }

    function invariant_ES1_ES2_ES3() external {
        uint24 distributionId = _grantFund.getDistributionId();
        (, , , , , bytes32 topSlateHash) = _grantFund.getDistributionPeriodInfo(distributionId);

        uint256[] memory topSlateProposalIds = _grantFund.getFundedProposalSlate(topSlateHash);

        // calculate the total tokens requested by the proposals in the top slate
        uint256 totalTokensRequested = 0;
        for (uint256 i = 0; i < topSlateProposalIds.length; ++i) {
            uint256 proposalId = topSlateProposalIds[i];
            (, , , uint128 tokensRequested, , ) = _grantFund.getProposalInfo(proposalId);
            totalTokensRequested += tokensRequested;
        }

        uint256[] memory standardFundingProposals = _standardHandler.getStandardFundingProposals(distributionId);

        // check the state of every proposal submitted in this distribution period
        for (uint256 i = 0; i < standardFundingProposals.length; ++i) {
            uint256 proposalId = standardFundingProposals[i];
            (, uint24 proposalDistributionId, , , , bool executed) = _grantFund.getProposalInfo(proposalId);
            int256 proposalIndex = _findProposalIndex(proposalId, topSlateProposalIds);
            // invariant ES1: A proposal can only be executed if it's listed in the final funded proposal slate at the end of the challenge round.
            if (proposalIndex == -1) {
                assertFalse(executed);
            }

            // invariant ES2: A proposal can only be executed if it's listed in the final funded proposal slate at the end of the challenge round.
            assertEq(distributionId, proposalDistributionId);
            if (executed) {
                (, , uint48 endBlock, , , ) = _grantFund.getDistributionPeriodInfo(distributionId);
                assertGt(block.number, endBlock + 50400);
                require(
                    block.number > endBlock + 50400,
                    "invariant ES2: A proposal can only be executed after the challenge stage is complete."
                );
            }
        }

        require(
            !_standardHandler.hasDuplicates(_standardHandler.getProposalsExecuted()),
            "invariant ES3: A proposal can only be executed once."
        );
    }

    function invariant_DR1_DR2_DR3() external {
        uint24 distributionId = _grantFund.getDistributionId();
        (, , , uint128 fundsAvailable, uint256 fundingVotePowerCast, ) = _grantFund.getDistributionPeriodInfo(distributionId);

        uint256 totalRewardsClaimed;

        for (uint256 i = 0; i < _standardHandler.getActorsCount(); ++i) {
            address actor = _standardHandler.actors(i);

            // get the initial funding stage voting power of the actor
            (uint128 votingPower, uint128 remainingVotingPower, ) = _grantFund.getVoterInfo(distributionId, actor);

            // get actor info from standard handler
            (
                IStandardFunding.FundingVoteParams[] memory fundingVoteParams,
                IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams,
                uint256 delegationRewardsClaimed
            ) = _standardHandler.getVotingActorsInfo(actor, distributionId);

            totalRewardsClaimed += delegationRewardsClaimed;

            if (delegationRewardsClaimed != 0) {
                // check that delegation rewards are greater tahn 0 if they did vote in both stages
                assertTrue(delegationRewardsClaimed >= 0);

                uint256 votingPowerAllocatedByDelegatee = votingPower - remainingVotingPower;

                require(
                    fundingVoteParams.length > 0 && screeningVoteParams.length > 0,
                    "invariant DR2: Delegation rewards are 0 if voter didn't vote in both stages."
                );

                uint256 rewards;
                if (votingPowerAllocatedByDelegatee > 0) {
                    rewards = Maths.wdiv(
                        Maths.wmul(
                            fundsAvailable,
                            votingPowerAllocatedByDelegatee
                        ),
                        fundingVotePowerCast
                    ) / 10;
                }

                require(
                    delegationRewardsClaimed == rewards,
                    "invariant DR3: Delegation rewards are proportional to voters funding power allocated in the funding stage."
                );
            }
        }

        // invariant DR1: Cumulative delegation rewards should be 10% of a distribution periods GBC.
        assertTrue(totalRewardsClaimed <= fundsAvailable * 1 / 10);
        if (_standardHandler.numberOfCalls('SFH.claimDelegateReward.success') == _standardHandler.getActorsCount()) {
            assertEq(totalRewardsClaimed, fundsAvailable * 1 / 10);
        }
    }

    function invariant_call_summary() external view {
        uint24 distributionId = _grantFund.getDistributionId();

        _standardHandler.logCallSummary();
        _standardHandler.logProposalSummary();
        _logFinalizeSummary(distributionId);
    }

    function _logFinalizeSummary(uint24 distributionId_) internal view {
        (, , , uint128 fundsAvailable, , bytes32 topSlateHash) = _grantFund.getDistributionPeriodInfo(distributionId_);
        uint256[] memory topSlateProposalIds = _grantFund.getFundedProposalSlate(topSlateHash);

        uint256[] memory topTenScreenedProposalIds = _grantFund.getTopTenProposals(distributionId_);

        console.log("\nFinalize Summary\n");
        console.log("------------------");
        console.log("Delegation Rewards Claimed: ", _standardHandler.numberOfCalls('SFH.claimDelegateReward.success'));
        console.log("Proposal Execute Count:     ", _standardHandler.numberOfCalls('SFH.executeStandard.success'));
        console.log("Slate Update Called:        ", _standardHandler.numberOfCalls('SFH.updateSlate.called'));
        console.log("Slate Update Count:         ", _standardHandler.numberOfCalls('SFH.updateSlate.success'));
        console.log("Top Slate Proposal Count:   ", topSlateProposalIds.length);
        console.log("Top Ten Proposal Count:     ", topTenScreenedProposalIds.length);
        console.log("Funds Available:            ", fundsAvailable);
        console.log("------------------");
    }

}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { console }  from "@std/console.sol";
import { SafeCast } from "@oz/utils/math/SafeCast.sol";

import { IStandardFunding } from "../../src/grants/interfaces/IStandardFunding.sol";
import { Maths }            from "../../src/grants/libraries/Maths.sol";

import { StandardTestBase } from "./base/StandardTestBase.sol";
import { StandardHandler }  from "./handlers/StandardHandler.sol";
import { Handler }          from "./handlers/Handler.sol";

contract StandardMultipleDistributionInvariant is StandardTestBase {

    // run tests against all functions, having just started a distribution period
    function setUp() public override {
        super.setUp();

        // set the list of function selectors to run
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = _standardHandler.startNewDistributionPeriod.selector;
        selectors[1] = _standardHandler.proposeStandard.selector;
        selectors[2] = _standardHandler.screeningVote.selector;
        selectors[3] = _standardHandler.fundingVote.selector;
        selectors[4] = _standardHandler.updateSlate.selector;
        selectors[5] = _standardHandler.executeStandard.selector;
        selectors[6] = _standardHandler.claimDelegateReward.selector;
        selectors[7] = _standardHandler.roll.selector;

        // ensure utility functions are excluded from the invariant runs
        targetSelector(FuzzSelector({
            addr: address(_standardHandler),
            selectors: selectors
        }));

        // update scenarioType to fast to have larger rolls
        _standardHandler.setCurrentScenarioType(Handler.ScenarioType.Fast);
    }

    function invariant_call_summary() external view {
        uint24 distributionId = _grantFund.getDistributionId();

        _standardHandler.logCallSummary();
        // _standardHandler.logProposalSummary();
        _standardHandler.logActorSummary(distributionId, true, true);

        // TODO: need to be able to log all the different type of summaries
        // _logFinalizeSummary(distributionId);
    }
}

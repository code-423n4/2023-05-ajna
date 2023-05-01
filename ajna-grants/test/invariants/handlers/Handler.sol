// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { Test }    from "forge-std/Test.sol";
import { Strings } from "@oz/utils/Strings.sol";

import { IAjnaToken }          from "../../utils/IAjnaToken.sol";
import { GrantFundTestHelper } from "../../utils/GrantFundTestHelper.sol";

import { GrantFund }        from "../../../src/grants/GrantFund.sol";
import { IStandardFunding } from "../../../src/grants/interfaces/IStandardFunding.sol";

import { ITestBase } from "../base/ITestBase.sol";

contract Handler is Test, GrantFundTestHelper {

    /***********************/
    /*** State Variables ***/
    /***********************/

    // state variables
    IAjnaToken        internal  _ajna;
    GrantFund         internal  _grantFund;

    // Test invariant contract
    ITestBase internal testContract;

    // test params
    address internal _actor; // currently active actor, used in useRandomActor modifier
    address[] public actors;
    address _tokenDeployer;

    // logging
    mapping(bytes32 => uint256) public numberOfCalls;

    // randomness counter
    uint256 internal counter = 1;

    // constant error string when an unexpected revert is thrown
    string internal constant UNEXPECTED_REVERT = "UNEXPECTED_REVERT_ERROR";

    // default to slow scenario types
    uint8 internal _currentScenarioType = 1;

    enum ScenarioType {
        Fast,
        Slow
    }

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
    ) {
        // Ajna Token contract address on mainnet
        _ajna = IAjnaToken(token_);

        // deploy growth fund contract
        _grantFund = GrantFund(grantFund_);

        // token deployer
        _tokenDeployer = tokenDeployer_;

        // instantiate actors
        actors = _buildActors(numOfActors_, tokensToDistribute_);

        // Test invariant contract
        testContract = ITestBase(testContract_);
    }

    /*****************/
    /*** Modifiers ***/
    /*****************/

    modifier useCurrentBlock() {
        // vm.roll(testContract.currentBlock());

        _;

        testContract.setCurrentBlock(block.number);
    }

    modifier useRandomActor(uint256 actorIndex) {
        vm.stopPrank();

        address actor = actors[constrictToRange(actorIndex, 0, actors.length - 1)];
        _actor = actor;
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    /*************************/
    /*** Wrapped Functions ***/
    /*************************/

    // roll forward to a random block height
    // roll limit is configurable based on the scenario type
    function roll(uint256 rollAmount_) external useCurrentBlock {
        numberOfCalls['roll']++;

        uint256 rollLimit = 300;

        if (_currentScenarioType == uint8(ScenarioType.Fast)) {
            rollLimit = 7000;
        }

        // determine a random number of blocks to roll, less than 100
        rollAmount_ = constrictToRange(rollAmount_, 0, rollLimit);

        uint256 blockHeight = block.number + rollAmount_;

        // roll forward to the selected block
        vm.roll(blockHeight);
        testContract.setCurrentBlock(blockHeight);
    }

    /**************************/
    /*** Utility Functions ****/
    /**************************/

    function _buildActors(uint256 numOfActors_, uint256 tokensToDistribute_) internal returns (address[] memory actors_) {
        actors_ = new address[](numOfActors_);
        uint256 tokensDistributed = 0;

        for (uint256 i = 0; i < numOfActors_; ++i) {
            // create actor
            address actor = makeAddr(string(abi.encodePacked("Actor", Strings.toString(i))));
            actors_[i] = actor;

            // transfer ajna tokens to the actor
            if (tokensToDistribute_ - tokensDistributed == 0) {
                break;
            }
            uint256 incrementalTokensDistributed = randomAmount(tokensToDistribute_ - tokensDistributed);
            changePrank(_tokenDeployer);
            _ajna.transfer(actor, incrementalTokensDistributed);
            tokensDistributed += incrementalTokensDistributed;

            // FIXME: this isn't currently delegating to other actors properly
            // actor delegates tokens randomly
            if (randomSeed() % 2 == 0) {
                // actor self delegates
                changePrank(actor);
                _ajna.delegate(actor);
            } else {
                // actor delegates to a random actor
                changePrank(actor);
                if (actors.length > 0) {
                    _ajna.delegate(randomActor());
                }
                else {
                    // if no other actors are available (such as on the first iteration) self delegate
                    _ajna.delegate(actor);
                }
            }
        }
    }

    function constrictToRange(
        uint256 x,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256 result) {
        require(max >= min, "MAX_LESS_THAN_MIN");

        uint256 size = max - min;

        if (size == 0) return min;            // Using max would be equivalent as well.
        if (max != type(uint256).max) size++; // Make the max inclusive.

        // Ensure max is inclusive in cases where x != 0 and max is at uint max.
        if (max == type(uint256).max && x != 0) x--; // Accounted for later.

        if (x < min) x += size * (((min - x) / size) + 1);

        result = min + ((x - min) % size);

        // Account for decrementing x to make max inclusive.
        if (max == type(uint256).max && x != 0) result++;
    }

    function randomAmount(uint256 maxAmount_) internal returns (uint256) {
        return constrictToRange(randomSeed(), 1, maxAmount_);
    }

    function randomActor() internal returns (address) {
        return actors[constrictToRange(randomSeed(), 0, actors.length - 1)];
    }

    function randomSeed() internal returns (uint256) {
        counter++;
        return uint256(keccak256(abi.encodePacked(block.number, block.difficulty, counter)));
    }

    function getActorsCount() public view returns(uint256) {
        return actors.length;
    }

    function setCurrentScenarioType(ScenarioType scenarioType) public {
        _currentScenarioType = uint8(scenarioType);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { SafeCast }  from "@oz/utils/math/SafeCast.sol";

import { GrantFund }        from "../../src/grants/GrantFund.sol";
import { IFunding }         from "../../src/grants/interfaces/IFunding.sol";
import { IStandardFunding } from "../../src/grants/interfaces/IStandardFunding.sol";
import { Maths }            from "../../src/grants/libraries/Maths.sol";

import { GrantFundTestHelper } from "../utils/GrantFundTestHelper.sol";
import { IAjnaToken }          from "../utils/IAjnaToken.sol";

contract StandardFundingGrantFundTest is GrantFundTestHelper {

    // used to cast 256 to uint64 to match emit expectations
    using SafeCast for uint256;

    IAjnaToken        internal  _token;
    GrantFund         internal  _grantFund;

    // Ajna token Holder at the Ajna contract creation on mainnet
    address internal _tokenDeployer  = 0x666cf594fB18622e1ddB91468309a7E194ccb799;
    address internal _tokenHolder1   = makeAddr("_tokenHolder1");
    address internal _tokenHolder2   = makeAddr("_tokenHolder2");
    address internal _tokenHolder3   = makeAddr("_tokenHolder3");
    address internal _tokenHolder4   = makeAddr("_tokenHolder4");
    address internal _tokenHolder5   = makeAddr("_tokenHolder5");
    address internal _tokenHolder6   = makeAddr("_tokenHolder6");
    address internal _tokenHolder7   = makeAddr("_tokenHolder7");
    address internal _tokenHolder8   = makeAddr("_tokenHolder8");
    address internal _tokenHolder9   = makeAddr("_tokenHolder9");
    address internal _tokenHolder10  = makeAddr("_tokenHolder10");
    address internal _tokenHolder11  = makeAddr("_tokenHolder11");
    address internal _tokenHolder12  = makeAddr("_tokenHolder12");
    address internal _tokenHolder13  = makeAddr("_tokenHolder13");
    address internal _tokenHolder14  = makeAddr("_tokenHolder14");
    address internal _tokenHolder15  = makeAddr("_tokenHolder15");

    address[] internal _votersArr = [
        _tokenHolder1,
        _tokenHolder2,
        _tokenHolder3,
        _tokenHolder4,
        _tokenHolder5,
        _tokenHolder6,
        _tokenHolder7,
        _tokenHolder8,
        _tokenHolder9,
        _tokenHolder10,
        _tokenHolder11,
        _tokenHolder12,
        _tokenHolder13,
        _tokenHolder14,
        _tokenHolder15
    ];

    // at this block on mainnet, all ajna tokens belongs to _tokenDeployer
    uint256 internal _startBlock      = 16354861;

    mapping (uint256 => uint256) internal noOfVotesOnProposal;
    uint256[] internal topTenProposalIds;
    uint256[] internal potentialProposalsSlate;
    uint256 treasury = 500_000_000 * 1e18;

    // declare this to avoid stack too deep in end to end test
    uint256 delegateRewards = 0;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), _startBlock);

        vm.startPrank(_tokenDeployer);

        // Ajna Token contract address on mainnet
        _token = IAjnaToken(0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079);

        // deploy growth fund contract
        _grantFund = new GrantFund();

        // initial minter distributes tokens to test addresses
        _transferAjnaTokens(_token, _votersArr, 50_000_000 * 1e18, _tokenDeployer);

        // initial minter distributes treasury to grantFund
        changePrank(_tokenDeployer);
        _token.approve(address(_grantFund), 500_000_000 * 1e18);
        _grantFund.fundTreasury(500_000_000 * 1e18);
    }

    /*************/
    /*** Tests ***/
    /*************/

    function testGetVotingPowerScreeningStage() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 50);

        // start distribution period
        _startDistributionPeriod(_grantFund);

        // check voting power after screening stage has started
        vm.roll(_startBlock + 100);

        uint256 votingPower = _getScreeningVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 50_000_000 * 1e18);

        // skip forward 150 blocks and transfer some tokens after voting power was determined
        vm.roll(_startBlock + 150);

        changePrank(_tokenHolder1);
        _token.transfer(_tokenHolder2, 25_000_000 * 1e18);

        // check voting power is unchanged
        votingPower = _getScreeningVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 50_000_000 * 1e18);

        // check voting power won't change with token transfer to an address that didn't make it into the snapshot
        address nonVotingAddress = makeAddr("nonVotingAddress");
        changePrank(_tokenHolder1);
        _token.transfer(nonVotingAddress, 10_000_000 * 1e18);

        votingPower = _getScreeningVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 50_000_000 * 1e18);
        votingPower = _getScreeningVotes(_grantFund, nonVotingAddress);
        assertEq(votingPower, 0);

        // generate proposal targets
        address[] memory ajnaTokenTargets = new address[](1);
        ajnaTokenTargets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder2,
            1 * 1e18
        );

        // generate proposal message
        string memory description = "Proposal for Ajna token transfer to tester address";

        // create and submit proposal
        TestProposal memory proposal = _createProposalStandard(_grantFund, _tokenHolder1, ajnaTokenTargets, values, proposalCalldata, description);

        // token holder uses up their voting power in two separate votes on the same proposal
        _screeningVote(_grantFund, _tokenHolder1, proposal.proposalId, 30_000_000 * 1e18);
        _screeningVote(_grantFund, _tokenHolder1, proposal.proposalId, 20_000_000 * 1e18);

        // check revert if additional votes exceed the voter's voting power in the screening stage
        vm.expectRevert(IStandardFunding.InsufficientVotingPower.selector);
        _screeningVoteNoLog(_grantFund, _tokenHolder1, proposal.proposalId, 16_000_000 * 1e18);

        // check revert for using full voting power in screeningVote
        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](3);
        screeningVoteParams[0] = IStandardFunding.ScreeningVoteParams({
            proposalId: proposal.proposalId,
            votes: 20_000_000 * 1e18
        });
        screeningVoteParams[1] = IStandardFunding.ScreeningVoteParams({
            proposalId: proposal.proposalId,
            votes: 30_000_000 * 1e18
        });
        screeningVoteParams[2] = IStandardFunding.ScreeningVoteParams({
            proposalId: proposal.proposalId,
            votes: 10_000_000 * 1e18
        });

        changePrank(_tokenHolder3);
        vm.expectRevert(IStandardFunding.InsufficientVotingPower.selector);
        _grantFund.screeningVote(screeningVoteParams);
    }

    function testGetVotingPowerFundingStage() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 50);

        // start distribution period
        _startDistributionPeriod(_grantFund);

        // generate proposal targets
        address[] memory ajnaTokenTargets = new address[](1);
        ajnaTokenTargets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder2,
            1 * 1e18
        );

        // generate proposal message 
        string memory description = "Proposal for Ajna token transfer to tester address";

        // create and submit proposal
        TestProposal memory proposal = _createProposalStandard(_grantFund, _tokenHolder1, ajnaTokenTargets, values, proposalCalldata, description);

        // screening stage votes
        _screeningVote(_grantFund, _tokenHolder1, proposal.proposalId, 1 * 1e18);

        // skip forward to the funding stage
        vm.roll(_startBlock + 600_000);

        // check initial voting power
        uint256 votingPower = _getFundingVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 2_500_000_000_000_000 * 1e18);

        // check voting power won't change with token transfer to an address that didn't make it into the snapshot
        address nonVotingAddress = makeAddr("nonVotingAddress");
        changePrank(_tokenHolder1);
        _token.transfer(nonVotingAddress, 10_000_000 * 1e18);

        votingPower = _getFundingVotes(_grantFund, nonVotingAddress);
        assertEq(votingPower, 0);
        votingPower = _getFundingVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 2_500_000_000_000_000 * 1e18);
        assertEq(_grantFund.getFundingPowerVotes(2_500_000_000_000_000 * 1e18), 50_000_000 * 1e18);

        // incremental votes that will be added to proposals accumulator is the sqrt of the voter's voting power
        _fundingVote(_grantFund, _tokenHolder1, proposal.proposalId, voteYes, 25_000_000 * 1e18);

        // voting power reduced when voted in funding stage
        votingPower = _getFundingVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 1_875_000_000_000_000 * 1e18);
        assertEq(_grantFund.getFundingPowerVotes(625_000_000_000_000 * 1e18), 25_000_000 * 1e18);

        // check that additional votes on the same proposal will calculate an accumulated square
        _fundingVote(_grantFund, _tokenHolder1, proposal.proposalId, voteYes, 10_000_000 * 1e18);
        votingPower = _getFundingVotes(_grantFund, _tokenHolder1);
        assertEq(votingPower, 1_275_000_000_000_000 * 1e18);
        assertEq(_grantFund.getFundingPowerVotes(1_225_000_000_000_000 * 1e18), 35_000_000 * 1e18);

        // check revert if additional votes exceed the budget
        vm.expectRevert(IStandardFunding.InsufficientVotingPower.selector);
        _fundingVoteNoLog(_grantFund, _tokenHolder1, proposal.proposalId, 16_000_000 * 1e18);
    }

    function testPropose() external {
        // generate proposal targets
        address[] memory ajnaTokenTargets = new address[](1);
        ajnaTokenTargets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        // Eth to transfer is non zero
        values[0] = 1;

        // generate proposal calldata
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder2,
            1 * 1e18
        );

        // generate proposal message 
        string memory description = "Proposal for Ajna token transfer to tester address";

        // start distribution period
        _startDistributionPeriod(_grantFund);

        changePrank(_tokenHolder2);

        // should revert if target array size is greater than calldata and values size
        address[] memory invalidTargetsLength = new address[](2);
        invalidTargetsLength[0] = address(_token);
        invalidTargetsLength[1] = address(_token);
        uint256[] memory invalidValuesLength = new uint256[](2);
        invalidValuesLength[0] = 0;
        invalidValuesLength[1] = 0;
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(invalidTargetsLength, invalidValuesLength, proposalCalldata, description);

        // Skips to funding period
        vm.roll(_startBlock + 576_002);
        // should revert to submit proposal
        vm.expectRevert(IStandardFunding.ScreeningPeriodEnded.selector);
        _grantFund.proposeStandard(ajnaTokenTargets, values, proposalCalldata, description);

        vm.roll(_startBlock + 10);

        // should revert if Eth transfer is not zero
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(ajnaTokenTargets, values, proposalCalldata, description);

        // updating Eth value to transfer to 0
        values[0] = 0;

        // create and submit proposal
        TestProposal memory proposal = _createProposalStandard(_grantFund, _tokenHolder2, ajnaTokenTargets, values, proposalCalldata, description);
        
        // should revert if same proposal is proposed again
        vm.expectRevert(IFunding.ProposalAlreadyExists.selector);
        _grantFund.proposeStandard(ajnaTokenTargets, values, proposalCalldata, description);
        
        vm.roll(_startBlock + 10);

        // check proposal status
        IFunding.ProposalState proposalState = _grantFund.state(proposal.proposalId);
        assertEq(uint8(proposalState), uint8(IFunding.ProposalState.Active));

        // check proposal state
        (
            uint256 proposalId,
            uint256 distributionId,
            uint256 votesReceived,
            uint256 tokensRequested,
            int256 qvBudgetAllocated,
            bool executed
        ) = _grantFund.getProposalInfo(proposal.proposalId);

        assertEq(proposalId, proposal.proposalId);
        assertEq(distributionId, 1);
        assertEq(votesReceived, 0);
        assertEq(tokensRequested, 1 * 1e18);
        assertEq(qvBudgetAllocated, 0);
        assertFalse(executed);

        // should revert to find mechanism with invalid ProposalId
        vm.expectRevert(IFunding.ProposalNotFound.selector);
        _grantFund.findMechanismOfProposal(0x223);

        // check findMechanism identifies it as a standard proposal
        assert(_grantFund.findMechanismOfProposal(proposalId) == IFunding.FundingMechanism.Standard);
    }

    function testInvalidProposalCalldata() external {
        // start distribution period
        _startDistributionPeriod(_grantFund);

        // generate proposal targets
        address[] memory targets = new address[](1);
        targets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        uint256 proposalTokenAmount = 1 * 1e18;
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "burn(address,uint256)",
            address(_grantFund),
            proposalTokenAmount
        );

        // generate proposal message
        string memory description = "Proposal for Ajna token burn from the growth fund";

        // create proposal should revert since invalid burn operation was attempted
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(targets, values, proposalCalldata, description);
    }

    function testInvalidProposalTarget() external {
        // start distribution period
        _startDistributionPeriod(_grantFund);

        // generate proposal targets
        address[] memory targets = new address[](1);
        targets[0] = _tokenHolder1;

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder1,
            1 * 1e18
        );

        // generate proposal message
        string memory description = "Proposal for Ajna token transfer to tester address";

        // create proposal should revert since a non Ajna token contract target was used
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(targets, values, proposalCalldata, description);

        // create proposal withs no targets should revert
        targets = new address[](0);
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(targets, values, proposalCalldata, description);
    }

    function testVotesCast() external {
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 100);
        // start distribution period
        _startDistributionPeriod(_grantFund);
        uint24 distributionId = _grantFund.getDistributionId();

        vm.roll(_startBlock + 200);

        TestProposalParams[] memory testProposalParams = new TestProposalParams[](2);
        testProposalParams[0] = TestProposalParams(_tokenHolder1, 9_000_000 * 1e18);
        testProposalParams[1] = TestProposalParams(_tokenHolder2, 2_000_000 * 1e18);

        TestProposal[] memory testProposals = _createNProposals(_grantFund, _token, testProposalParams);

        // ensure that user has not voted
        uint256 screeningVotesCast = _grantFund.screeningVotesCast(distributionId, _tokenHolder1);
        assertEq(screeningVotesCast, 0);

        // cast screening stage vote
        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](2);
        screeningVoteParams[0] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[0].proposalId,
            votes: 20_000_000 * 1e18
        });
        screeningVoteParams[1] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[1].proposalId,
            votes: 30_000_000 * 1e18
        });

        _screeningVote(_grantFund, screeningVoteParams, _tokenHolder1);

        // check that user has voted
        screeningVotesCast = _grantFund.screeningVotesCast(distributionId, _tokenHolder1);
        assertEq(screeningVotesCast, 50_000_000 * 1e18);

        _screeningVote(_grantFund, _tokenHolder2, testProposals[1].proposalId, 5_000_000 * 1e18);

        screeningVotesCast = _grantFund.screeningVotesCast(distributionId, _tokenHolder2);
        assertEq(screeningVotesCast, 5_000_000 * 1e18);

        changePrank(_tokenHolder1);

        // skip to funding period
        vm.roll(_startBlock + 600_000);

        // should be false if user has not voted in funding stage but voted in screening stage
        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = _grantFund.getFundingVotesCast(distributionId, _tokenHolder1);
        assertEq(fundingVoteParams.length, 0);

        // voter allocates all of their voting power in support of the proposal
        _fundingVote(_grantFund, _tokenHolder1, testProposals[1].proposalId, voteNo, -50_000_000 * 1e18);
        // check if user vote is updated after voting in funding stage 
        fundingVoteParams = _grantFund.getFundingVotesCast(distributionId, _tokenHolder1);
        assertEq(fundingVoteParams.length, 1);
        assertEq(fundingVoteParams[0].proposalId, testProposals[1].proposalId);
        assertEq(fundingVoteParams[0].votesUsed, -50_000_000 * 1e18);

        // check revert if attempts to vote again
        assertInsufficientVotingPowerRevert(_grantFund, _tokenHolder1, testProposals[1].proposalId, -1);
    }

    /**
     *  @notice 14 voters consider 18 different proposals. 10 Make it through to the funding stage.
     */
    function testScreenProposalsCheckSorting() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 150);

        // start distribution period
        _startDistributionPeriod(_grantFund);
        uint24 distributionId = _grantFund.getDistributionId();

        vm.roll(_startBlock + 200);

        TestProposalParams[] memory testProposalParams = new TestProposalParams[](15);
        testProposalParams[0] = TestProposalParams(_tokenHolder1, 9_000_000 * 1e18);
        testProposalParams[1] = TestProposalParams(_tokenHolder2, 2_000_000 * 1e18);
        testProposalParams[2] = TestProposalParams(_tokenHolder3, 5_000_000 * 1e18);
        testProposalParams[3] = TestProposalParams(_tokenHolder4, 5_000_000 * 1e18);
        testProposalParams[4] = TestProposalParams(_tokenHolder5, 50_000 * 1e18);
        testProposalParams[5] = TestProposalParams(_tokenHolder6, 100_000 * 1e18);
        testProposalParams[6] = TestProposalParams(_tokenHolder7, 100_000 * 1e18);
        testProposalParams[7] = TestProposalParams(_tokenHolder8, 100_000 * 1e18);
        testProposalParams[8] = TestProposalParams(_tokenHolder9, 100_000 * 1e18);
        testProposalParams[9] = TestProposalParams(_tokenHolder10, 100_000 * 1e18);
        testProposalParams[10] = TestProposalParams(_tokenHolder11, 100_000 * 1e18);
        testProposalParams[11] = TestProposalParams(_tokenHolder12, 100_000 * 1e18);
        testProposalParams[12] = TestProposalParams(_tokenHolder13, 100_000 * 1e18);
        testProposalParams[13] = TestProposalParams(_tokenHolder14, 100_000 * 1e18);

        TestProposal[] memory testProposals = _createNProposals(_grantFund, _token, testProposalParams);

        // screen proposals
        _screeningVote(_grantFund, _tokenHolder1, testProposals[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder1));
        _screeningVote(_grantFund, _tokenHolder2, testProposals[1].proposalId, _getScreeningVotes(_grantFund, _tokenHolder2));
        _screeningVote(_grantFund, _tokenHolder3, testProposals[2].proposalId, _getScreeningVotes(_grantFund, _tokenHolder3));
        _screeningVote(_grantFund, _tokenHolder4, testProposals[3].proposalId, _getScreeningVotes(_grantFund, _tokenHolder4));
        _screeningVote(_grantFund, _tokenHolder5, testProposals[4].proposalId, _getScreeningVotes(_grantFund, _tokenHolder5));
        _screeningVote(_grantFund, _tokenHolder6, testProposals[5].proposalId, _getScreeningVotes(_grantFund, _tokenHolder6));
        _screeningVote(_grantFund, _tokenHolder7, testProposals[6].proposalId, _getScreeningVotes(_grantFund, _tokenHolder7));
        _screeningVote(_grantFund, _tokenHolder8, testProposals[7].proposalId, _getScreeningVotes(_grantFund, _tokenHolder8));
        _screeningVote(_grantFund, _tokenHolder9, testProposals[8].proposalId, _getScreeningVotes(_grantFund, _tokenHolder9));
        _screeningVote(_grantFund, _tokenHolder10, testProposals[9].proposalId, _getScreeningVotes(_grantFund, _tokenHolder10));

        // check top ten proposals
        GrantFund.Proposal[] memory screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 10);

        // one of the non-current top 10 is moved up to the top spot
        _screeningVote(_grantFund, _tokenHolder11, testProposals[10].proposalId, _getScreeningVotes(_grantFund, _tokenHolder11));
        _screeningVote(_grantFund, _tokenHolder12, testProposals[10].proposalId, _getScreeningVotes(_grantFund, _tokenHolder12));

        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 10);
        assertEq(screenedProposals[0].proposalId, testProposals[10].proposalId);
        assertEq(screenedProposals[0].votesReceived, 100_000_000 * 1e18);

        // another non-current top ten is moved up to the top spot
        _screeningVote(_grantFund, _tokenHolder13, testProposals[11].proposalId, _getScreeningVotes(_grantFund, _tokenHolder13));
        _screeningVote(_grantFund, _tokenHolder14, testProposals[11].proposalId, _getScreeningVotes(_grantFund, _tokenHolder14));
        _screeningVote(_grantFund, _tokenHolder15, testProposals[11].proposalId, _getScreeningVotes(_grantFund, _tokenHolder15));

        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 10);
        assertEq(screenedProposals[0].proposalId, testProposals[11].proposalId);
        assertEq(screenedProposals[0].votesReceived, 150_000_000 * 1e18);
        assertEq(screenedProposals[1].proposalId, testProposals[10].proposalId);
        assertEq(screenedProposals[1].votesReceived, 100_000_000 * 1e18);
    }

    function testScreenProposalsMulti() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 150);

        // start distribution period
        _startDistributionPeriod(_grantFund);
        uint24 distributionId = _grantFund.getDistributionId();

        vm.roll(_startBlock + 200);

        TestProposalParams[] memory testProposalParams = new TestProposalParams[](15);
        testProposalParams[0] = TestProposalParams(_tokenHolder1, 9_000_000 * 1e18);
        testProposalParams[1] = TestProposalParams(_tokenHolder2, 3_000_000 * 1e18);
        testProposalParams[2] = TestProposalParams(_tokenHolder3, 5_000_000 * 1e18);
        testProposalParams[3] = TestProposalParams(_tokenHolder4, 5_000_000 * 1e18);
        testProposalParams[4] = TestProposalParams(_tokenHolder5, 50_000 * 1e18);
        testProposalParams[5] = TestProposalParams(_tokenHolder6, 100_000 * 1e18);
        testProposalParams[6] = TestProposalParams(_tokenHolder7, 100_000 * 1e18);
        testProposalParams[7] = TestProposalParams(_tokenHolder8, 100_000 * 1e18);
        testProposalParams[8] = TestProposalParams(_tokenHolder9, 100_000 * 1e18);
        testProposalParams[9] = TestProposalParams(_tokenHolder10, 100_000 * 1e18);
        testProposalParams[10] = TestProposalParams(_tokenHolder11, 100_000 * 1e18);
        testProposalParams[11] = TestProposalParams(_tokenHolder12, 100_000 * 1e18);
        testProposalParams[12] = TestProposalParams(_tokenHolder13, 100_000 * 1e18);
        testProposalParams[13] = TestProposalParams(_tokenHolder14, 100_000 * 1e18);

        TestProposal[] memory testProposals = _createNProposals(_grantFund, _token, testProposalParams);

        // tokenholder 1 casts screening stage votes, split evenly across 10 proposals
        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](10);
        screeningVoteParams[0] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[0].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[1] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[1].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[2] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[2].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[3] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[3].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[4] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[4].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[5] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[5].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[6] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[6].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[7] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[7].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[8] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[8].proposalId,
            votes: 5_000_000 * 1e18
        });
        screeningVoteParams[9] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[9].proposalId,
            votes: 5_000_000 * 1e18
        });
        _screeningVote(_grantFund, screeningVoteParams, _tokenHolder1);

        // check top ten proposals
        GrantFund.Proposal[] memory screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 10);

        // two of the non-current top 10 are moved up to the top two spots
        screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](2);
                screeningVoteParams[0] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[10].proposalId,
            votes: 15_000_000 * 1e18
        });
        screeningVoteParams[1] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals[11].proposalId,
            votes: 15_000_000 * 1e18
        });
        _screeningVote(_grantFund, screeningVoteParams, _tokenHolder2);

        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 10);
        assertEq(screenedProposals[0].proposalId, testProposals[10].proposalId);
        assertEq(screenedProposals[0].votesReceived, 15_000_000 * 1e18);
        assertEq(screenedProposals[1].proposalId, testProposals[11].proposalId);
        assertEq(screenedProposals[1].votesReceived, 15_000_000 * 1e18);
    }

    function testStartNewDistributionPeriod() external {
        uint24 currentDistributionId = _grantFund.getDistributionId();
        assertEq(currentDistributionId, 0);

        _startDistributionPeriod(_grantFund);
        currentDistributionId = _grantFund.getDistributionId();
        assertEq(currentDistributionId, 1);

        (uint24 id, uint48 startBlock, uint48 endBlock, , uint256 fundingVotesCast, ) = _grantFund.getDistributionPeriodInfo(currentDistributionId);
        assertEq(id, currentDistributionId);
        assertEq(fundingVotesCast, 0);
        assertEq(startBlock, block.number);
        assertEq(endBlock, block.number + 648000);
        
        vm.roll(_startBlock + 100);
        currentDistributionId = _grantFund.getDistributionId();
        assertEq(currentDistributionId, 1);

        // check a new distribution period can't be started if already active
        vm.expectRevert(IStandardFunding.DistributionPeriodStillActive.selector);
        _grantFund.startNewDistributionPeriod();

        // skip forward past the end of the distribution period to allow starting a new distribution
        vm.roll(_startBlock + 650_000);

        _startDistributionPeriod(_grantFund);
        currentDistributionId = _grantFund.getDistributionId();
        assertEq(currentDistributionId, 2);
    }

    /**
     *  @notice Integration test of 7 proposals submitted, with 6 passing the screening stage. Five potential funding slates are tested.
     *  @dev    Maximum quarterly distribution is 10_000_000.
     *  @dev    Funded slate is executed.
     *  @dev    Reverts:
     *              - IStandardFunding.InsufficientVotingPower
     *              - IStandardFunding.ExecuteProposalInvalid
     *              - IFunding.ProposalNotSuccessful
     */
    function testDistributionPeriodEndToEnd() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 150);

        // start distribution period
        _startDistributionPeriod(_grantFund);

        uint24 distributionId = _grantFund.getDistributionId();

        (, , , uint128 gbc, , ) = _grantFund.getDistributionPeriodInfo(distributionId);

        assertEq(gbc, 15_000_000 * 1e18);

        TestProposalParams[] memory testProposalParams = new TestProposalParams[](7);
        testProposalParams[0] = TestProposalParams(_tokenHolder1, 8_500_000 * 1e18);
        testProposalParams[1] = TestProposalParams(_tokenHolder2, 5_000_000 * 1e18);
        testProposalParams[2] = TestProposalParams(_tokenHolder3, 5_000_000 * 1e18);
        testProposalParams[3] = TestProposalParams(_tokenHolder4, 5_000_000 * 1e18);
        testProposalParams[4] = TestProposalParams(_tokenHolder5, 50_000 * 1e18);
        testProposalParams[5] = TestProposalParams(_tokenHolder6, 100_000 * 1e18);
        testProposalParams[6] = TestProposalParams(_tokenHolder7, 100_000 * 1e18);

        // create 7 proposals paying out tokens
        TestProposal[] memory testProposals = _createNProposals(_grantFund, _token, testProposalParams);
        assertEq(testProposals.length, 7);

        vm.roll(_startBlock + 200);

        // screening period votes
        _screeningVote(_grantFund, _tokenHolder1, testProposals[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder1));
        _screeningVote(_grantFund, _tokenHolder2, testProposals[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder2));
        _screeningVote(_grantFund, _tokenHolder3, testProposals[1].proposalId, _getScreeningVotes(_grantFund, _tokenHolder3));
        _screeningVote(_grantFund, _tokenHolder4, testProposals[1].proposalId, _getScreeningVotes(_grantFund, _tokenHolder4));
        _screeningVote(_grantFund, _tokenHolder5, testProposals[2].proposalId, _getScreeningVotes(_grantFund, _tokenHolder5));
        _screeningVote(_grantFund, _tokenHolder6, testProposals[2].proposalId, _getScreeningVotes(_grantFund, _tokenHolder6));
        _screeningVote(_grantFund, _tokenHolder7, testProposals[3].proposalId, _getScreeningVotes(_grantFund, _tokenHolder7));
        _screeningVote(_grantFund, _tokenHolder8, testProposals[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder8));
        _screeningVote(_grantFund, _tokenHolder9, testProposals[4].proposalId, _getScreeningVotes(_grantFund, _tokenHolder9));
        _screeningVote(_grantFund, _tokenHolder10, testProposals[5].proposalId, _getScreeningVotes(_grantFund, _tokenHolder10));

        // check can't cast funding votes in the screening stage
        assertFundingVoteInvalidVoteRevert(_grantFund, _tokenHolder1, testProposals[0].proposalId, -50_000_000 * 1e18);

        /*********************/
        /*** Funding Stage ***/
        /*********************/

        // skip time to move from screening period to funding period
        vm.roll(_startBlock + 600_000);

        // check can't cast screening votes in the funding stage
        assertScreeningVoteInvalidVoteRevert(_grantFund, _tokenHolder11, testProposals[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder11));

        // check topTenProposals array is correct after screening period - only six should have advanced
        GrantFund.Proposal[] memory screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 6);
        assertEq(screenedProposals[0].proposalId, testProposals[0].proposalId);
        assertEq(screenedProposals[0].votesReceived, 150_000_000 * 1e18);
        assertEq(screenedProposals[1].proposalId, testProposals[1].proposalId);
        assertEq(screenedProposals[1].votesReceived, 100_000_000 * 1e18);
        assertEq(screenedProposals[2].proposalId, testProposals[2].proposalId);
        assertEq(screenedProposals[2].votesReceived, 100_000_000 * 1e18);
        assertEq(screenedProposals[3].proposalId, testProposals[3].proposalId);
        assertEq(screenedProposals[3].votesReceived, 50_000_000 * 1e18);
        assertEq(screenedProposals[4].proposalId, testProposals[4].proposalId);
        assertEq(screenedProposals[4].votesReceived, 50_000_000 * 1e18);
        assertEq(screenedProposals[5].proposalId, testProposals[5].proposalId);
        assertEq(screenedProposals[5].votesReceived, 50_000_000 * 1e18);

        // check can't cast funding vote on proposal that didn't make it through the screening stage
        assertFundingVoteInvalidVoteRevert(_grantFund, _tokenHolder1, testProposals[6].proposalId, 50_000_000 * 1e18);

        // funding period votes for two competing slates, 1, or 2 and 3
        _fundingVote(_grantFund, _tokenHolder1, screenedProposals[0].proposalId, voteYes, 50_000_000 * 1e18);
        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        _fundingVote(_grantFund, _tokenHolder2, screenedProposals[1].proposalId, voteYes, 50_000_000 * 1e18);
        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));

        // tokenholder 3 votes on all proposals in one transactions
        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = new IStandardFunding.FundingVoteParams[](6);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[0].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[1].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[2] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[2].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[3] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[3].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[4] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[4].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[5] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[5].proposalId,
            votesUsed: -10_000_000 * 1e18
        });
        _fundingVoteMulti(_grantFund, fundingVoteParams, _tokenHolder3);
        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));

        // tokenholder4 votes on two proposals in one transaction, but tries to use more than their available budget
        fundingVoteParams = new IStandardFunding.FundingVoteParams[](2);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[3].proposalId,
            votesUsed: 40_000_000 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[5].proposalId,
            votesUsed: -40_000_000 * 1e18
        });
        changePrank(_tokenHolder4);
        vm.expectRevert(IStandardFunding.InsufficientVotingPower.selector);
        _grantFund.fundingVote(fundingVoteParams);

        // tokenholder4 divides their full votingpower into two proposals in one transaction
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[3].proposalId,
            votesUsed: 40_000_000 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals[5].proposalId,
            votesUsed: -30_000_000 * 1e18
        });
        _fundingVoteMulti(_grantFund, fundingVoteParams, _tokenHolder4);
        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));

        changePrank(_tokenHolder5);
        vm.expectRevert(IStandardFunding.InsufficientVotingPower.selector);
        _fundingVoteNoLog(_grantFund, _tokenHolder5, screenedProposals[3].proposalId, -2_600_000_000_000_000 * 1e18);

        // check tokenHolder5 partial vote budget calculations
        _fundingVote(_grantFund, _tokenHolder5, screenedProposals[5].proposalId, voteNo, -45_000_000 * 1e18);
        screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));

        // should revert if tokenHolder5 attempts to change the direction of a vote
        changePrank(_tokenHolder5);
        vm.expectRevert(IStandardFunding.FundingVoteWrongDirection.selector);
        _fundingVoteNoLog(_grantFund, _tokenHolder5, screenedProposals[5].proposalId, 5_000_000 * 1e18);

        // check remaining votes available to the above token holders
        (uint128 voterPower, uint128 votingPowerRemaining, uint256 votesCast) = _grantFund.getVoterInfo(distributionId, _tokenHolder1);
        assertEq(voterPower, 2_500_000_000_000_000 * 1e18);
        assertEq(votingPowerRemaining, 0);
        assertEq(votesCast, 1);
        (voterPower, votingPowerRemaining, votesCast) = _grantFund.getVoterInfo(distributionId, _tokenHolder2);
        assertEq(voterPower, 2_500_000_000_000_000 * 1e18);
        assertEq(votingPowerRemaining, 0);
        assertEq(votesCast, 1);
        (voterPower, votingPowerRemaining, votesCast) = _grantFund.getVoterInfo(distributionId, _tokenHolder3);
        assertEq(voterPower, 2_500_000_000_000_000 * 1e18);
        assertEq(votingPowerRemaining, 195_000_000_000_000 * 1e18);
        assertEq(votesCast, 6);
        (voterPower, votingPowerRemaining, votesCast) = _grantFund.getVoterInfo(distributionId, _tokenHolder4);
        assertEq(voterPower, 2_500_000_000_000_000 * 1e18);
        assertEq(votingPowerRemaining, 0);
        assertEq(uint256(votingPowerRemaining), _getFundingVotes(_grantFund, _tokenHolder4));
        assertEq(votesCast, 2);
        (voterPower, votingPowerRemaining, votesCast) = _grantFund.getVoterInfo(distributionId, _tokenHolder5);
        assertEq(voterPower, 2_500_000_000_000_000 * 1e18);
        assertEq(votingPowerRemaining, 475_000_000_000_000 * 1e18);
        assertEq(uint256(votingPowerRemaining), _getFundingVotes(_grantFund, _tokenHolder5));
        assertEq(votesCast, 1);

        assertEq(_grantFund.getFundingPowerVotes(2_500_000_000_000_000 * 1e18), 50_000_000 * 1e18);

        uint256[] memory potentialProposalSlate = new uint256[](2);
        potentialProposalSlate[0] = screenedProposals[0].proposalId;

        // including Proposal in potentialProposalSlate that is not in topTenProposal (funding Stage)
        potentialProposalSlate[1] = testProposals[6].proposalId;
        
        // ensure updateSlate won't allow if called before DistributionPeriod starts
        vm.expectRevert(IStandardFunding.InvalidProposalSlate.selector);
        _grantFund.updateSlate(potentialProposalSlate, distributionId);

        /************************/
        /*** Challenge Period ***/
        /************************/

        // skip to the end of the DistributionPeriod
        vm.roll(_startBlock + 650_000);

        // ensure updateSlate won't allow if slate has a proposal that is not in topTenProposal (funding Stage)
        vm.expectRevert(IStandardFunding.InvalidProposalSlate.selector);
        _grantFund.updateSlate(potentialProposalSlate, distributionId);

        // Updating potential Proposal Slate to include proposal that is in topTenProposal (funding Stage)
        potentialProposalSlate = new uint256[](4);
        potentialProposalSlate[0] = screenedProposals[0].proposalId;
        potentialProposalSlate[1] = screenedProposals[1].proposalId;
        potentialProposalSlate[2] = screenedProposals[3].proposalId;
        potentialProposalSlate[3] = screenedProposals[4].proposalId;

        // ensure updateSlate won't allow exceeding the GBC
        vm.expectRevert(IStandardFunding.InvalidProposalSlate.selector);
        _grantFund.updateSlate(potentialProposalSlate, distributionId);
        (, , , , , bytes32 slateHash) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(slateHash, 0);

        // ensure updateSlate will allow a valid slate
        potentialProposalSlate = new uint256[](1);
        potentialProposalSlate[0] = screenedProposals[3].proposalId;
        vm.expectEmit(true, true, false, true);
        emit FundedSlateUpdated(distributionId, _grantFund.getSlateHash(potentialProposalSlate));
        bool proposalSlateUpdated = _grantFund.updateSlate(potentialProposalSlate, distributionId);
        assertTrue(proposalSlateUpdated);

        // should not update slate if current funding slate is same as potentialProposalSlate 
        assertFalse(_grantFund.updateSlate(potentialProposalSlate, distributionId));

        // ensure updateSlate will revert if a proposal had negative votes
        potentialProposalSlate[0] = screenedProposals[5].proposalId;
        vm.expectRevert(IStandardFunding.InvalidProposalSlate.selector);
        _grantFund.updateSlate(potentialProposalSlate, distributionId);

        // check slate hash
        (, , , , , slateHash) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(slateHash, 0x55e999c21a3faf0bdde6c3dbdeb20311552e5ac9eb607c60f379172c78240156);
        // check funded proposal slate matches expected state
        GrantFund.Proposal[] memory fundedProposalSlate = _getProposalListFromProposalIds(_grantFund, _grantFund.getFundedProposalSlate(slateHash));
        assertEq(fundedProposalSlate.length, 1);
        assertEq(fundedProposalSlate[0].proposalId, screenedProposals[3].proposalId);

        // ensure updateSlate will update the currentSlateHash when a superior slate is presented
        potentialProposalSlate = new uint256[](2);
        potentialProposalSlate[0] = screenedProposals[3].proposalId;
        potentialProposalSlate[1] = screenedProposals[4].proposalId;
        vm.expectEmit(true, true, false, true);
        emit FundedSlateUpdated(distributionId, _grantFund.getSlateHash(potentialProposalSlate));
        proposalSlateUpdated = _grantFund.updateSlate(potentialProposalSlate, distributionId);
        assertTrue(proposalSlateUpdated);
        // check slate hash
        (, , , , , slateHash) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(slateHash, 0xb72e359fc43715be27ea92fd3c6675ddc7ebca9c2f6ac8b8f1a8195c0b579067);
        // check funded proposal slate matches expected state
        fundedProposalSlate = _getProposalListFromProposalIds(_grantFund, _grantFund.getFundedProposalSlate(slateHash));
        assertEq(fundedProposalSlate.length, 2);
        assertEq(fundedProposalSlate[0].proposalId, screenedProposals[3].proposalId);
        assertEq(fundedProposalSlate[1].proposalId, screenedProposals[4].proposalId);

        // check that the slate isn't updated if a slate contains duplicate proposals
        potentialProposalSlate = new uint256[](2);
        potentialProposalSlate[0] = screenedProposals[0].proposalId;
        potentialProposalSlate[1] = screenedProposals[0].proposalId;
        vm.expectRevert(IStandardFunding.InvalidProposalSlate.selector);
        _grantFund.updateSlate(potentialProposalSlate, distributionId);

        // ensure an additional update can be made to the optimized slate
        potentialProposalSlate = new uint256[](2);
        potentialProposalSlate[0] = screenedProposals[0].proposalId;
        potentialProposalSlate[1] = screenedProposals[4].proposalId;
        vm.expectEmit(true, true, false, true);
        emit FundedSlateUpdated(distributionId, _grantFund.getSlateHash(potentialProposalSlate));
        proposalSlateUpdated = _grantFund.updateSlate(potentialProposalSlate, distributionId);
        assertTrue(proposalSlateUpdated);
        // check slate hash
        (, , , , , slateHash) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(slateHash, 0x59445eae0a1138f27e258b071c6210dbd8fec6d1d7da077f3586a8aaa89806ce);
        // check funded proposal slate matches expected state
        fundedProposalSlate = _getProposalListFromProposalIds(_grantFund, _grantFund.getFundedProposalSlate(slateHash));
        assertEq(fundedProposalSlate.length, 2);
        assertEq(fundedProposalSlate[0].proposalId, screenedProposals[0].proposalId);
        assertEq(fundedProposalSlate[1].proposalId, screenedProposals[4].proposalId);

        // check that a different slate which distributes more tokens (less than gbc), but has less votes won't pass
        potentialProposalSlate = new uint256[](2);
        potentialProposalSlate[0] = screenedProposals[2].proposalId;
        potentialProposalSlate[1] = screenedProposals[3].proposalId;
        assertInferiorSlateFalse(_grantFund, potentialProposalSlate, distributionId);

        // check funded proposal slate wasn't updated
        (, , , , , slateHash) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(slateHash, 0x59445eae0a1138f27e258b071c6210dbd8fec6d1d7da077f3586a8aaa89806ce);
        fundedProposalSlate = _getProposalListFromProposalIds(_grantFund, _grantFund.getFundedProposalSlate(slateHash));
        assertEq(fundedProposalSlate.length, 2);
        assertEq(fundedProposalSlate[0].proposalId, screenedProposals[0].proposalId);
        assertEq(fundedProposalSlate[1].proposalId, screenedProposals[4].proposalId);

        // check can't execute proposals prior to the end of the challenge period
        vm.expectRevert(IStandardFunding.ExecuteProposalInvalid.selector);
        _grantFund.executeStandard(testProposals[0].targets, testProposals[0].values, testProposals[0].calldatas, keccak256(bytes(testProposals[0].description)));

        // should revert if user tries to claim reward in before challenge Period ends
        vm.expectRevert(IStandardFunding.ChallengePeriodNotEnded.selector);
        _grantFund.claimDelegateReward(distributionId);

        /********************************/
        /*** Execute Funded Proposals ***/
        /********************************/

        // skip to the end of the Distribution's challenge period
        vm.roll(_startBlock + 700_000);

        // execute funded proposals
        _executeProposal(_grantFund, _token, testProposals[0]);
        _executeProposal(_grantFund, _token, testProposals[4]);

        // check the status of unfunded proposals is defeated
        assertFalse(uint8(_grantFund.state(testProposals[1].proposalId)) == uint8(IFunding.ProposalState.Succeeded));
        assertEq(uint8(_grantFund.state(testProposals[1].proposalId)), uint8(IFunding.ProposalState.Defeated));

        // check that shouldn't be able to execute unfunded proposals
        vm.expectRevert(IFunding.ProposalNotSuccessful.selector);
        _grantFund.executeStandard(testProposals[1].targets, testProposals[1].values, testProposals[1].calldatas, keccak256(bytes(testProposals[1].description)));

        // check that shouldn't be able to execute a proposal twice
        vm.expectRevert(IFunding.ProposalNotSuccessful.selector);
        _grantFund.executeStandard(testProposals[0].targets, testProposals[0].values, testProposals[0].calldatas, keccak256(bytes(testProposals[0].description)));

        /******************************/
        /*** Claim Delegate Rewards ***/
        /******************************/

        // Claim delegate reward for all delegatees
        // delegates who didn't vote with their full power receive fewer rewards
        delegateRewards = _grantFund.getDelegateReward(distributionId, _tokenHolder1);
        assertEq(delegateRewards, 316_990.701606086221470836 * 1e18);
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder1,
                distributionId_:   distributionId,
                claimedReward_:    delegateRewards
            }
        );
        delegateRewards = _grantFund.getDelegateReward(distributionId, _tokenHolder2);
        assertEq(delegateRewards, 316_990.701606086221470836 * 1e18);
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder2,
                distributionId_:   distributionId,
                claimedReward_:    delegateRewards
            }
        );
        delegateRewards = _grantFund.getDelegateReward(distributionId, _tokenHolder3);
        assertEq(delegateRewards, 292_265.426880811496196111 * 1e18);
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder3,
                distributionId_:   distributionId,
                claimedReward_:    delegateRewards
            }
        );
        delegateRewards = _grantFund.getDelegateReward(distributionId, _tokenHolder4);
        assertEq(delegateRewards, 316_990.701606086221470836 * 1e18);
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder4,
                distributionId_:   distributionId,
                claimedReward_:    delegateRewards
            }
        );
        delegateRewards = _grantFund.getDelegateReward(distributionId, _tokenHolder5);
        assertEq(delegateRewards, 256_762.468300929839391377 * 1e18);
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder5,
                distributionId_:   distributionId,
                claimedReward_:    delegateRewards
            }
        );

        // should revert as _tokenHolder5 already claimed his reward
        vm.expectRevert(IStandardFunding.RewardAlreadyClaimed.selector);
        _grantFund.claimDelegateReward(distributionId);

        // transfers 0 ajna Token as _tokenHolder6 has not participated in funding stage
        _claimDelegateReward(
            {
                grantFund_:        _grantFund,
                voter_:            _tokenHolder6,
                distributionId_:   distributionId,
                claimedReward_:    0
            }
        );

        // should revert as _tokenHolder14 has not participated in screening stage
        changePrank(_tokenHolder14);
        vm.expectRevert(IStandardFunding.DelegateRewardInvalid.selector);
        _grantFund.claimDelegateReward(distributionId);
    }

    /**
     *  @notice Test GBC calculations for 4 consecutive distributions.
     */ 
    function testMultipleDistribution() external {
        // 14 tokenholders self delegate their tokens to enable voting on the proposals
        _selfDelegateVoters(_token, _votersArr);

        vm.roll(_startBlock + 150);

        /*********************************/
        /*** First Distribution Period ***/
        /*********************************/

        // start first distribution
        _startDistributionPeriod(_grantFund);

        uint24 distributionId = _grantFund.getDistributionId();

        (, , , uint128 gbc_distribution1, , ) = _grantFund.getDistributionPeriodInfo(distributionId);

        assertEq(gbc_distribution1, 15_000_000 * 1e18);
        
        TestProposalParams[] memory testProposalParams_distribution1 = new TestProposalParams[](1);
        testProposalParams_distribution1[0] = TestProposalParams(_tokenHolder1, 8_500_000 * 1e18);

        // create 1 proposal paying out tokens
        TestProposal[] memory testProposals_distribution1 = _createNProposals(_grantFund, _token, testProposalParams_distribution1);
        assertEq(testProposals_distribution1.length, 1);

        vm.roll(_startBlock + 200);

        // screening period votes
        _screeningVote(_grantFund, _tokenHolder1, testProposals_distribution1[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder1));

        // skip time to move from screening period to funding period
        vm.roll(_startBlock + 600_000);

        // check topTenProposals array is correct after screening period - only 1 should have advanced
        GrantFund.Proposal[] memory screenedProposals_distribution1 = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals_distribution1.length, 1);

        // funding period votes
        _fundingVote(_grantFund, _tokenHolder1, screenedProposals_distribution1[0].proposalId, voteYes, 50_000_000 * 1e18);

        // skip to the Challenge period
        vm.roll(_startBlock + 650_000);

        uint256[] memory potentialProposalSlate = new uint256[](1);
        potentialProposalSlate[0] = screenedProposals_distribution1[0].proposalId;

        // updateSlate
        _grantFund.updateSlate(potentialProposalSlate, distributionId);

        // skip to the end of Challenge period
        vm.roll(_startBlock + 700_000);

        // check proposal status isn't defeated
        IFunding.ProposalState proposalState = _grantFund.state(testProposals_distribution1[0].proposalId);
        assert(uint8(proposalState) != uint8(IFunding.ProposalState.Defeated));

        // check proposal status is succeeded
        proposalState = _grantFund.state(testProposals_distribution1[0].proposalId);
        assertEq(uint8(proposalState), uint8(IFunding.ProposalState.Succeeded));

        // execute funded proposals
        _executeProposal(_grantFund, _token, testProposals_distribution1[0]);

        // check proposal status updates to executed
        proposalState = _grantFund.state(testProposals_distribution1[0].proposalId);
        assertEq(uint8(proposalState), uint8(IFunding.ProposalState.Executed));

        /**********************************/
        /*** Second Distribution Period ***/
        /**********************************/

        // start second distribution
        _startDistributionPeriod(_grantFund);

        uint24 distributionId2 = _grantFund.getDistributionId();

        (, , , uint128 gbc_distribution2, , ) = _grantFund.getDistributionPeriodInfo(distributionId2);

        assertEq(gbc_distribution2, 14_745_000 * 1e18);
        
        TestProposalParams[] memory testProposalParams_distribution2 = new TestProposalParams[](1);
        testProposalParams_distribution2[0] = TestProposalParams(_tokenHolder1, 8_200_000 * 1e18);

        // create 1 proposal paying out tokens
        TestProposal[] memory testProposals_distribution2 = _createNProposals(_grantFund, _token, testProposalParams_distribution2);
        assertEq(testProposals_distribution2.length, 1);

        vm.roll(_startBlock + 700_200);

        // screening period votes
        _screeningVote(_grantFund, _tokenHolder1, testProposals_distribution2[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder1));

        // check revert if attempts to cast screening votes on proposals from first distribution period
        changePrank(_tokenHolder10);
        vm.expectRevert(IStandardFunding.InvalidVote.selector);
        _screeningVoteNoLog(_grantFund, _tokenHolder10, testProposals_distribution1[0].proposalId, 50_000_000 * 1e18);

        IStandardFunding.ScreeningVoteParams[] memory screeningVoteParams = new IStandardFunding.ScreeningVoteParams[](2);
        screeningVoteParams[0] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals_distribution1[0].proposalId,
            votes: 20_000_000 * 1e18
        });
        screeningVoteParams[1] = IStandardFunding.ScreeningVoteParams({
            proposalId: testProposals_distribution2[0].proposalId,
            votes: 20_000_000 * 1e18
        });
        vm.expectRevert(IStandardFunding.InvalidVote.selector);
        _grantFund.screeningVote(screeningVoteParams);

        // skip time to move from screening period to funding period
        vm.roll(_startBlock + 1_300_000);

        // check topTenProposals array is correct after screening period - only 1 should have advanced
        GrantFund.Proposal[] memory screenedProposals_distribution2 = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId2));
        assertEq(screenedProposals_distribution2.length, 1);

        // funding period votes
        _fundingVote(_grantFund, _tokenHolder1, screenedProposals_distribution2[0].proposalId, voteYes, 50_000_000 * 1e18);

        // check revert if attempts to cast funding votes on proposals from first distribution period
        changePrank(_tokenHolder10);
        vm.expectRevert(IStandardFunding.InvalidVote.selector);
        _fundingVoteNoLog(_grantFund, _tokenHolder10, testProposals_distribution1[0].proposalId, 50_000_000 * 1e18);

        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = new IStandardFunding.FundingVoteParams[](6);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals_distribution2[0].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: screenedProposals_distribution1[0].proposalId,
            votesUsed: 21_000_000 * 1e18
        });
        vm.expectRevert(IStandardFunding.InvalidVote.selector);
        _grantFund.fundingVote(fundingVoteParams);

        // skip to the Challenge period
        vm.roll(_startBlock + 1_350_000);

        uint256[] memory potentialProposalSlate_distribution2 = new uint256[](1);
        potentialProposalSlate_distribution2[0] = screenedProposals_distribution2[0].proposalId;

        // updateSlate
        _grantFund.updateSlate(potentialProposalSlate_distribution2, distributionId2);

        /*********************************/
        /*** Third Distribution Period ***/
        /*********************************/

        // start third distribution before executing proposals of second distribution
        _startDistributionPeriod(_grantFund);

        uint24 distributionId3 = _grantFund.getDistributionId();

        (, , , uint128 gbc_distribution3, , ) = _grantFund.getDistributionPeriodInfo(distributionId3);

        assertEq(gbc_distribution3, 14_302_650 * 1e18);

        // skip to the end of Challenge period
        vm.roll(_startBlock + 1_400_000);

        // execute funded proposals
        _executeProposal(_grantFund, _token, testProposals_distribution2[0]);
        
        TestProposalParams[] memory testProposalParams_distribution3 = new TestProposalParams[](1);
        testProposalParams_distribution3[0] = TestProposalParams(_tokenHolder1, 7_000_000 * 1e18);

        // create 1 proposal paying out tokens
        TestProposal[] memory testProposals_distribution3 = _createNProposals(_grantFund, _token, testProposalParams_distribution3);
        assertEq(testProposals_distribution3.length, 1);

        vm.roll(_startBlock + 1_400_200);

        // screening period votes
        _screeningVote(_grantFund, _tokenHolder1, testProposals_distribution3[0].proposalId, _getScreeningVotes(_grantFund, _tokenHolder1));

        // skip time to move from screening period to funding period
        vm.roll(_startBlock + 1_990_000);

        // check topTenProposals array is correct after screening period - only 1 should have advanced
        GrantFund.Proposal[] memory screenedProposals_distribution3 = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId3));
        assertEq(screenedProposals_distribution3.length, 1);

        // funding period votes
        _fundingVote(_grantFund, _tokenHolder1, screenedProposals_distribution3[0].proposalId, voteYes, 50_000_000 * 1e18);

        // skip to the Challenge period
        vm.roll(_startBlock + 2_000_000);

        uint256[] memory potentialProposalSlate_distribution3 = new uint256[](1);
        potentialProposalSlate_distribution3[0] = screenedProposals_distribution3[0].proposalId;

        // updateSlate
        _grantFund.updateSlate(potentialProposalSlate_distribution3, distributionId3);

        // skip to the end of Challenge period
        vm.roll(_startBlock + 2_100_000);

        // execute funded proposals
        _executeProposal(_grantFund, _token, testProposals_distribution3[0]);

        // start third distribution
        _startDistributionPeriod(_grantFund);

        uint24 distributionId4 = _grantFund.getDistributionId();

        (, , , uint128 gbc_distribution4, , ) = _grantFund.getDistributionPeriodInfo(distributionId4);

        assertEq(gbc_distribution4, 14_289_000 * 1e18);
    }

    // test that three people with fewer tokens should be able to out vote 1 person with more
    function testQuadraticVotingTally() external {
        // create new test address just for this test
        address testAddress1   = makeAddr("testAddress1");
        address testAddress2   = makeAddr("testAddress2");
        address testAddress3   = makeAddr("testAddress3");
        address testAddress4   = makeAddr("testAddress4");
        _votersArr = new address[](4);
        _votersArr[0] = testAddress1;
        _votersArr[1] = testAddress2;
        _votersArr[2] = testAddress3;
        _votersArr[3] = testAddress4;

        // transfer ajna tokens to the new address
        changePrank(_tokenDeployer);
        _token.transfer(testAddress1, 4 * 1e18);
        _token.transfer(testAddress2, 3 * 1e18);
        _token.transfer(testAddress3, 3 * 1e18);
        _token.transfer(testAddress4, 3 * 1e18);

        // new addresses self delegate
        changePrank(testAddress1);
        _token.delegate(testAddress1);
        changePrank(testAddress2);
        _token.delegate(testAddress2);
        changePrank(testAddress3);
        _token.delegate(testAddress3);
        changePrank(testAddress4);
        _token.delegate(testAddress4);

        vm.roll(_startBlock + 150);

        // start distribution period
        _startDistributionPeriod(_grantFund);
        uint24 distributionId = _grantFund.getDistributionId();

        // generate proposal targets
        address[] memory ajnaTokenTargets = new address[](1);
        ajnaTokenTargets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            testAddress1,
            10 * 1e18
        );
        TestProposal memory proposal = _createProposalStandard(_grantFund, testAddress1, ajnaTokenTargets, values, proposalCalldata, "Proposal for Ajna token transfer to tester address 1");

        proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            testAddress2,
            7 * 1e18
        );
        TestProposal memory proposal2 = _createProposalStandard(_grantFund, testAddress2, ajnaTokenTargets, values, proposalCalldata, "Proposal 2 for Ajna token transfer to tester address 2");

        proposalCalldata = new bytes[](1);
        proposalCalldata[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            testAddress3,
            6 * 1e18
        );
        TestProposal memory proposal3 = _createProposalStandard(_grantFund, testAddress3, ajnaTokenTargets, values, proposalCalldata, "Proposal 2 for Ajna token transfer to tester address 2");

        vm.roll(_startBlock + 300);

        // screening period votes
        _screeningVote(_grantFund, testAddress1, proposal.proposalId, 4 * 1e18);
        _screeningVote(_grantFund, testAddress2, proposal2.proposalId, 3 * 1e18);
        _screeningVote(_grantFund, testAddress3, proposal3.proposalId, 3 * 1e18);


        // skip forward to the funding stage
        vm.roll(_startBlock + 600_000);

        GrantFund.Proposal[] memory screenedProposals = _getProposalListFromProposalIds(_grantFund, _grantFund.getTopTenProposals(distributionId));
        assertEq(screenedProposals.length, 3);
        assertEq(screenedProposals[0].proposalId, proposal.proposalId);
        assertEq(screenedProposals[0].votesReceived, 4 * 1e18);
        assertEq(screenedProposals[1].proposalId, proposal2.proposalId);
        assertEq(screenedProposals[1].votesReceived, 3 * 1e18);
        assertEq(screenedProposals[2].proposalId, proposal3.proposalId);
        assertEq(screenedProposals[2].votesReceived, 3 * 1e18);

        // check initial voting power
        uint256 votingPower = _getFundingVotes(_grantFund, testAddress1);
        assertEq(votingPower, 16 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress2);
        assertEq(votingPower, 9 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress3);
        assertEq(votingPower, 9 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress4);
        assertEq(votingPower, 9 * 1e18);

        _fundingVote(_grantFund, testAddress1, proposal.proposalId, voteYes, 4 * 1e18);

        IStandardFunding.FundingVoteParams[] memory fundingVoteParams = new IStandardFunding.FundingVoteParams[](2);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: proposal2.proposalId,
            votesUsed: 2 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: proposal3.proposalId,
            votesUsed: 2 * 1e18
        });
        _fundingVoteMulti(_grantFund, fundingVoteParams, testAddress2);

        fundingVoteParams = new IStandardFunding.FundingVoteParams[](2);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: proposal2.proposalId,
            votesUsed: 2 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: proposal3.proposalId,
            votesUsed: 2 * 1e18
        });
        _fundingVoteMulti(_grantFund, fundingVoteParams, testAddress3);

        fundingVoteParams = new IStandardFunding.FundingVoteParams[](2);
        fundingVoteParams[0] = IStandardFunding.FundingVoteParams({
            proposalId: proposal2.proposalId,
            votesUsed: 2 * 1e18
        });
        fundingVoteParams[1] = IStandardFunding.FundingVoteParams({
            proposalId: proposal3.proposalId,
            votesUsed: 2 * 1e18
        });
        _fundingVoteMulti(_grantFund, fundingVoteParams, testAddress4);

        // check voting power after voting
        votingPower = _getFundingVotes(_grantFund, testAddress1);
        assertEq(votingPower, 0 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress2);
        assertEq(votingPower, 1 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress3);
        assertEq(votingPower, 1 * 1e18);
        votingPower = _getFundingVotes(_grantFund, testAddress4);
        assertEq(votingPower, 1 * 1e18);

        // skip to the DistributionPeriod
        vm.roll(_startBlock + 650_000);

        // verify that even without using their full voting power,
        // several smaller token holders are able to outvote a larger token holder
        uint256[] memory proposalSlate = new uint256[](1);
        proposalSlate[0] = proposal.proposalId;
        assertTrue(_grantFund.updateSlate(proposalSlate, distributionId));

        proposalSlate = new uint256[](1);
        proposalSlate[0] = proposal2.proposalId;
        assertTrue(_grantFund.updateSlate(proposalSlate, distributionId));

        proposalSlate = new uint256[](2);
        proposalSlate[0] = proposal2.proposalId;
        proposalSlate[1] = proposal3.proposalId;
        assertTrue(_grantFund.updateSlate(proposalSlate, distributionId));
    }

    function testFuzzTopTenProposalandDelegateReward(uint256 noOfVoters_, uint256 noOfProposals_) external {

        /******************************/
        /*** Top ten proposals fuzz ***/
        /******************************/

        uint256 noOfVoters = bound(noOfVoters_, 1, 500);
        uint256 noOfProposals = bound(noOfProposals_, 1, 50);

        vm.roll(_startBlock + 20);

        // Initialize N voter addresses 
        address[] memory voters = _getVoters(noOfVoters);
        assertEq(voters.length, noOfVoters);

        // Transfer random ajna tokens to all voters and self delegate
        uint256[] memory votes = _setVotingPower(noOfVoters, voters, _token, _tokenDeployer);
        assertEq(votes.length, noOfVoters);

        vm.roll(block.number + 100);

        _startDistributionPeriod(_grantFund);

        vm.roll(block.number + 100);

        // ensure user gets the vote for screening stage
        for(uint i = 0; i < noOfVoters; i++) {
            assertEq(votes[i], _getScreeningVotes(_grantFund, voters[i]));
        }

        uint24 distributionId = _grantFund.getDistributionId();

        // submit N proposals
        TestProposal[] memory proposals = _getProposals(noOfProposals, _grantFund, _tokenHolder1, _token);

        // Each voter votes on a random proposal from all Proposals
        for(uint i = 0; i < noOfVoters; i++) {
            uint256 randomProposalIndex = _getRandomProposal(noOfProposals);

            uint256 randomProposalId = proposals[randomProposalIndex].proposalId;

            noOfVotesOnProposal[randomProposalId] += votes[i];

            _screeningVote(_grantFund, voters[i], randomProposalId, _getScreeningVotes(_grantFund, voters[i]));
        }

        // calculate top 10 proposals based on total vote casted on each proposal
        for(uint i = 0; i < noOfProposals; i++) {
            uint256 currentProposalId = proposals[i].proposalId;
            uint256 votesOnCurrentProposal = noOfVotesOnProposal[currentProposalId];
            uint256 lengthOfArray = topTenProposalIds.length;

            // only add proposals having atleast a vote
            if (votesOnCurrentProposal > 0) {

                // if there are less than 10 proposals in topTenProposalIds , add current proposals and sort topTenProposalIds based on Votes
                if (lengthOfArray < 10) {
                    topTenProposalIds.push(currentProposalId);

                    // ensure if there are more than 1 proposalId in topTenProposalIds to sort  
                    if(topTenProposalIds.length > 1) {
                        _insertionSortProposalsByVotes(topTenProposalIds); 
                    }
                }

                // if there are 10 proposals in topTenProposalIds, check new proposal has more votes than the last proposal in topTenProposalIds
                else if(noOfVotesOnProposal[topTenProposalIds[lengthOfArray - 1]] < votesOnCurrentProposal) {

                    // remove last proposal with least no of vote in topTenProposalIds
                    topTenProposalIds.pop();

                    // add new proposal with more votes than last
                    topTenProposalIds.push(currentProposalId);

                    // sort topTenProposalIds
                    _insertionSortProposalsByVotes(topTenProposalIds);
                }
            }
        }
        
        // get top ten proposals from contract
        uint256[] memory topTenProposalIdsFromContract = _grantFund.getTopTenProposals(distributionId);

        // ensure the no of proposals are correct
        assertEq(topTenProposalIds.length, topTenProposalIdsFromContract.length);

        for (uint i = 0; i < topTenProposalIds.length; i++) {
            // ensure that each proposal in topTenProposalIdsFromContract is correct
            assertEq(topTenProposalIds[i], topTenProposalIdsFromContract[i]);
        }

        /******************************/
        /*** Delegate rewards fuzz  ***/
        /******************************/

        // skip to funding stage
        vm.roll(block.number + 600_000);

        // gbc = 3% of treasury
        uint256 gbc = Maths.wmul(treasury, 0.03 * 1e18);

        uint256 totalBudgetAllocated;

        // try to allocalate budget to all top ten proposals i.e. all are in final check slate
        for(uint i = 0; i < noOfVoters; i++) {
            // get proposal Id of proposal to vote
            uint256 proposalId = topTenProposalIds[i % topTenProposalIds.length];

            // check if proposalId is already there in potential proposal slate
            if (_findProposalIndex(proposalId, potentialProposalsSlate) == -1) {
                // add proposalId in potential proposal slate for check slate if it isn't already present
                potentialProposalsSlate.push(proposalId);
            }

            // calculate and allocate all qvBudget of the voter to the proposal
            uint256 budgetAllocated = votes[i];
            totalBudgetAllocated += Maths.wpow(budgetAllocated, 2);
            _fundingVote(_grantFund, voters[i], proposalId, voteYes, int256(budgetAllocated));
        }

        // skip to challenge period
        vm.roll(block.number + 50_000);

        // get an array of proposalIds that were funded and requested less tokens than the GBC
        uint256[] memory proposalsToUpdate = _filterProposalsLessThanGBC(gbc, potentialProposalsSlate);

        // check current slate (slate will only contain proposals that have budget allocated to them prior)
        _grantFund.updateSlate(proposalsToUpdate, distributionId);

        // skip to end of challenge period
        vm.roll(block.number + 100_000);
        
        uint256 totalDelegationReward;

        // claim delegate reward for each voter
        for(uint i = 0; i < noOfVoters; i++) {
            // calculate delegate reward for each voter
            uint256 reward = Maths.wdiv(Maths.wmul(gbc, Maths.wpow(votes[i], 2)), totalBudgetAllocated) / 10;
            totalDelegationReward += reward; 

            // check whether reward calculated is correct
            _claimDelegateReward(
                {
                    grantFund_:        _grantFund,
                    voter_:            voters[i],
                    distributionId_:   distributionId,
                    claimedReward_:    reward
                }
            );
        }

        // ensure total delegation reward is less than equals to 10% of gbc
        assertGe(gbc / 10, totalDelegationReward);
    }

    // helper method that sort proposals based on votes on them
    function _insertionSortProposalsByVotes(uint256[] storage arr) internal {
        for (uint i = 1; i < arr.length; i++) {
            uint256 proposalId = arr[i];
            uint256 votesReceivedOnProposal = noOfVotesOnProposal[proposalId];
            uint j = i;

            while (j > 0 && votesReceivedOnProposal > noOfVotesOnProposal[arr[j-1]]) {
                // swap values if left item < right item
                uint256 temp = arr[j - 1];
                arr[j - 1] = arr[j];
                arr[j] = temp;

                j--;
            }
        }
    }

    // get an array of proposalIds that have tokens requested less than the GBC
    function _filterProposalsLessThanGBC(uint256 gbc_, uint256[] memory potentialProposalsSlate_) internal view returns (uint256[] memory filteredProposals_) {
        filteredProposals_ = new uint256[](potentialProposalsSlate_.length);
        uint256 filteredProposalsLength = 0;
        uint256 totalTokensRequested = 0;
        for (uint i = 0; i < potentialProposalsSlate_.length; ++i) {
            (, , , uint128 tokensRequested, ,) = _grantFund.getProposalInfo(potentialProposalsSlate_[i]);
            if (totalTokensRequested + tokensRequested > gbc_ * 9 / 10) {
                break;
            }
            else {
                filteredProposals_[i] = potentialProposalsSlate_[i];
                totalTokensRequested += tokensRequested;
                filteredProposalsLength += 1;
            }
        }

        assembly { mstore(filteredProposals_, filteredProposalsLength) }
    }

}




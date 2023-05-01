// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { GrantFund }           from "../../src/grants/GrantFund.sol";
import { IFunding }            from "../../src/grants/interfaces/IFunding.sol";
import { IStandardFunding }    from "../../src/grants/interfaces/IStandardFunding.sol";

import { GrantFundTestHelper } from "../utils/GrantFundTestHelper.sol";
import { IAjnaToken }          from "../utils/IAjnaToken.sol";
import { Maths }               from "../../src/grants/libraries/Maths.sol";

contract GrantFundTest is GrantFundTestHelper {

    IAjnaToken        internal  _token;
    GrantFund         internal  _grantFund;

    // at this block on mainnet, all ajna tokens belongs to _tokenDeployer
    uint256 internal _startBlock = 16354861;

    // Ajna token Holder at the Ajna contract creation on mainnet
    address internal _tokenDeployer  = 0x666cf594fB18622e1ddB91468309a7E194ccb799;
    address internal _tokenHolder1   = makeAddr("_tokenHolder1");
    address internal _tokenHolder2   = makeAddr("_tokenHolder2");
    address internal _tokenHolder3   = makeAddr("_tokenHolder3");

    address[] internal _votersArr = [
        _tokenHolder1,
        _tokenHolder2,
        _tokenHolder3
    ];

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), _startBlock);

        vm.startPrank(_tokenDeployer);

        // Ajna Token contract address on mainnet
        _token = IAjnaToken(0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079);

        // deploy growth fund contract
        _grantFund = new GrantFund();

        // initial minter distributes tokens to test addresses
        _transferAjnaTokens(_token, _votersArr, 50_000_000 * 1e18, _tokenDeployer);
    }

    function testFundTreasury() external {
        // should be able to add additional funds to the treasury
        changePrank(_tokenHolder1);
        _token.approve(address(_grantFund), 50_000_000 * 1e18);
        vm.expectEmit(true, true, false, true);
        emit FundTreasury(50_000_000 * 1e18, 50_000_000 * 1e18);
        _grantFund.fundTreasury(50_000_000 * 1e18);
    }

    function testTreasuryInsufficientBalanceExtraordinary() external {
        // tiny amount of ajna tokens are added to the treasury
        changePrank(_tokenHolder1);
        _token.approve(address(_grantFund), 1);
        vm.expectEmit(true, true, false, true);
        emit FundTreasury(1, 1);
        _grantFund.fundTreasury(1);

        // voter self delegates
        _token.delegate(_tokenHolder1);

        vm.roll(_startBlock + 100);

        // generate proposal targets
        address[] memory targets = new address[](1);
        targets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder1,
            50_000_000 * 1e18
        );

        // should revert when extraordinary funding proposal created for an amount greater than that in the treasury
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeExtraordinary(block.number + 100_000, targets, values, calldatas, "Extraordinary Proposal for Ajna token transfer to tester address");
    }

    function testTreasuryDistributionPeriodFunding() external {
        // fund treasury before and after starting the distribution period
        changePrank(_tokenDeployer);
        _token.approve(address(_grantFund), 100_000_000 * 1e18);
        _grantFund.fundTreasury(50_000_000 * 1e18);

        // start distribution period
        uint24 distributionId = _startDistributionPeriod(_grantFund);

        // calculate expected funds available
        uint256 expectedFundsAvailable = Maths.wmul(50_000_000 * 1e18, 0.03 * 1e18);

        // get distribution period info and check funds available doesn't update for the distribution period
        (, , , uint128 fundsAvailable, , ) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(fundsAvailable, expectedFundsAvailable);

        // fund treasury after distribution period started
        _grantFund.fundTreasury(50_000_000 * 1e18);

        // get distribution period info and check funds available doesn't update for the distribution period
        (, , , fundsAvailable, , ) = _grantFund.getDistributionPeriodInfo(distributionId);
        assertEq(fundsAvailable, expectedFundsAvailable);
    }

    function testTreasuryInsufficientBalanceStandard() external {
        // voter self delegates
        _token.delegate(_tokenHolder1);

        vm.roll(_startBlock + 100);

        // start distribution period
        _startDistributionPeriod(_grantFund);

        // fund treasury after distribution period started
        changePrank(_tokenDeployer);
        _token.approve(address(_grantFund), 50_000_000 * 1e18);
        _grantFund.fundTreasury(50_000_000 * 1e18);

        // generate proposal targets
        address[] memory targets = new address[](1);
        targets[0] = address(_token);

        // generate proposal values
        uint256[] memory values = new uint256[](1);
        // Eth to transfer is non zero
        values[0] = 0;

        // generate proposal calldata
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _tokenHolder2,
            1 * 1e18
        );

        // generate proposal message 
        string memory description = "Proposal for Ajna token transfer to tester address";

        // should revert when standard funding proposal created for an amount greater than that in the treasury
        vm.expectRevert(IFunding.InvalidProposal.selector);
        _grantFund.proposeStandard(targets, values, calldatas, description);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { Test } from "@std/Test.sol";

import { AjnaToken } from "../../src/token/AjnaToken.sol";

import { SigUtils } from "../utils/SigUtils.sol";

contract AjnaTokenTest is Test {

    AjnaToken internal _token;
    SigUtils  internal _sigUtils;

    address internal _tokenDeployer = makeAddr("tokenDeployer");
    address internal _tokenHolder   = makeAddr("_tokenHolder");
    uint256 _initialAjnaTokenSupply   = 2_000_000_000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function setUp() external {
        vm.startPrank(_tokenDeployer);
        _token = new AjnaToken(_tokenHolder);

        _sigUtils = new SigUtils(_token.DOMAIN_SEPARATOR());
        changePrank(_tokenHolder);
    }

    function testCannotSendTokensToContract() external {
        vm.expectRevert("Cannot transfer tokens to the contract itself");
        _token.transfer(address(_token), 1);
    }

    function testTransferTokensToZeroAddress() external {
        vm.expectRevert("ERC20: transfer to the zero address");
        _token.transfer(address(0), 1);
    }

    function testBaseInvariantMetadata() external {
        assertEq(_token.name(),     "AjnaToken");
        assertEq(_token.symbol(),   "AJNA");
        assertEq(_token.decimals(), 18);
    }

    function testTokenTotalSupply() external {
        assertEq(_token.totalSupply(), _initialAjnaTokenSupply);
    }

    function testHolderTokenBalance() external {
        assertEq(_token.balanceOf(_tokenHolder), _initialAjnaTokenSupply);
    }

    /**********************/
    /*** Burnable tests ***/
    /**********************/

    function testBurn() external {
        assertEq(_token.totalSupply(), _initialAjnaTokenSupply);
        _token.burn(50_000_000 * 1e18);
        assertEq(_token.totalSupply(), 1_950_000_000 * 1e18);
    }

    function testTransferWithApprove(uint256 amount_) external {
        vm.assume(amount_ > 0);
        vm.assume(amount_ <= _initialAjnaTokenSupply);
        _token.approve(_tokenHolder, amount_);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_tokenHolder, address(5555), amount_);
        _token.transferFrom(_tokenHolder, address(5555), amount_);

        assertEq(_token.balanceOf(_tokenHolder), _initialAjnaTokenSupply - amount_);
        assertEq(_token.balanceOf(address(5555)),  amount_);
    }

    /*********************/
    /*** Permit tests ***/
    /*********************/

    function testTransferWithPermit(uint256 amount_) external {
        vm.assume(amount_ > 0);
        vm.assume(amount_ <= _initialAjnaTokenSupply);

        // define owner and spender addresses
        (address owner, uint256 ownerPrivateKey) = makeAddrAndKey("owner");
        address spender                          = makeAddr("spender");
        address newOwner                         = makeAddr("newOwner");

        // set owner balance
        deal(address(_token), owner, amount_);

        // check owner and spender balances
        assertEq(_token.balanceOf(owner),    amount_);
        assertEq(_token.balanceOf(spender),  0);
        assertEq(_token.balanceOf(newOwner), 0);

        // TEST transfer with ERC20 permit
        changePrank(owner);
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: amount_,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = _sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        _token.permit(owner, spender, amount_, permit.deadline, v, r, s);

        changePrank(spender);
        _token.transferFrom(owner, newOwner, amount_);

        // check owner and spender balances after transfer
        assertEq(_token.balanceOf(owner),    0);
        assertEq(_token.balanceOf(spender),  0);
        assertEq(_token.balanceOf(newOwner), amount_);
        assertEq(_token.allowance(owner, spender), 0);

        // TEST transfer from with permit
        // set owner balance
        deal(address(_token), owner, amount_);

        permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: amount_,
            nonce: 1,
            deadline: 1 days
        });

        digest = _sigUtils.getTypedDataHash(permit);
        (v, r, s) = vm.sign(ownerPrivateKey, digest);

        _token.transferFromWithPermit(owner, newOwner, spender, amount_, permit.deadline, v, r, s);
        // check owner and spender balances after 2nd transfer with permit
        assertEq(_token.balanceOf(owner),    0);
        assertEq(_token.balanceOf(spender),  0);
        assertEq(_token.balanceOf(newOwner), amount_ * 2);
        assertEq(_token.allowance(owner, spender), 0);

        // CHECK FOR UNDERFLOW: owner can no longer spend tokens if their balance is 0
        permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1,
            nonce: 2,
            deadline: 1 days
        });

        digest = _sigUtils.getTypedDataHash(permit);
        (v, r, s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        _token.transferFromWithPermit(owner, newOwner, spender, 1, permit.deadline, v, r, s);
    }

    /*********************/
    /*** Voting tests ***/
    /*********************/

    function testDelegateVotes() external {
        address delegator = address(2222);
        address delegate1 = address(3333);
        address delegate2 = address(4444);

        // set delegator balance to 1_000 AJNA tokens
        deal(address(_token), delegator, 1_000 * 1e18);

        // check voting power
        assertEq(_token.getVotes(delegator), 0);
        assertEq(_token.getVotes(delegate1), 0);
        assertEq(_token.getVotes(delegate2), 0);

        vm.roll(11111);
        changePrank(delegator);
        vm.expectEmit(true, true, false, true);
        emit DelegateChanged(delegator, address(0), delegate1);
        vm.expectEmit(true, true, false, true);
        emit DelegateVotesChanged(delegate1, 0, 1_000 * 1e18);
        _token.delegate(delegate1);

        // check accounts balances
        assertEq(_token.balanceOf(delegator), 1_000 * 1e18);
        assertEq(_token.balanceOf(delegate1), 0);
        assertEq(_token.balanceOf(delegate2), 0);
        // check voting power
        assertEq(_token.getVotes(delegator), 0);
        assertEq(_token.getVotes(delegate1), 1_000 * 1e18);
        assertEq(_token.getVotes(delegate2), 0);

        assertEq(_token.delegates(delegator), delegate1);

        vm.roll(11112);

        changePrank(delegator);
        vm.expectEmit(true, true, false, true);
        emit DelegateChanged(delegator, delegate1, delegate2);
        vm.expectEmit(true, true, false, true);
        emit DelegateVotesChanged(delegate1, 1_000 * 1e18, 0);
        vm.expectEmit(true, true, false, true);
        emit DelegateVotesChanged(delegate2, 0, 1_000 * 1e18);
        _token.delegate(delegate2);
        vm.roll(11113);

        // check accounts balances
        assertEq(_token.balanceOf(delegator), 1_000 * 1e18);
        assertEq(_token.balanceOf(delegate1), 0);
        assertEq(_token.balanceOf(delegate2), 0);
        // check voting power
        assertEq(_token.getVotes(delegator), 0);
        assertEq(_token.getVotes(delegate1), 0);
        assertEq(_token.getVotes(delegate2), 1_000 * 1e18);

        assertEq(_token.delegates(delegator), delegate2);
        // check voting power at block 11111 and 11112
        assertEq(_token.getPastVotes(delegate1, 11111), 1_000 * 1e18);
        assertEq(_token.getPastVotes(delegate2, 11111), 0);
        assertEq(_token.getPastVotes(delegate1, 11112), 0);
        assertEq(_token.getPastVotes(delegate2, 11112), 1_000 * 1e18);
    }

    function testCalculateVotingPower() external {
        address delegator1 = address(1111);
        address delegator2 = address(2222);
        address delegate1  = address(3333);
        address delegate2  = address(4444);

        // set delegators and delegates AJNA balances
        deal(address(_token), delegator1, 1_000 * 1e18);
        deal(address(_token), delegator2, 2_000 * 1e18);
        deal(address(_token), delegate1,  3_000 * 1e18);
        deal(address(_token), delegate2,  4_000 * 1e18);

        // initial voting power is 0
        assertEq(_token.getVotes(delegator1), 0);
        assertEq(_token.getVotes(delegator2), 0);
        assertEq(_token.getVotes(delegate1),  0);
        assertEq(_token.getVotes(delegate2),  0);

        // delegates delegate to themselves
        changePrank(delegate1);
        _token.delegate(delegate1);
        changePrank(delegate2);
        _token.delegate(delegate2);

        // check votes
        assertEq(_token.getVotes(delegator1), 0);
        assertEq(_token.getVotes(delegator2), 0);
        assertEq(_token.getVotes(delegate1),  3_000 * 1e18);
        assertEq(_token.getVotes(delegate2),  4_000 * 1e18);

        // delegators delegate to delegates
        changePrank(delegator1);
        _token.delegate(delegate1);
        changePrank(delegator2);
        _token.delegate(delegate2);

        // check votes
        assertEq(_token.getVotes(delegator1), 0);
        assertEq(_token.getVotes(delegator2), 0);
        assertEq(_token.getVotes(delegate1),  4_000 * 1e18);
        assertEq(_token.getVotes(delegate2),  6_000 * 1e18);

        assertEq(_token.delegates(delegator1), delegate1);
        assertEq(_token.delegates(delegator2), delegate2);
        assertEq(_token.delegates(delegate1),  delegate1);
        assertEq(_token.delegates(delegate2),  delegate2);
    }

    function testNestedDelegation() external {
        assertEq(_token.getVotes(_tokenHolder),  0);
        assertEq(_token.getVotes(address(3333)), 0);
        assertEq(_token.getVotes(address(4444)), 0);

        // tokens owner delegates votes to 3333
        vm.roll(11112);
        _token.delegate(address(3333));

        assertEq(_token.getVotes(_tokenHolder),  0);
        assertEq(_token.getVotes(address(3333)), 2_000_000_000 * 1e18);
        assertEq(_token.getVotes(address(4444)), 0);

        // 3333 cannot delegate votes to 4444
        vm.roll(11112);
        changePrank(address(3333));
        _token.delegate(address(4444));

        assertEq(_token.getVotes(_tokenHolder),  0);
        assertEq(_token.getVotes(address(3333)), 2_000_000_000 * 1e18);
        assertEq(_token.getVotes(address(4444)), 0);

        // tokens owner delegates votes to 4444
        changePrank(_tokenHolder);
        _token.delegate(address(4444));

        assertEq(_token.getVotes(_tokenHolder),  0);
        assertEq(_token.getVotes(address(3333)), 0);
        assertEq(_token.getVotes(address(4444)), 2_000_000_000 * 1e18);
    }
}

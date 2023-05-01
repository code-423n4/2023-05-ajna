// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { Address }         from "@oz/utils/Address.sol";
import { IVotes }          from "@oz/governance/utils/IVotes.sol";
import { ReentrancyGuard } from "@oz/security/ReentrancyGuard.sol";
import { SafeCast }        from "@oz/utils/math/SafeCast.sol";

import { Maths } from "../libraries/Maths.sol";

import { IFunding } from "../interfaces/IFunding.sol";

abstract contract Funding is IFunding, ReentrancyGuard {

    /******************/
    /*** Immutables ***/
    /******************/

    // address of the ajna token used in grant coordination
    address public immutable ajnaTokenAddress = 0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079;

    /*****************/
    /*** Constants ***/
    /*****************/

    /**
     * @notice Number of blocks prior to a given voting stage to check an accounts voting power.
     * @dev    Prevents flashloan attacks or duplicate voting with multiple accounts.
     */
    uint256 internal constant VOTING_POWER_SNAPSHOT_DELAY = 33;

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     * @notice Total funds available for Funding Mechanism
    */
    uint256 public treasury;

    /**************************/
    /*** Internal Functions ***/
    /**************************/

     /**
     * @notice Execute the calldata of a passed proposal.
     * @param targets_   The list of smart contract targets for the calldata execution. Should be the Ajna token address.
     * @param values_    Unused. Should be 0 since all calldata is executed on the Ajna token's transfer method.
     * @param calldatas_ The list of calldatas to execute.
     */
    function _execute(
        uint256 proposalId_,
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_
    ) internal {
        // use common event name to maintain consistency with tally
        emit ProposalExecuted(proposalId_);

        string memory errorMessage = "Governor: call reverted without message";
        for (uint256 i = 0; i < targets_.length; ++i) {
            (bool success, bytes memory returndata) = targets_[i].call{value: values_[i]}(calldatas_[i]);
            Address.verifyCallResult(success, returndata, errorMessage);
        }
    }

     /**
     * @notice Retrieve the voting power of an account.
     * @dev    Voting power is the minimum of the amount of votes available at a snapshot block 33 blocks prior to voting start, and at the vote starting block.
     * @param account_        The voting account.
     * @param snapshot_       One of the block numbers to retrieve the voting power at. 33 blocks prior to the block at which a proposal is available for voting.
     * @param voteStartBlock_ The block number the proposal became available for voting.
     * @return                The voting power of the account.
     */
    function _getVotesAtSnapshotBlocks(
        address account_,
        uint256 snapshot_,
        uint256 voteStartBlock_
    ) internal view returns (uint256) {
        IVotes token = IVotes(ajnaTokenAddress);

        // calculate the number of votes available at the snapshot block
        uint256 votes1 = token.getPastVotes(account_, snapshot_);

        // enable voting weight to be calculated during the voting period's start block
        voteStartBlock_ = voteStartBlock_ != block.number ? voteStartBlock_ : block.number - 1;

        // calculate the number of votes available at the stage's start block
        uint256 votes2 = token.getPastVotes(account_, voteStartBlock_);

        return Maths.min(votes2, votes1);
    }

    /**
     * @notice Verifies proposal's targets, values, and calldatas match specifications.
     * @dev    Counters incremented in an unchecked block due to being bounded by array length.
     * @param targets_         The addresses of the contracts to call.
     * @param values_          The amounts of ETH to send to each target.
     * @param calldatas_       The calldata to send to each target.
     * @return tokensRequested_ The amount of tokens requested in the calldata.
     */
    function _validateCallDatas(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_
    ) internal view returns (uint128 tokensRequested_) {

        // check params have matching lengths
        if (targets_.length == 0 || targets_.length != values_.length || targets_.length != calldatas_.length) revert InvalidProposal();

        for (uint256 i = 0; i < targets_.length;) {

            // check targets and values params are valid
            if (targets_[i] != ajnaTokenAddress || values_[i] != 0) revert InvalidProposal();

            // check calldata function selector is transfer()
            bytes memory selDataWithSig = calldatas_[i];

            bytes4 selector;
            //slither-disable-next-line assembly
            assembly {
                selector := mload(add(selDataWithSig, 0x20))
            }
            if (selector != bytes4(0xa9059cbb)) revert InvalidProposal();

            // https://github.com/ethereum/solidity/issues/9439
            // retrieve tokensRequested from incoming calldata, accounting for selector and recipient address
            uint256 tokensRequested;
            bytes memory tokenDataWithSig = calldatas_[i];
            //slither-disable-next-line assembly
            assembly {
                tokensRequested := mload(add(tokenDataWithSig, 68))
            }

            // update tokens requested for additional calldata
            tokensRequested_ += SafeCast.toUint128(tokensRequested);

            unchecked { ++i; }
        }
    }

    /**
     * @notice Create a proposalId from a hash of proposal's targets, values, and calldatas arrays, and a description hash.
     * @dev    Consistent with proposalId generation methods used in OpenZeppelin Governor.
     * @param targets_         The addresses of the contracts to call.
     * @param values_          The amounts of ETH to send to each target.
     * @param calldatas_       The calldata to send to each target.
     * @param descriptionHash_ The hash of the proposal's description string. Generated by keccak256(bytes(description))).
     * @return proposalId_     The hashed proposalId created from the provided params.
     */
    function _hashProposal(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) internal pure returns (uint256 proposalId_) {
        proposalId_ = uint256(keccak256(abi.encode(targets_, values_, calldatas_, descriptionHash_)));
    }
}

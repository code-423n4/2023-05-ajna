// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IERC20 }    from "@oz/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@oz/token/ERC20/utils/SafeERC20.sol";

import { ExtraordinaryFunding } from "./base/ExtraordinaryFunding.sol";
import { StandardFunding }      from "./base/StandardFunding.sol";

import { IGrantFund } from "./interfaces/IGrantFund.sol";

contract GrantFund is IGrantFund, ExtraordinaryFunding, StandardFunding {

    using SafeERC20 for IERC20;

    /**************************/
    /*** Proposal Functions ***/
    /**************************/

    /// @inheritdoc IGrantFund
    function hashProposal(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) external pure override returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(targets_, values_, calldatas_, descriptionHash_);
    }

    /**
     * @notice Given a proposalId, find if it is a standard or extraordinary proposal.
     * @param proposalId_ The id of the proposal to query the mechanism of.
     * @return FundingMechanism to which the proposal was submitted.
     */
    function findMechanismOfProposal(
        uint256 proposalId_
    ) public view returns (FundingMechanism) {
        if (_standardFundingProposals[proposalId_].proposalId != 0)           return FundingMechanism.Standard;
        else if (_extraordinaryFundingProposals[proposalId_].proposalId != 0) return FundingMechanism.Extraordinary;
        else revert ProposalNotFound();
    }

    /// @inheritdoc IGrantFund
    function state(
        uint256 proposalId_
    ) external view override returns (ProposalState) {
        FundingMechanism mechanism = findMechanismOfProposal(proposalId_);

        return mechanism == FundingMechanism.Standard ? _standardProposalState(proposalId_) : _getExtraordinaryProposalState(proposalId_);
    }

    /**************************/
    /*** Treasury Functions ***/
    /**************************/

    /// @inheritdoc IGrantFund
    function fundTreasury(uint256 fundingAmount_) external override {
        IERC20 token = IERC20(ajnaTokenAddress);

        // update treasury accounting
        treasury += fundingAmount_;

        emit FundTreasury(fundingAmount_, treasury);

        // transfer ajna tokens to the treasury
        token.safeTransferFrom(msg.sender, address(this), fundingAmount_);
    }

}

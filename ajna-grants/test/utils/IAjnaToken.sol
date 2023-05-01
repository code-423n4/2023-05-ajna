// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IVotes }    from "@oz/governance/utils/IVotes.sol";
import { IERC20 }      from "@oz/token/ERC20/IERC20.sol";

interface IAjnaToken is IERC20, IVotes {}
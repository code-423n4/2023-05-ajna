// SPDX-License-Identifier: MIT

//slither-disable-next-line solc-version
pragma solidity 0.8.7;


import { ERC20 }          from "@oz/token/ERC20/ERC20.sol";
import { IERC20 }         from "@oz/token/ERC20/IERC20.sol";
import { ERC20Burnable }  from "@oz/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit }    from "@oz/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC20Wrapper }   from "@oz/token/ERC20/extensions/ERC20Wrapper.sol";
import { IERC20Metadata } from "@oz/token/ERC20/extensions/IERC20Metadata.sol";

contract BurnWrappedAjna is ERC20, ERC20Burnable, ERC20Permit, ERC20Wrapper {

    /**
     * @notice Ethereum mainnet address of the Ajna Token.
     */
    address internal constant AJNA_TOKEN_ADDRESS = 0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079;

    /**
     * @notice Tokens that have been wrapped cannot be unwrapped.
     */
    error UnwrapNotAllowed();

    /**
     * @notice Only mainnet Ajna token can be wrapped.
     */
    error InvalidWrappedToken();

    constructor(IERC20 wrappedToken)
        ERC20("Burn Wrapped AJNA", "bwAJNA")
        ERC20Permit("Burn Wrapped AJNA") // enables wrapped token to also use permit functionality
        ERC20Wrapper(wrappedToken)
    {
        if (address(wrappedToken) != AJNA_TOKEN_ADDRESS) {
            revert InvalidWrappedToken();
        }
    }

    /*****************/
    /*** OVERRIDES ***/
    /*****************/

    /**
     * @dev See {ERC20-decimals} and {ERC20Wrapper-decimals}.
     */
    function decimals() public pure override(ERC20, ERC20Wrapper) returns (uint8) {
        // since the Ajna Token has 18 decimals, we can just return 18 here.
        return 18;
    }

    /**
     * @notice Override unwrap method to ensure burn wrapped tokens can't be unwrapped.
     */
    function withdrawTo(address, uint256) public pure override returns (bool) {
        revert UnwrapNotAllowed();
    }

}

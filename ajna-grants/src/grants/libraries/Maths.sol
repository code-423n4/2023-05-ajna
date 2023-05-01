// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library Maths {

    uint256 public constant WAD = 10**18;

    function abs(int x) internal pure returns (int) {
        return x >= 0 ? x : -x;
    }

    /**
     * @notice Returns the square root of a WAD, as a WAD.
     * @dev Utilizes the babylonian method: https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
     * @param y The WAD to take the square root of.
     * @return z The square root of the WAD, as a WAD.
     */
    function wsqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // convert z to a WAD
        z = z * 10**9;
    }

    function wmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + 10**18 / 2) / 10**18;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * 10**18 + y / 2) / y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    /** @notice Raises a WAD to the power of an integer and returns a WAD */
    function wpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : 10**18;

        for (n /= 2; n != 0; n /= 2) {
            x = wmul(x, x);

            if (n % 2 != 0) {
                z = wmul(z, x);
            }
        }
    }

}

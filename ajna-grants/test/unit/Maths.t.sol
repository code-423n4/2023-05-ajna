// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import { Test } from "@std/Test.sol";

import { Maths } from '../../src/grants/libraries/Maths.sol';

contract MathsTest is Test {

    function testAbs() external {
        assertEq(Maths.abs(0), 0);
        assertEq(Maths.abs(1), 1);
        assertEq(Maths.abs(-1), 1);        
        assertEq(Maths.abs(1e18), 1e18);
        assertEq(Maths.abs(-1e18), 1e18);
        assertEq(Maths.abs(-.005 * 1e18), .005 * 1e18);
    }

    function testDivision() external {
        uint256 numerator   = 11_000.143012091382543917 * 1e18;
        uint256 denominator = 1_001.6501589292607751220 * 1e18;
        assertEq(Maths.wdiv(numerator, denominator), 10.98202093218880245 * 1e18);

        assertEq(Maths.wdiv(1 * 1e18, 60 * 1e18), 0.016666666666666667 * 1e18);
        assertEq(Maths.wdiv(0, 60 * 1e18),        0);
    }

    function testMin() external {
        uint256 smallerWad = 0.002144924036174740 * 1e18;
        uint256 largerWad  = 0.951347940696070000 * 1e18;

        assertEq(Maths.min(2, 4), 2);
        assertEq(Maths.min(0, 9), 0);
        assertEq(Maths.min(smallerWad, largerWad), smallerWad);
    }

    function testMultiplication() external {
        uint256 num1 = 10_000.44444444444443999 * 1e18;
        uint256 num2 = 1.02132007 * 1e18;
        assertEq(Maths.wmul(num1, num2), 10_213.654620031111106562 * 1e18);

        assertEq(Maths.wmul(1 * 1e18, 60 * 1e18), 60 * 1e18);
        assertEq(Maths.wmul(1 * 1e18, 0.5 * 1e18), 0.5 * 1e18);
        assertEq(Maths.wmul(1 * 1e18, 0), 0);
    }

    function testPow() external {
        assertEq(Maths.wpow(3 * 1e18, 3), 27 * 1e18);
        assertEq(Maths.wpow(1_000 * 1e18, 2), 1_000_000 * 1e18);
        assertEq(Maths.wpow(0.5 * 1e18, 20), 0.000000953674316406 * 1e18);
        assertEq(Maths.wpow(0.2 * 1e18, 17), 0.000000000001310720 * 1e18);
    }

    function testSqrt() external {
        assertEq(Maths.wsqrt(100 * 1e18), 10 * 1e18);
        assertEq(Maths.wsqrt(25 * 1e18), 5 * 1e18);
        assertEq(Maths.wsqrt(11_000.143012091382543917 * 1e18), 104.881566598000000000 * 1e18);

        assertEq(Maths.wsqrt(2 * 1e18), 1.414213562000000000 * 1e18);
        assertEq(Maths.wsqrt(2), 1 * 1e9);
    }

}

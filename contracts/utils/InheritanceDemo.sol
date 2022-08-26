// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "hardhat/console.sol";

contract A {
    function foo () public virtual {
        console.log("A");
    }
}

contract B is A {
    function foo () public virtual override {
        console.log("B");
    }
}

contract C is A {
    function foo () public virtual override {
        console.log("C");
        super.foo();
    }
}

// What I want ideally:
// X: inherits from B, foo prints B
// Y: inherits from C, foo prints CA
// Z: inherits from both, foo prints CB
// In the case where it inherits from both, I need C to call B when it calls super
// Solution 1 is pretty close, except Z1 has to define foo(), even to just call super.foo().
// Solution 2: copy C to a new contract Cprime is B. Then Z2 is Cprime.
// Both are a bit ugly, but the Cprime solution puts less work on the downstream developer.

contract X is B {} // foo() prints B

contract Y is C {} // foo() prints CA

// Solution 1:
contract Z1 is B, C { // want foo() to print CB
    function foo () public override (B, C) {
        super.foo();
    }
}

// Solution 2:
contract Cprime is B {
        function foo () public virtual override {
        console.log("C");
        super.foo();
    }
}

contract Z2 is Cprime {}
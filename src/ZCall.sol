// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./ZCallExecution.sol";
import "./ZCallRuntime.sol";

/// @notice ZCall (zipped contracts) v1.0.0
/// @author merklejerk (https://github.com/merklejerk)
contract ZCall is ZCallExecution, ZCallRuntime {}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./targets/TaikoL2WithoutBaseFeeCheck.sol";
import "./Layer2Test.sol";


contract TaikoL2Tests is Layer2Test {
    using SafeCast for uint256;

    uint32 private constant BLOCK_GAS_LIMIT = 30_000_000;
    uint64 private anchorBlockId;

    // Contracts on Taiko
    SignalService signalService;
    TaikoL2 public taikoL2;

    function setUpOnTaiko() internal override {
        signalService = deploySignalService(address(new SignalService()));
        taikoL2 = deployTaikoL2(address(new TaikoL2WithoutBaseFeeCheck()), ethereumChainId);
            signalService.authorize(address(taikoL2), true);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
        vm.deal(address(taikoL2), 100 ether);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external onTaiko {
        vm.fee(1);

        vm.prank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        _anchorV2(BLOCK_GAS_LIMIT);

        vm.prank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(TaikoL2.L2_PUBLIC_INPUT_HASH_MISMATCH.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external onTaiko {
        vm.fee(1);
        vm.expectRevert(TaikoL2.L2_INVALID_SENDER.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    function test_L2_AnchorTx_signing(bytes32 digest) external onTaiko {
        (uint8 v, uint256 r, uint256 s) = LibL2Signer.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, taikoL2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = LibL2Signer.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, taikoL2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert(LibL2Signer.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibL2Signer.signAnchor(digest, uint8(0));

        vm.expectRevert(LibL2Signer.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibL2Signer.signAnchor(digest, uint8(3));
    }

    function test_L2_withdraw() external onTaiko {
        vm.prank(taikoL2.owner());
        taikoL2.withdraw(address(0), Alice);
        assertEq(address(taikoL2).balance, 0 ether);
        assertEq(Alice.balance, 100 ether);

        // Random EOA cannot call withdraw
        vm.expectRevert(EssentialContract.RESOLVER_DENIED.selector);
        vm.prank(Alice);
        taikoL2.withdraw(address(0), Alice);
    }

    function test_L2_getBlockHash() external onTaiko {
        assertEq(taikoL2.getBlockHash(uint64(1000)), 0);
    }

    function _anchorV2(uint32 parentGasUsed) private {
        bytes32 anchorStateRoot = randBytes32();
        LibSharedData.BaseFeeConfig memory baseFeeConfig = LibSharedData.BaseFeeConfig({
            adjustmentQuotient: 8,
            sharingPctg: 75,
            gasIssuancePerSecond: 5_000_000,
            minGasExcess: 1_340_000_000,
            maxGasIssuancePerBlock: 600_000_000 // two minutes
         });
        taikoL2.anchorV2(++anchorBlockId, anchorStateRoot, parentGasUsed, baseFeeConfig);
    }
}

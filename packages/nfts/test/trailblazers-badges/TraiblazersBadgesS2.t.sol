// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { TrailblazersBadgesS2 } from "../../contracts/trailblazers-badges/TrailblazersBadgesS2.sol";

contract TrailblazersBadgesTest is Test {
    UtilsScript public utils;

    TrailblazersBadges public s1Badges;
    TrailblazersBadgesS2 public s2Badges;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    uint256 public BADGE_ID;

    MockBlacklist public blacklist;

    address mintSigner;
    uint256 mintSignerPk;

    bool constant PINK_TAMPER = true;
    bool constant PURPLE_TAMPER = false;

    uint256 public MAX_TAMPERS;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startBroadcast(owner);

        (mintSigner, mintSignerPk) = makeAddrAndKey("mintSigner");

        // deploy token with empty root
        address impl = address(new TrailblazersBadges());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TrailblazersBadges.initialize, (owner, "ipfs://", mintSigner, blacklist)
                )
            )
        );

        s1Badges = TrailblazersBadges(proxy);

        BADGE_ID = s1Badges.BADGE_RAVERS();

        // deploy the s2 contract

        impl = address(new TrailblazersBadgesS2());
        proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(TrailblazersBadgesS2.initialize, (address(s1Badges)))
            )
        );

        s2Badges = TrailblazersBadgesS2(proxy);
        MAX_TAMPERS = s2Badges.MAX_TAMPERS();

        s1Badges.setSeason2BadgeContract(address(s2Badges));
        vm.stopBroadcast();
    }

    function test_s1_metadata_badges() public view {
        assertEq(s1Badges.BADGE_RAVERS(), 0);
        assertEq(s1Badges.BADGE_ROBOTS(), 1);
        assertEq(s1Badges.BADGE_BOUNCERS(), 2);
        assertEq(s1Badges.BADGE_MASTERS(), 3);
        assertEq(s1Badges.BADGE_MONKS(), 4);
        assertEq(s1Badges.BADGE_DRUMMERS(), 5);
        assertEq(s1Badges.BADGE_ANDROIDS(), 6);
        assertEq(s1Badges.BADGE_SHINTO(), 7);
    }

    function test_s2_metadata_badges() public view {
        assertEq(s2Badges.RAVER_PINK_ID(), 0);
        assertEq(s2Badges.RAVER_PURPLE_ID(), 1);
        assertEq(s2Badges.ROBOT_PINK_ID(), 2);
        assertEq(s2Badges.ROBOT_PURPLE_ID(), 3);
        assertEq(s2Badges.BOUNCER_PINK_ID(), 4);
        assertEq(s2Badges.BOUNCER_PURPLE_ID(), 5);
        assertEq(s2Badges.MASTER_PINK_ID(), 6);
        assertEq(s2Badges.MASTER_PURPLE_ID(), 7);
        assertEq(s2Badges.MONK_PINK_ID(), 8);
        assertEq(s2Badges.MONK_PURPLE_ID(), 9);
        assertEq(s2Badges.DRUMMER_PINK_ID(), 10);
        assertEq(s2Badges.DRUMMER_PURPLE_ID(), 11);
        assertEq(s2Badges.ANDROID_PINK_ID(), 12);
        assertEq(s2Badges.ANDROID_PURPLE_ID(), 13);
        assertEq(s2Badges.SHINTO_PINK_ID(), 14);
        assertEq(s2Badges.SHINTO_PURPLE_ID(), 15);
    }

    function test_s1_s2_badgeId_conversion() public view {
        (uint256 pinkId, uint256 purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_RAVERS());
        assertEq(pinkId, s2Badges.RAVER_PINK_ID());
        assertEq(purpleId, s2Badges.RAVER_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_ROBOTS());
        assertEq(pinkId, s2Badges.ROBOT_PINK_ID());
        assertEq(purpleId, s2Badges.ROBOT_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_BOUNCERS());
        assertEq(pinkId, s2Badges.BOUNCER_PINK_ID());
        assertEq(purpleId, s2Badges.BOUNCER_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_MASTERS());
        assertEq(pinkId, s2Badges.MASTER_PINK_ID());
        assertEq(purpleId, s2Badges.MASTER_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_MONKS());
        assertEq(pinkId, s2Badges.MONK_PINK_ID());
        assertEq(purpleId, s2Badges.MONK_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_DRUMMERS());
        assertEq(pinkId, s2Badges.DRUMMER_PINK_ID());
        assertEq(purpleId, s2Badges.DRUMMER_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_ANDROIDS());
        assertEq(pinkId, s2Badges.ANDROID_PINK_ID());
        assertEq(purpleId, s2Badges.ANDROID_PURPLE_ID());

        (pinkId, purpleId) = s2Badges.getSeason2BadgeIds(s1Badges.BADGE_SHINTO());
        assertEq(pinkId, s2Badges.SHINTO_PINK_ID());
        assertEq(purpleId, s2Badges.SHINTO_PURPLE_ID());
    }

    function test_s2_s1_badgeId_conversion() public view {
        uint256 s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.RAVER_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_RAVERS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.RAVER_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_RAVERS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.ROBOT_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_ROBOTS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.ROBOT_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_ROBOTS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.BOUNCER_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_BOUNCERS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.BOUNCER_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_BOUNCERS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.MASTER_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_MASTERS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.MASTER_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_MASTERS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.MONK_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_MONKS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.MONK_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_MONKS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.DRUMMER_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_DRUMMERS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.DRUMMER_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_DRUMMERS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.ANDROID_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_ANDROIDS());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.ANDROID_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_ANDROIDS());

        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.SHINTO_PINK_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_SHINTO());
        s1BadgeId = s2Badges.getSeason1BadgeId(s2Badges.SHINTO_PURPLE_ID());
        assertEq(s1BadgeId, s1Badges.BADGE_SHINTO());
    }

    function mint_s1(address minter, uint256 badgeId) public {
        bytes32 _hash = s1Badges.getHash(minter, badgeId);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = s1Badges.canMint(abi.encodePacked(r, s, v), minter, badgeId);
        assertTrue(canMint);

        vm.startPrank(minter);
        s1Badges.mint(abi.encodePacked(r, s, v), badgeId);
        vm.stopPrank();
    }

    function test_mint_s1() public {
        mint_s1(minters[0], s1Badges.BADGE_RAVERS());
        mint_s1(minters[0], s1Badges.BADGE_ROBOTS());
        assertEq(s1Badges.balanceOf(minters[0]), 2);

        mint_s1(minters[1], s1Badges.BADGE_BOUNCERS());
        mint_s1(minters[1], s1Badges.BADGE_MASTERS());
        assertEq(s1Badges.balanceOf(minters[1]), 2);

        mint_s1(minters[2], s1Badges.BADGE_MONKS());
        mint_s1(minters[2], s1Badges.BADGE_DRUMMERS());
        assertEq(s1Badges.balanceOf(minters[2]), 2);
    }

    function test_startMigration() public {
        mint_s1(minters[0], BADGE_ID);

        uint256 tokenId = s1Badges.tokenOfOwnerByIndex(minters[0], 0);

        vm.startPrank(minters[0]);
        s1Badges.approve(address(s2Badges), tokenId);
        s2Badges.startMigration(BADGE_ID);
        vm.stopPrank();

        assertEq(s1Badges.balanceOf(minters[0]), 0);
        assertEq(s1Badges.balanceOf(address(s2Badges)), 1);

        assertEq(s1Badges.ownerOf(tokenId), address(s2Badges));

        assertEq(s2Badges.isMigrationActive(minters[0]), true);
    }

    // happy-path, make 3 pink tampers, and 2 purple ones
    function test_tamperMigration() public {
        test_startMigration();

        vm.startPrank(minters[0]);

        for (uint256 i = 0; i < MAX_TAMPERS; i++) {
            s2Badges.tamperMigration(PINK_TAMPER);
        }

        s2Badges.tamperMigration(PURPLE_TAMPER);
        s2Badges.tamperMigration(PURPLE_TAMPER);
        vm.stopPrank();

        assertEq(s2Badges.isTamperActive(minters[0]), true);
        assertEq(s2Badges.isMigrationActive(minters[0]), true);

        (uint256 pinkTampers, uint256 purpleTampers) = s2Badges.getMigrationTampers(minters[0]);
        assertEq(pinkTampers, MAX_TAMPERS);
        assertEq(purpleTampers, 2);
    }

    // revert when attempting a 4th pink tamper
    function test_revert_tooManyTampers() public {
        test_tamperMigration();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        s2Badges.tamperMigration(PINK_TAMPER);

        vm.stopPrank();
    }

    function test_revert_early_endMigration() public {
        test_tamperMigration();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        s2Badges.endMigration();
        vm.stopPrank();
    }

    function test_endMigration() public {
        test_tamperMigration();
        // roll forward the block number 2 hours

        vm.warp(2 hours);
        vm.startPrank(minters[0]);
        s2Badges.endMigration();
        vm.stopPrank();

        // check for s1 burn
        assertEq(s1Badges.balanceOf(minters[0]), 0);
        assertEq(s1Badges.balanceOf(address(s2Badges)), 0);

        // check for s2 state reset
        assertEq(s2Badges.isMigrationActive(minters[0]), false);
        assertEq(s2Badges.isTamperActive(minters[0]), false);

        // check for s2 mint
        (uint256 pinkBadgeId, uint256 purpleBadgeId) = s2Badges.getSeason2BadgeIds(BADGE_ID);
        uint256 s2TokenId = s2Badges.getTokenId(minters[0], pinkBadgeId) > 0
            ? s2Badges.getTokenId(minters[0], pinkBadgeId)
            : s2Badges.getTokenId(minters[0], purpleBadgeId);
        assertEq(s2Badges.balanceOf(minters[0], s2TokenId), 1);

        // check for s2 badge balances
        bool[16] memory badgeBalances = s2Badges.badgeBalances(minters[0]);

        assertTrue(
            badgeBalances[s2Badges.RAVER_PINK_ID()] || badgeBalances[s2Badges.RAVER_PURPLE_ID()]
        );

        assertFalse(badgeBalances[s2Badges.ROBOT_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.ROBOT_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.BOUNCER_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.BOUNCER_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.MASTER_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.MASTER_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.MONK_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.MONK_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.DRUMMER_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.DRUMMER_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.ANDROID_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.ANDROID_PURPLE_ID()]);
        assertFalse(badgeBalances[s2Badges.SHINTO_PINK_ID()]);
        assertFalse(badgeBalances[s2Badges.SHINTO_PURPLE_ID()]);
    }

    function test_revert_startMigrationTwice() public {
        test_startMigration();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        s2Badges.startMigration(BADGE_ID);
        vm.stopPrank();
    }

    /*
    function test_simulateS1() public {
        vm.prank(minters[0]);
        s1Badges.mintBadge(minters[0], BADGE_ID, 0, "0x");
    }*/
}

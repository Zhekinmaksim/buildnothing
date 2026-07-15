// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/BuildNothing.sol";

contract BuildNothingTest is Test {
    BuildNothing bn;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address snitchA = makeAddr("snitchA");
    address snitchB = makeAddr("snitchB");
    address snitchC = makeAddr("snitchC");

    function setUp() public {
        bn = new BuildNothing();
        vm.deal(alice, 200 ether);
        vm.deal(bob, 200 ether);
        vm.deal(carol, 200 ether);
    }

    // ------------------------------------------------------------ helpers
    function _commit(address who, address snitch, uint256 duration, uint256 stake) internal returns (uint256 id) {
        vm.prank(who);
        id = bn.commit{value: stake}(duration, snitch);
    }

    function _beatDaily(uint256 vowId, address snitch, uint256 daysN) internal {
        for (uint256 i = 0; i < daysN; i++) {
            vm.warp(block.timestamp + 1 days);
            vm.prank(snitch);
            bn.heartbeat(vowId);
        }
    }

    // ------------------------------------------------------------ commit
    function test_commit_basics() public {
        uint256 id = _commit(alice, snitchA, 3 days, 5 ether);
        (address penitent,, uint64 start, uint64 end,,, uint128 stake,, BuildNothing.Status st,) = bn.vows(id);
        assertEq(penitent, alice);
        assertEq(stake, 5 ether);
        assertEq(end - start, 3 days);
        assertEq(uint8(st), uint8(BuildNothing.Status.Active));
        assertEq(bn.activeVowOf(alice), id);
    }

    function test_commit_reverts() public {
        vm.startPrank(alice);
        vm.expectRevert(BuildNothing.BadDuration.selector);
        bn.commit{value: 1 ether}(1 hours, snitchA);
        vm.expectRevert(BuildNothing.BadStake.selector);
        bn.commit{value: 101 ether}(3 days, snitchA);
        vm.expectRevert(BuildNothing.NotSnitch.selector);
        bn.commit{value: 1 ether}(3 days, alice); // self-snitch
        bn.commit{value: 1 ether}(3 days, snitchA);
        vm.expectRevert(BuildNothing.VowAlreadyActive.selector);
        bn.commit{value: 1 ether}(3 days, snitchA);
        vm.stopPrank();
    }

    // ------------------------------------------------------------ survive path
    function test_survive_and_claim_principal() public {
        uint256 id = _commit(alice, snitchA, 3 days, 5 ether);
        _beatDaily(id, snitchA, 3);

        vm.warp(block.timestamp + 1); // past end
        bn.resolve(id);
        (,,,,,,,, BuildNothing.Status st,) = bn.vows(id);
        assertEq(uint8(st), uint8(BuildNothing.Status.Survived));

        // finalize epoch after claim window
        (, uint32 epochId) = _vowEpoch(id);
        (uint64 eEnd,,,,,) = bn.epochs(epochId);
        vm.warp(uint256(eEnd) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochId);

        uint256 before = alice.balance;
        bn.claim(id);
        assertEq(alice.balance, before + 5 ether); // no slashes => principal only
    }

    // ------------------------------------------------------------ relapse path
    function test_relapse_slashes_to_survivors() public {
        uint256 a = _commit(alice, snitchA, 5 days, 10 ether);
        uint256 b = _commit(bob, snitchB, 5 days, 10 ether);

        // both beat for 2 days, then bob opens Claude Code
        _beatDaily(a, snitchA, 2);
        vm.prank(snitchB);
        bn.heartbeat(b);
        vm.prank(snitchB);
        bn.relapse(b);
        (,,,,,,,, BuildNothing.Status stB,) = bn.vows(b);
        assertEq(uint8(stB), uint8(BuildNothing.Status.Relapsed));
        assertEq(bn.activeVowOf(bob), 0); // freed to vow again

        // alice survives the rest
        _beatDaily(a, snitchA, 3);
        vm.warp(block.timestamp + 1);
        bn.resolve(a);

        (, uint32 epochId) = _vowEpoch(a);
        (uint64 eEnd,,,,,) = bn.epochs(epochId);
        vm.warp(uint256(eEnd) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochId);

        uint256 before = alice.balance;
        bn.claim(a);
        assertEq(alice.balance, before + 20 ether); // principal + bob's slash
    }

    function test_relapse_after_end_reverts() public {
        uint256 id = _commit(alice, snitchA, 1 days, 1 ether);
        _beatDaily(id, snitchA, 1);
        vm.warp(block.timestamp + 1);
        vm.prank(snitchA);
        vm.expectRevert(BuildNothing.VowOver.selector);
        bn.relapse(id);
    }

    // ------------------------------------------------------------ tamper path
    function test_dead_snitch_slashes() public {
        uint256 a = _commit(alice, snitchA, 5 days, 4 ether);
        uint256 b = _commit(bob, snitchB, 5 days, 4 ether);

        _beatDaily(a, snitchA, 1);
        // alice's snitch goes silent after day 1 => gap 4 days > 48h
        // bob beats faithfully
        for (uint256 i = 1; i < 5; i++) {
            vm.warp(block.timestamp + 1 days);
            vm.prank(snitchB);
            bn.heartbeat(b);
        }
        vm.warp(block.timestamp + 1);
        bn.resolve(a);
        bn.resolve(b);
        (,,,,,,,, BuildNothing.Status stA,) = bn.vows(a);
        (,,,,,,,, BuildNothing.Status stB,) = bn.vows(b);
        assertEq(uint8(stA), uint8(BuildNothing.Status.Slashed));
        assertEq(uint8(stB), uint8(BuildNothing.Status.Survived));

        (, uint32 epochId) = _vowEpoch(b);
        (uint64 eEnd,,,,,) = bn.epochs(epochId);
        vm.warp(uint256(eEnd) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochId);

        uint256 before = bob.balance;
        bn.claim(b);
        assertEq(bob.balance, before + 8 ether);
    }

    function test_offline_grace_survives() public {
        // 36h gap is within the 48h grace
        uint256 id = _commit(alice, snitchA, 3 days, 1 ether);
        vm.warp(block.timestamp + 36 hours);
        vm.prank(snitchA);
        bn.heartbeat(id);
        vm.warp(block.timestamp + 36 hours + 1); // past end (72h)
        bn.resolve(id);
        (,,,,,,,, BuildNothing.Status st,) = bn.vows(id);
        assertEq(uint8(st), uint8(BuildNothing.Status.Survived));
    }

    // ------------------------------------------------------------ rollover
    function test_rollover_when_nobody_survives() public {
        uint256 a = _commit(alice, snitchA, 2 days, 3 ether);
        vm.prank(snitchA);
        bn.relapse(a);

        (, uint32 epochId) = _vowEpoch(a);
        (uint64 eEnd,,,,,) = bn.epochs(epochId);
        vm.warp(uint256(eEnd) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochId);
        assertEq(bn.rolloverPool(), 3 ether);

        // next cohort: bob survives and inherits the jackpot
        uint256 b = _commit(bob, snitchB, 2 days, 1 ether);
        _beatDaily(b, snitchB, 2);
        vm.warp(block.timestamp + 1);
        bn.resolve(b);
        (, uint32 epochB) = _vowEpoch(b);
        (uint64 eEndB,,,,,) = bn.epochs(epochB);
        vm.warp(uint256(eEndB) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochB);

        uint256 before = bob.balance;
        bn.claim(b);
        assertEq(bob.balance, before + 1 ether + 3 ether);
        assertEq(bn.rolloverPool(), 0);
    }

    // ------------------------------------------------------------ late resolve
    function test_late_resolve_gets_principal_only() public {
        uint256 a = _commit(alice, snitchA, 2 days, 5 ether);
        uint256 b = _commit(bob, snitchB, 2 days, 5 ether);
        uint256 c = _commit(carol, snitchC, 2 days, 5 ether);

        // carol relapses; alice and bob survive; bob resolves late
        vm.prank(snitchC);
        bn.relapse(c);
        _beatDaily(a, snitchA, 2);
        vm.prank(snitchB);
        bn.heartbeat(b); // bob beats via warp side effect of a's loop; ensure last beat fresh
        vm.warp(block.timestamp + 1);
        bn.resolve(a); // alice resolves in time

        (, uint32 epochId) = _vowEpoch(a);
        (uint64 eEnd,,,,,) = bn.epochs(epochId);
        vm.warp(uint256(eEnd) + bn.CLAIM_WINDOW() + 1);
        bn.finalizeEpoch(epochId);

        bn.resolve(b); // bob resolves AFTER finalize
        (,,,,,,,,, bool principalOnly) = bn.vows(b);
        assertTrue(principalOnly);

        uint256 beforeA = alice.balance;
        bn.claim(a);
        assertEq(alice.balance, beforeA + 5 ether + 5 ether); // full slash pool

        uint256 beforeB = bob.balance;
        bn.claim(b);
        assertEq(bob.balance, beforeB + 5 ether); // principal only, ratio intact
    }

    // ------------------------------------------------------------ auth
    function test_only_snitch_reports() public {
        uint256 id = _commit(alice, snitchA, 2 days, 1 ether);
        vm.prank(bob);
        vm.expectRevert(BuildNothing.NotSnitch.selector);
        bn.heartbeat(id);
        vm.prank(alice); // even the penitent can't self-report
        vm.expectRevert(BuildNothing.NotSnitch.selector);
        bn.relapse(id);
    }

    // ------------------------------------------------------------ donations
    function test_donation_seeds_jackpot() public {
        vm.prank(alice);
        (bool ok, ) = address(bn).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(bn.rolloverPool(), 2 ether);
    }

    // ------------------------------------------------------------ util
    function _vowEpoch(uint256 vowId) internal view returns (bool, uint32) {
        (,,,,,,, uint32 epochId,,) = bn.vows(vowId);
        return (true, epochId);
    }
}

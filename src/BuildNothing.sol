// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BUILD NOTHING - stake on not vibecoding
/// @notice Submitted to a hackathon about building anything.
///
///         Commit MON to a vow of abstinence from Claude Code.
///         A local "snitch" (Claude Code hook + cron) reports on you:
///         - heartbeat(): daily proof the snitch is alive and untampered
///         - relapse():   fired the moment a Claude Code session starts
///         Survive your vow with an unbroken heartbeat chain and no relapse,
///         and you reclaim your stake plus a share of the slashed pool.
///
///         Trust model (tamper-EVIDENT, not tamper-proof):
///         - Missing heartbeat  => failure (killing the snitch = losing)
///         - Relapse ping       => immediate failure
///         - Surgically removing the hook while keeping the cron alive is
///           possible; that is deliberate fraud against a small-stakes game,
///           not a weakness we pretend doesn't exist. See README threat model.
///         - Stakes are capped because this contract is unaudited.
contract BuildNothing {
    // ---------------------------------------------------------------- config
    uint256 public constant MAX_GAP = 48 hours;   // grace for offline machines
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 30 days;
    uint256 public constant MAX_STAKE = 100 ether; // MON; unaudited-contract cap
    uint256 public constant CLAIM_WINDOW = 7 days; // resolve deadline after vow end
    uint256 public constant EPOCH_LENGTH = 7 days;

    // ---------------------------------------------------------------- state
    enum Status { None, Active, Relapsed, Survived, Slashed }

    struct Vow {
        address penitent;      // the one who vows
        address snitch;        // burner authorized to report
        uint64  start;
        uint64  end;
        uint64  lastBeat;
        uint64  maxGap;        // running max gap between beats
        uint128 stake;
        uint32  epochId;
        Status  status;
        bool    principalOnly; // resolved after epoch finalize: no pool share
    }

    struct Epoch {
        uint64  end;           // vows ending by this settle in this epoch
        uint128 slashedPool;   // stakes of the fallen
        uint128 survivorStake; // total stake of survivors (payout weights)
        uint128 rolloverIn;    // jackpot inherited from survivor-less epochs
        uint32  survivors;
        bool    finalized;
    }

    uint256 public nextVowId;
    uint32  public currentEpoch;
    uint128 public rolloverPool; // slashed funds nobody survived to claim

    mapping(uint256 => Vow) public vows;
    mapping(uint32 => Epoch) public epochs;
    mapping(address => uint256) public activeVowOf; // one active vow per address
    mapping(uint256 => bool) public paidOut;

    // ---------------------------------------------------------------- events
    event Committed(uint256 indexed vowId, address indexed penitent, address snitch, uint64 start, uint64 end, uint128 stake, uint32 epochId);
    event Heartbeat(uint256 indexed vowId, uint64 at, uint64 maxGap);
    event Relapsed(uint256 indexed vowId, uint64 at, uint64 cleanSeconds);
    event Survived(uint256 indexed vowId, uint128 stake, bool principalOnly);
    event SlashedNoBeat(uint256 indexed vowId, uint64 worstGap);
    event EpochFinalized(uint32 indexed epochId, uint128 slashedPool, uint128 rolloverIn, uint32 survivors);
    event Payout(uint256 indexed vowId, address indexed penitent, uint256 amount);

    // ---------------------------------------------------------------- errors
    error BadDuration();
    error BadStake();
    error VowAlreadyActive();
    error NotSnitch();
    error NotActive();
    error VowNotOver();
    error VowOver();
    error NothingToClaim();
    error EpochNotFinalized();
    error EpochStillOpen();
    error TransferFailed();

    // ---------------------------------------------------------------- epochs
    constructor() {
        currentEpoch = 1;
        epochs[1].end = uint64(block.timestamp + EPOCH_LENGTH);
    }

    /// @notice Anyone may roll the epoch pointer forward past elapsed epochs.
    function rollEpoch() public {
        while (block.timestamp > epochs[currentEpoch].end) {
            uint64 prevEnd = epochs[currentEpoch].end;
            currentEpoch += 1;
            if (epochs[currentEpoch].end == 0) {
                epochs[currentEpoch].end = prevEnd + uint64(EPOCH_LENGTH);
            }
        }
    }

    // ---------------------------------------------------------------- commit
    /// @param duration seconds of abstinence vowed
    /// @param snitch   burner address (funded with dust) that reports
    function commit(uint256 duration, address snitch) external payable returns (uint256 vowId) {
        rollEpoch();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert BadDuration();
        if (msg.value == 0 || msg.value > MAX_STAKE) revert BadStake();
        if (activeVowOf[msg.sender] != 0) revert VowAlreadyActive();
        if (snitch == address(0) || snitch == msg.sender) revert NotSnitch();

        vowId = ++nextVowId;
        uint64 nowTs = uint64(block.timestamp);
        uint64 endTs = nowTs + uint64(duration);

        // vow joins the epoch in which it ENDS, so weekly cohorts settle together
        uint32 epochId = currentEpoch;
        while (epochs[epochId].end < endTs) {
            uint64 prevEnd = epochs[epochId].end;
            epochId += 1;
            if (epochs[epochId].end == 0) {
                epochs[epochId].end = prevEnd + uint64(EPOCH_LENGTH);
            }
        }

        vows[vowId] = Vow({
            penitent: msg.sender,
            snitch: snitch,
            start: nowTs,
            end: endTs,
            lastBeat: nowTs,
            maxGap: 0,
            stake: uint128(msg.value),
            epochId: epochId,
            status: Status.Active,
            principalOnly: false
        });
        activeVowOf[msg.sender] = vowId;

        emit Committed(vowId, msg.sender, snitch, nowTs, endTs, uint128(msg.value), epochId);
    }

    // ---------------------------------------------------------------- snitch
    function heartbeat(uint256 vowId) external {
        Vow storage v = vows[vowId];
        if (msg.sender != v.snitch) revert NotSnitch();
        if (v.status != Status.Active) revert NotActive();
        uint64 nowTs = uint64(block.timestamp);
        // beats after vow end are clamped: post-end silence is not a gap
        uint64 effective = nowTs < v.end ? nowTs : v.end;
        uint64 gap = effective - v.lastBeat;
        if (gap > v.maxGap) v.maxGap = gap;
        v.lastBeat = effective;
        emit Heartbeat(vowId, nowTs, v.maxGap);
    }

    function relapse(uint256 vowId) external {
        Vow storage v = vows[vowId];
        if (msg.sender != v.snitch) revert NotSnitch();
        if (v.status != Status.Active) revert NotActive();
        if (block.timestamp >= v.end) revert VowOver(); // already survived
        v.status = Status.Relapsed;
        activeVowOf[v.penitent] = 0;
        epochs[v.epochId].slashedPool += v.stake;
        emit Relapsed(vowId, uint64(block.timestamp), uint64(block.timestamp) - v.start);
    }

    // ---------------------------------------------------------------- settle
    /// @notice After the vow ends, anyone may resolve it (usually the penitent).
    ///         Resolving after the epoch is finalized still returns principal
    ///         but forfeits the pool share - the payout ratio is frozen.
    function resolve(uint256 vowId) public {
        Vow storage v = vows[vowId];
        if (v.status != Status.Active) revert NotActive();
        if (block.timestamp < v.end) revert VowNotOver();

        uint64 tailGap = v.end - v.lastBeat;
        uint64 worst = tailGap > v.maxGap ? tailGap : v.maxGap;

        activeVowOf[v.penitent] = 0;
        Epoch storage e = epochs[v.epochId];

        if (worst > MAX_GAP) {
            v.status = Status.Slashed;
            if (!e.finalized) {
                e.slashedPool += v.stake;
            } else {
                rolloverPool += v.stake; // late slash rolls forward
            }
            emit SlashedNoBeat(vowId, worst);
        } else {
            v.status = Status.Survived;
            if (!e.finalized) {
                e.survivorStake += v.stake;
                e.survivors += 1;
            } else {
                v.principalOnly = true;
            }
            emit Survived(vowId, v.stake, v.principalOnly);
        }
    }

    /// @notice Freeze an epoch's payout ratio after its claim window passes.
    ///         If nobody survived, the slashed pool rolls into the global
    ///         jackpot which the next finalized epoch's survivors inherit.
    function finalizeEpoch(uint32 epochId) external {
        Epoch storage e = epochs[epochId];
        if (e.finalized) return;
        if (e.end == 0) revert EpochStillOpen();
        if (block.timestamp < uint256(e.end) + CLAIM_WINDOW) revert EpochStillOpen();
        e.finalized = true;
        if (e.survivors == 0) {
            if (e.slashedPool > 0) {
                rolloverPool += e.slashedPool;
                e.slashedPool = 0;
            }
        } else {
            // survivors inherit the accumulated jackpot, snapshotted here
            e.rolloverIn = rolloverPool;
            rolloverPool = 0;
        }
        emit EpochFinalized(epochId, e.slashedPool, e.rolloverIn, e.survivors);
    }

    /// @notice Survivor payout: principal + pro-rata slashed pool + jackpot.
    function claim(uint256 vowId) external {
        Vow storage v = vows[vowId];
        if (v.status == Status.Active && block.timestamp >= v.end) resolve(vowId);
        if (v.status != Status.Survived) revert NothingToClaim();
        if (paidOut[vowId]) revert NothingToClaim();

        Epoch storage e = epochs[v.epochId];
        if (!e.finalized) revert EpochNotFinalized();

        paidOut[vowId] = true;
        uint256 amount = v.stake;
        if (!v.principalOnly && e.survivorStake > 0) {
            amount += (uint256(e.slashedPool) * v.stake) / e.survivorStake;
            amount += (uint256(e.rolloverIn) * v.stake) / e.survivorStake;
        }

        (bool ok, ) = v.penitent.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Payout(vowId, v.penitent, amount);
    }

    // ---------------------------------------------------------------- views
    function vowState(uint256 vowId) external view returns (
        Status status, uint64 cleanSeconds, uint64 secondsLeft, uint64 worstGap, bool beatOverdue
    ) {
        Vow storage v = vows[vowId];
        status = v.status;
        uint64 nowTs = uint64(block.timestamp);
        uint64 capped = nowTs < v.end ? nowTs : v.end;
        uint64 anchor = v.status == Status.Active ? capped : v.lastBeat;
        cleanSeconds = anchor > v.start ? anchor - v.start : 0;
        secondsLeft = nowTs < v.end ? v.end - nowTs : 0;
        uint64 tail = capped > v.lastBeat ? capped - v.lastBeat : 0;
        worstGap = tail > v.maxGap ? tail : v.maxGap;
        beatOverdue = v.status == Status.Active && worstGap > MAX_GAP;
    }

    receive() external payable {
        // donations seed the rollover jackpot
        rolloverPool += uint128(msg.value);
    }
}

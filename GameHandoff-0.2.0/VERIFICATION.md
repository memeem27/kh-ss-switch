# Game Handoff 0.2.0 verification record

Verified on 2026-09-16 for Windows x64.

## Exact compatibility inputs

- Hollow Knight target: 1.5.78.11833, checked against `D:\HKrip` and the
  Modding API v77 patched game assembly.
- Modding API v77 Windows ZIP SHA-256:
  `BC9F0DB3D0916B05CD5A2420BB602FB1B239CE3FF6C289FD84BFFB682FB8F1D6`
- Modding API v77 `Assembly-CSharp.dll` SHA-256:
  `5944411BD93830369390A4B51766EE68C4AB26195B299E25A07B5E7D0E00086D`
- Hollow Knight DebugMod 1.4.10.5 SHA-256:
  `F3712E5AAAC6DA9C8967CEE513CCBECEB8B7981342D3D850E897F77AE9F531A3`
- Silksong target: 1.0.30000, checked against `D:\SSrip`.
- Silksong target `Assembly-CSharp.dll` SHA-256:
  `E17E9C2ABB413E1B6A3FE764D5D4647A632F1C757CB13A6927E59EC8FEF5E086`
- Silksong DebugMod 1.1.2 SHA-256:
  `7E7D52C11A7A67C9D2E27D3B497FA192CD50CB38B314602417011671F7E8CC78`
- Silksong BepInEx assembly version: 5.4.23.4.

Binary metadata inspection confirmed every reflected DebugMod type, method,
field, property, event, and BepInEx plugin GUID used by the adapters. Hollow
Knight DebugMod 1.4.10.5 was also rebuilt from source against the exact v77
reference set with zero compile errors.

## Clean builds

The Common library, coordinator, Hollow Knight adapter, Silksong adapter, and
test program all built successfully in Release configuration with zero warnings
and zero errors. The coordinator was published as a self-contained Windows x64
single-file executable and smoke-tested from the extracted release archive.

## Automated test coverage

The final test run passed all of the following:

- binary protocol round-trip and malformed/oversized frame rejection;
- HMAC authentication primitives and real wrong-key connection rejection;
- silent authenticated-peer heartbeat timeout;
- exact game-version rejection;
- two coordinators plus four simulated game processes;
- simultaneous damage on both computers producing exactly one handoff;
- stale epoch rejection (no delayed double swap);
- 8 MiB state transfer in both directions with byte-for-byte verification;
- delayed load acknowledgment proving the two-sided commit barrier;
- second handoff in the reverse direction;
- local game disconnect freezing/disarming both computers;
- reconnect requiring both players to re-arm;
- deliberately stalled state capture triggering the exchange timeout;
- one-click preflight passing against a synthetic exact-version installation;
- internal package SHA-256 manifest verification after ZIP extraction.

## Remaining real-world validation

A real two-computer playtest inside both Unity games is still required. Automated
tests cannot reproduce every scene-specific DebugMod coroutine, cutscene,
elevator, boss arena, or Windows focus restriction. The adapters therefore wait
for DebugMod success plus a stable post-load game state, and any rejection,
exception signal, disconnect, heartbeat loss, or timeout freezes both sides
instead of committing a possibly divergent handoff.

# Game Handoff 0.2.2

Game Handoff swaps two players between **Hollow Knight** and **Hollow Knight:
Silksong 1.0.30000** whenever either active player loses health. Hollow Knight
1.5.78.11833 is the tested build, but other Hollow Knight versions are allowed
to start with a visible warning instead of being rejected.
It uses the games' community DebugMod savestate implementations (these are not
official Team Cherry tools); it does not try to convert a Hollow Knight state
into a Silksong state. Instead, each Hollow Knight state goes to the other
computer's Hollow Knight process, and likewise for Silksong.

This is a Windows/LAN beta. Use disposable modded save slots and back up both
games' save directories before testing it.

## What is included

- `GameHandoff.HollowKnight.dll`: a Modding API v77 mod tested on HK
  1.5.78.11833; the game-version check is advisory only.
- `GameHandoff.Silksong.dll`: a BepInEx plugin for Silksong 1.0.30000.
- `GameHandoff.Common.dll`: the shared authenticated framing protocol.
- `GameHandoff.Coordinator.dll`: a normal managed .NET coordinator. One copy
  runs on each computer through Microsoft's installed `dotnet` host and connects
  through Hamachi. The release deliberately contains no custom executable.

The host coordinator is authoritative. A swap completes only after both incoming
states finish loading. A disconnect or load error leaves both games frozen so the
two sessions cannot silently diverge. Authenticated heartbeats detect silent
Hamachi failures, and a stalled handoff times out after 180 seconds.

## Requirements on both computers

1. Silksong 1.0.30000. Hollow Knight 1.5.78.11833 is tested; other Hollow
   Knight versions can start but are unverified.
2. Hollow Knight Modding API **v77** and DebugMod **1.4.10.5**.
3. Silksong BepInEx **5.4.23.4** and HK-Speedrunning DebugMod **1.1.2**.
4. Hamachi, with both computers joined to the same Hamachi network.
5. Microsoft .NET 8 Runtime (`Microsoft.NETCore.App 8.x`). The preflight checker
   verifies this before play.
6. Both games running in borderless/windowed mode. Exclusive fullscreen can
   prevent Windows from changing focus reliably.

DebugMod quickslots are reserved by Game Handoff and will be overwritten.
Loading a DebugMod state can also overwrite the selected normal save slot.

The exact tested DebugMod binaries have these SHA-256 hashes:

- Hollow Knight DebugMod 1.4.10.5:
  `F3712E5AAAC6DA9C8967CEE513CCBECEB8B7981342D3D850E897F77AE9F531A3`
- Silksong DebugMod 1.1.2:
  `7E7D52C11A7A67C9D2E27D3B497FA192CD50CB38B314602417011671F7E8CC78`

## Installation

Install these files on **both** computers:

### Hollow Knight

Copy this pair into:

`Hollow Knight/hollow_knight_Data/Managed/Mods/GameHandoff/`

- `GameHandoff.HollowKnight.dll`
- `GameHandoff.Common.dll`

### Silksong

Copy this pair into:

`Hollow Knight Silksong/BepInEx/plugins/GameHandoff/`

- `GameHandoff.Silksong.dll`
- `GameHandoff.Common.dll`

### Coordinator

Keep the `Coordinator` folder anywhere convenient. The host edits `host.ini`; the
other player edits `client.ini`.

- Replace `CHANGE_ME...` with the same long private random text on both computers.
- The client sets `peerAddress` to the host's Hamachi IPv4 address, normally a
  `25.x.x.x` address.
- `initialGame` in `host.ini` chooses the host player's first game. The joining
  player automatically starts in the other game.
- Keep `localPort` and `peerPort` unchanged unless another application uses them.
- If Windows Firewall prompts the host, allow the coordinator on the network used
  by Hamachi.

Start it with `Start Host.cmd` or `Start Client.cmd`.

### Antivirus note

This release uses a framework-dependent DLL because an unsigned, self-contained,
single-file .NET executable can attract heuristic antivirus detections. The CMD
launchers call the installed Microsoft `dotnet` host; they do not disable,
exclude, or modify antivirus settings. Do not create an antivirus exclusion for
Game Handoff. Verify `SHA256SUMS.txt`, keep the source archive, and report the
exact detection name and flagged file if this no-EXE package is still detected.

## Preflight (do not skip)

After installing everything, double-click `Run Preflight.cmd` on each computer.
The host uses its default `host` mode. On the joining computer, run:

```text
Run Preflight.cmd -Mode client
```

The checker finds normal Steam installs and verifies Silksong, Modding API,
DebugMod, BepInEx, adapter, common-library, coordinator, and configuration
versions. A different Hollow Knight game version produces `WARN` and does not
fail preflight; all other required lines must say `PASS`. For nonstandard paths:

```text
Run Preflight.cmd -Mode client -HollowKnightPath "D:\Games\Hollow Knight" -SilksongPath "D:\Games\Hollow Knight Silksong"
```

## Playing

1. Pass preflight on both computers.
2. On each computer, launch both games and enter disposable gameplay save slots.
   Do not arm during a cutscene, death, elevator ride, or room transition.
3. Launch each coordinator.
4. Enter `status`. Each coordinator must show `peer=connected`, both local games,
   both remote games, and coordinator `0.2.2/0.2.2`.
5. Enter `arm` on both computers.
6. The host begins in `initialGame`; the friend begins in the other game.
7. When either active player loses health, both current games freeze, both states
   are exchanged, and control switches after both loads finish.

Fatal damage and hazard-respawn transitions do not start a handoff; the normal
death/respawn sequence is allowed to finish. For 1.5 seconds after a completed
load, duplicate damage notifications are ignored to prevent an immediate second
switch. After loading, the adapter also moves the hero only if its collider is
actually overlapping terrain.

Coordinator commands:

- `status`: show connections and current ownership.
- `arm`: mark this player ready or re-arm after a recoverable failure.
- `swap`: manually test the same handoff without taking damage.
- `quit`: cleanly disarm the mods and close the coordinator.

Automatic focus uses three restore/foreground attempts. Windows can still deny
focus stealing in some desktop configurations; if that happens, click the newly
active game once. Set `focusWindows=false` if you prefer switching manually.

After any `SESSION STOPPED` message, fix the reported problem, make sure both game
mods have reconnected, and enter `arm` again on **both** computers. One-sided
re-arming is deliberately refused.

Optional coordinator settings are `exchangeTimeoutSeconds=180` (10-600) and
`peerTimeoutSeconds=30` (10-120). Keep the defaults unless slow Hamachi transfers
need a longer exchange timeout. If you change `localPort`, create a
`GameHandoff.ini` containing the same `localPort` in each game's Unity persistent
data folder; leaving port 32970 unchanged avoids this extra setup.

## Current limitations

- A real two-machine playtest is still required. The complete protocol and swap
  state machine are covered by a four-game integration simulation (including
  simultaneous damage, 8 MiB states, delayed loads, disconnect/reconnect, bad
  authentication, stale messages, and timeouts), but scene-specific behavior can
  only be validated inside the games.
- Hollow Knight builds other than 1.5.78.11833 are intentionally allowed but
  have not been compatibility-tested. The coordinator logs a warning and keeps
  the DebugMod, Modding API, and adapter safety checks enabled.
- A remote player continues moving for the Hamachi round-trip before their game
  receives the freeze command.
- Swaps during unusual cutscenes, elevators, death sequences, or scene transitions
  may be rejected by DebugMod. Both games remain frozen instead of forcing a load.
- This is for casual/modded play, not speedrun submissions.

## Building from source

The checked-in project defaults use the decompiled reference assemblies at
`D:\HKrip` and `D:\SSrip`. Override these MSBuild properties if yours differ:

```powershell
dotnet build src\HollowKnight\GameHandoff.HollowKnight.csproj -c Release /p:HKGameRefs="X:\path\to\HK\assemblies" /p:HKModdingApiRefs="X:\path\to\modding-api-v77"
dotnet build src\Silksong\GameHandoff.Silksong.csproj -c Release /p:SSGameRefs="X:\path\to\SS\assemblies" /p:BepInExRefs="X:\path\to\BepInEx\core"
dotnet build src\Coordinator\GameHandoff.Coordinator.csproj -c Release
dotnet publish src\Coordinator\GameHandoff.Coordinator.csproj -c Release --no-self-contained -p:UseAppHost=false
dotnet build tests\GameHandoff.Tests.csproj -c Release
dotnet .\tests\bin\Release\net8.0\GameHandoff.Tests.dll
```

The adapters deliberately use reflection only for DebugMod's savestate boundary.
That avoids linking or redistributing either game's code or DebugMod binaries.

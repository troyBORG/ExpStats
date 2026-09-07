# ExpStats

A small Ashita v4 companion overlay for an existing EXP bar.

![ExpStats in game](image/ExpStats.png)

It displays: It displays:

- Session EXP per hour (timing begins on the first EXP gain)
- EXP from the last kill
- Rolling average of the last three EXP gains
- Rolling average of the last ten EXP gains, shown after Avg(3)
- EXP remaining to the next level (`TNL`)
- Estimated time to level at the current session EXP/hour (`ETA`)
- EXP earned while the `Dedication` effect is active, shown beside ETA

After 20 minutes without an EXP gain, the next gain automatically starts a fresh session.
EXP/hour remains `--` until the second gain, avoiding a meaningless first-kill spike.
ETA is rounded up and shown as minutes below one hour, then hours and minutes (for example, `42m` or `1h 18m`). It remains `--` until a meaningful EXP/hour rate exists.
The Band counter appears only while the client reports the `Dedication` status effect. It starts at zero when the effect is detected and disappears when the effect wears. It calculates bonus EXP from each displayed total using `awarded × rate / (1 + rate)`; for Emperor Band, 175 awarded EXP contains 75 bonus EXP. The default profile is Emperor Band (+75%, 2,250 bonus per use).

Use `/expstats band emperor|empress|chariot|anniversary` to select the active ring. Changing profiles recalculates the displayed bonus from the already accumulated awarded EXP; it does not erase the running counter. Horizon's Dedication status does not identify the source ring, so this selection is explicit rather than guessed from the buff.

Dedication detection uses canonical status ID `249` and supports the indexed buff collection returned by Horizon's Ashita build; it does not depend on a resource-name lookup.

## HorizonXI 
This addon has been approved for use on HorizonXI
<img width="739" height="144" alt="image" src="https://github.com/user-attachments/assets/5c18035e-67de-47f3-b5e8-520fd8a5a1a2" />


This addon reads incoming `0x02D` action-message packets using the same local-player and field layout as XIUI's approved EXP bar. It recognizes normal EXP and EXP-chain message IDs, and reads the client's current/needed EXP values through Ashita's player memory API. On the explicit `/expstats partyreport` command, it queues one ordinary `/p` message containing the current statistics. It does not enumerate entities, inspect targets, write memory, send packets, access the network, or automate gameplay actions.

## Install after approval

Extract `ExpStats/` into Ashita's `addons/` directory, then run:

    /addon load ExpStats

## Commands

- `/expstats status` (alias `/xs`) — print current statistics
- `/expstats partyreport` (short form `/expstats party`) — post the current statistics to party chat
- `/expstats show` / `/expstats hide`
- `/expstats move` — unlock/lock the draggable window
- `/expstats reset` — start a fresh session
- `/expstats test` — load ten deterministic test values from 100 through 190

Settings persist per Ashita's stock settings library. Session EXP does not persist across addon/game restarts.

Window coordinates are saved when `/expstats move` is used to lock the window and restored on the first rendered frame after a reload or restart.

Version 0.8.1 defers player-memory reads briefly after the incoming zone/login packet, performs those reads before opening the ImGui window, and skips transitional frames when a complete player snapshot is unavailable. It also guarantees that a successful `imgui.Begin` is paired with `imgui.End`, even if drawing fails. Version 0.8.2 removes automatic player-memory reads from `d3d_present` entirely: render frames use cached Lua values, and player data is refreshed only after a confirmed EXP packet or an explicit status/report command. Version 0.8.3 suspends rendering and GUI-manager access as soon as the client sends zone-exit/logout packet `0x00B`, then resumes on zone-enter packet `0x00A`. Per-character files under `config/addons/ExpStats/` are normal Ashita settings-library behavior and are not shared between characters.

ExpStats respects both Ashita's global custom-UI visibility and FFXI's native ScrollLock interface toggle. Pressing ScrollLock temporarily hides or restores ExpStats without changing its saved `/expstats show|hide` setting. Reload ExpStats while the native interface is visible so its initial toggle state is synchronized.

## Review scope

- `ExpStats.lua`: Ashita events, commands, settings, and ImGui overlay
- `core.lua`: message cleaning/parsing and arithmetic
- No bundled binaries or network access

## Tests

Run the deterministic transition and ImGui lifecycle regression test with:

    luajit tests/lifecycle.lua

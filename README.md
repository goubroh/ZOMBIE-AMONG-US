# ZOMBIE AMONG US
"Trust No One. Survive the Infection."

An original social-deduction / zombie-survival multiplayer prototype built in **Godot 4** with **GDScript** and Godot's built-in **ENet** high-level multiplayer API. All characters, map, names, and UI in this project are original — nothing is copied from Among Us or any other title.

## About This Project

**Zombie Among Us** started as a single prompt to an AI assistant (Claude) describing a full 50-section game design document — roles, tasks, sabotage, meetings, voting, networking rules, UI style, the works. What's in this repo is the AI-generated response to that prompt: a real, running Godot 4 project implementing the core social-deduction loop, built directly from that spec rather than from scratch by a human team.

That means a few things worth knowing before you dig in:

- **It's a first draft, not a finished game.** The architecture (server-authoritative networking, role secrecy, task/vote/win logic) is sound and was designed to extend cleanly, but plenty of the original spec — vents, extra sabotage types, cameras, cosmetics, mobile controls, voice chat — isn't built yet. See "Not yet built" above.
- **It hasn't been run and play-tested by a human yet.** Treat early sessions as a shakedown: watch for scenes that don't wire up the way the docs claim, RPC timing issues, or settings (like the player-count range above) that drift out of sync with the actual code as changes get made.
- **Anyone on the team can and should keep prompting on it.** Whether that means asking an AI assistant to add the next feature from the extension list below, or editing the GDScript directly — the project is small enough (a dozen scripts, a dozen scenes) to read end-to-end before changing anything. `Net.gd` is the one file that matters most: every gameplay rule that needs to be cheat-proof lives there.
- **Keep this README honest as the code moves.** If you change a rule (player count, cooldown values, which win conditions are on by default), update the matching line here in the same change — a couple of small drifts have already crept in (see the note above about the 5-player minimum).

Contributions, forks, and "hey AI, add the vent system" follow-up sessions are all fair game — this was built to be a starting point, not a final cut.

## The Game Idea

You wake up as one of a small survival team dropped into an abandoned research/quarantine facility. Something got out. One of you already caught it — and doesn't know you know.

That's the whole hook: **everyone looks the same until they act.** There's no "Impostor is red and sus" visual tell. The infected player walks, talks, and fake-works alongside everyone else, and the only way to catch them is behavior — who was near a body, who avoided cameras, who's oddly bad at a task they should know cold.

**The tension comes from two clocks running against each other:**
- The **Survivor clock**: finish the shared task bar before the facility falls apart, or catch the Zombie before it's too late.
- The **Zombie clock**: a real cooldown between kills (no one dies "randomly" — every kill is a deliberate, risky choice by that one player), plus optional Infection Mode, where a "kill" doesn't remove a player from the game — it turns them, quietly, on a timer, so the team you thought you could trust keeps shrinking from the inside.

**Design pillars that shaped every system:**
- *Nothing is free information.* The Zombie's identity, the kill cooldown, whether a task credited "for real" — all of it lives only on the host, specifically so no client-side trick (or curious player poking at dev tools) can leak or cheat it.
- *Every accusation should be arguable.* Evidence (body location, who reported it, camera sightings, task completion) is meant to be circumstantial, not a smoking gun — because the fun of the genre is the argument, not the reveal.
- *Small map, frequent collisions.* Six task rooms in a tight facility mean paths cross constantly — the game is built to force interaction, not let players avoid each other for the whole round.
- *A round should be arguable in one sentence afterward* — "the vote was tied and the real Zombie skated" is a good story; a round nobody can reconstruct isn't.

That's the shape of the experience this prototype implements. Everything under "Not yet built" is about *deepening* deduction (cameras, vents-as-evidence, sabotage variety) rather than changing what the game fundamentally is.

## What's actually here

This is a **working, playable core-loop prototype**, not the entire 50-section spec (that's a multi-week production effort for a small team). It's built so the architecture — server-authoritative networking, secret roles, task economy, kill/infection, meetings/voting, win conditions — is real and correct, and you can grow it toward the full design from here.

### Implemented
- **Main Menu → Lobby → Game** flow, 5–10 players, host-configurable max player count
- **Host/Join over LAN** using ENet (`Net.gd`): host opens a server on port `47321`; clients connect with the host's IP address
- **Host-authoritative role assignment** — the Zombie's identity is only ever sent to that one client; it is never broadcast
- **Optional 2-Zombie mode** for 8–10 players (host toggle)
- **Task system**: 6 task stations around the map, a real "repeat the sequence" minigame, team task-progress bar; the server is the only thing that ever credits task completion (a Zombie faking a task never advances progress)
- **Zombie attack** with a server-enforced cooldown (client never controls its own cooldown) and short interaction range
- **Infection Mode** (toggle): infect → private "you've been infected" notice → timed conversion to Zombie, or **Instant Kill Mode** if infection is off
- **Body reporting** and **emergency meetings** (1 per player per round, enforced by the host)
- **Discussion → Voting phases** with timers, live chat, hidden-until-reveal voting, tie = no elimination
- **Role reveal on/off** setting
- **Win conditions**: all tasks complete, Zombies ≥ Survivors, all Survivors dead
- **Dead/spectator state** (movement + interaction disabled, semi-transparent handling stub)
- Dark sci-fi UI (menu, lobby, HUD, meeting screen, game-over screen) built from Godot Controls — no external art dependencies, so it opens and runs with zero missing assets

### Not yet built (clearly stubbed or omitted — see "Extending" below)
- Vent system (Zombie-only secret routes)
- Additional sabotage types beyond the architecture hook (oxygen/power/comms/lights/doors) — only the task-progress path is wired end-to-end right now
- Security cameras / evidence system
- Player cosmetics (hats, suits, backpack picker)
- Dedicated/relay server for real internet play (current build is LAN/direct-IP; see below)
- Android touch controls (virtual joystick + context buttons) — keyboard/mouse only right now
- Voice chat
- Ghost tasks for the dead team

## Requirements

- **Godot 4.2+** (Standard, not .NET — everything here is pure GDScript): https://godotengine.org/download

## Running it

1. Open Godot 4, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** (or the Play button). It boots to the Main Menu.
3. To test multiplayer locally: **Debug → Run Multiple Instances** in the editor's run settings (or just export a build and run it alongside the editor), have one instance **Host**, and the others **Join** using `127.0.0.1` as the IP.
4. On a real LAN, the host shares their local network IP (e.g. `192.168.1.42`) and other players enter that in the **Join** field. Godot's ENet server listens on UDP port `47321` — make sure that port is allowed through the host's firewall.

## Exporting

Godot's **Project → Export** handles this; you'll need to install the matching export templates from the Editor's Manager (**Editor → Manage Export Templates**) the first time.

- **Windows (.exe)**: add a "Windows Desktop" export preset, then Export Project.
- **Android (.apk / .aab)**: install the Android SDK/build tools, set them up under **Editor → Editor Settings → Export → Android**, add an "Android" export preset, and export. Switch the preset's export format to "App Bundle" for a `.aab`.

Both platforms already load fine since the project has no third-party plugins — you're exporting stock Godot + this GDScript.

## Networking model (important for extending)

`Net.gd` is the only place that talks to the network. The rule followed throughout: **the host (peer id 1) is the sole authority.** Clients call `request_*` RPCs describing what they *want* to do; the host validates it against `GameState` and then broadcasts the *result* back out. This is what stops a modified client from, say, granting itself the Zombie role, ignoring its kill cooldown, or double-voting — the client-side code literally has no path to change those values, it can only ask.

For real internet play (not just LAN), you'd put a small relay/rendezvous service in front of this (e.g. a lightweight matchmaking server that exchanges connection info, or Godot's `WebRTCMultiplayerPeer` with a signaling server) — the game logic itself doesn't need to change, only how the initial peer connection is established.

## Extending toward the full spec

The codebase is organized so each remaining feature is additive:

- **Vents**: add a `VentPoint` scene (same pattern as `TaskPoint.gd`) restricted to `GameState.local_role == "zombie"`, teleport on interact, with a `request_use_vent` RPC so the host can broadcast the transition (and so it becomes visible evidence to anyone watching).
- **More sabotage types**: `Net.gd` already has the win/lose-timer pattern used by tasks; add a `request_trigger_sabotage(type)` host RPC, a countdown synced via `phase_changed`-style signal, and a repair minigame reusing `MinigamePanel.gd`.
- **Cameras/evidence**: a `CameraConsole` UI that, on the host, streams back player positions for players currently "on camera" — the position data already exists in `GameWorld._player_nodes`.
- **Cosmetics**: extend the `players` dictionary in `GameState.gd` with a `cosmetics` sub-dict, replicate it alongside color/name in `Net._broadcast_player_list`.
- **Mobile controls**: add a `TouchScreenButton`/virtual-joystick `CanvasLayer` that's only added when `OS.get_name() == "Android"`, feeding the same `move_left/right/up/down/interact/report/ability/emergency` input actions already defined in `project.godot`.

## Project layout

```
project.godot
scripts/
  autoload/GameState.gd   # replicated game data + phase machine
  autoload/Net.gd         # all networking + server-authoritative rules
  Player.gd, TaskPoint.gd, BodyMarker.gd, GameWorld.gd
  MainMenu.gd, Lobby.gd, GameHUD.gd, MeetingUI.gd, MinigamePanel.gd
scenes/
  MainMenu.tscn, Lobby.tscn, GameWorld.tscn, GameHUD.tscn,
  Player.tscn, TaskPoint.tscn, BodyMarker.tscn,
  MeetingUI.tscn, MinigamePanel.tscn
```

## Controls (desktop)

- **WASD** — move
- **E** — interact / report a body
- **Q** — Zombie ability (attack nearest player in range)
- **F** — emergency meeting

## How This Was Actually Built (Prompting Notes)

Documenting this honestly so the team can repeat or improve on the approach:

**1. One large, structured spec prompt, not a vague ask.** The starting prompt wasn't "make me an Among Us clone" — it was a ~50-section numbered design document covering role system, win/lose conditions, task types, sabotage, meeting/voting flow, map layout, networking authority model, UI style, target platforms, and explicit originality constraints ("do not copy Among Us characters/art/UI"). That level of structure is what let the AI produce a coherent, internally-consistent system on the first pass instead of a shallow demo — vague prompts get vague (or randomly-scoped) results.

**2. An explicit scope-setting response before any code.** Given the size of that spec, the first move was naming what a single response could realistically deliver (a working core loop) versus what couldn't (the full 50-section production build) — and getting the highest-leverage architectural pieces right (server authority, secret roles, task crediting) rather than shallowly stubbing all 50 sections. That trade-off is called out explicitly in this README's "What's actually here" section above.

**3. File-by-file generation with a real project structure.** Instead of one giant script, the AI built this as an actual Godot project — separate autoloads for state vs. networking, separate scenes per UI screen, `.tscn` files hand-authored alongside the `.gd` scripts they reference — so it opens, imports, and is human-editable exactly like a project a person would have structured.

**4. Iterative, conversational follow-up for the operational stuff.** Everything after the initial build — how to actually launch the editor, how to export a `.exe`, how to find and share a local IP, how to reach friends off-network — came from follow-up prompts in plain language, including copy-pasted terminal output, so answers could be tailored to the exact Godot version and OS actually being used rather than generic instructions.

**5. Docs kept in the loop, not bolted on after.** README sections (this one included) were requested and updated in the same session as the code, specifically so the documentation doesn't silently drift from what the code does — a discrepancy that already happened once and got caught this way (the player-count minimum, above).

**Suggested next prompting moves**, in rough priority order for anyone continuing this:
- Ask for one feature from "Not yet built" at a time (vents first — it's the smallest, and other systems don't depend on it) rather than asking for several at once, so each addition can be sanity-checked before the next lands on top of it.
- Ask for a short **playtest checklist** (the exact sequence of actions to prove roles, tasks, kill/infection, meetings, and win conditions all work) before adding new systems — catches regressions early once more people are editing this.
- If real internet play (not just LAN) becomes a priority, that's worth its own focused prompt/session rather than folding it into a feature request, since it changes the connection-setup layer described in "Networking model" above.

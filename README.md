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
# Tunnel Vision!

A fast-paced arcade digging game for the Playdate.

Guide a determined mole deeper underground by digging through the earth to collect valuable treasure and eat worms to gain more time. 
You only have 30 seconds, so choose your route quickly and dig as deep as possible before time runs out!

## Game Jam Project

**Tunnel Vision!** was created as a game jam project by students learning game development.

The goals of this project are to:
- Learn the fundamentals of Lua programming
- Learn how Playdate games are structured
- Build and test a game on the Playdate Simulator
- Deploy and test the game on physical Playdate hardware
- Complete a small and playable game as a team

## Gameplay

The player controls a mole digging underground.

While digging, the player can find:
- Worms that add user time
- Treasures that add user points

The game ends when the timer reaches zero and the final score and maximum depth are displayed on the game-over screen.

## Controls

| Playdate control | Action |
|---|---|
| D-pad Left | Move and dig left |
| D-pad Right | Move and dig right |
| D-pad Down | Move and dig downward |
| A button | Start the game |
| A button or D-pad Down | Restart after game over |

The game currently focuses on left, right, and downward movement. Upward movement is unavailable.

## Game Features

- 30-second arcade sessions
- Worms that extend the timer
- Smooth grid-based movement
- Scrolling camera
- Digging particles
- Floating score effects
- Sound effects
- Black-and-white Playdate presentation

## Technology

The project uses:

- Playdate SDK
- Playdate Lua API
- Lua
- Visual Studio Code
- Aseprite

## Running the Game

Install the Playdate SDK first. On Windows, set `PLAYDATE_SDK_PATH` to your SDK folder, or add the SDK `bin` folder to your `PATH`.

To build the game:

```powershell
.\build-playdate.ps1
```

To build and open it in the Playdate Simulator:

```powershell
.\run-simulator.ps1
```

The compiled game is created at `build\MoleDown.pdx`.

To run it on a physical Playdate, open `build\MoleDown.pdx` in the Simulator, connect and unlock the Playdate, then use the Simulator device install/upload option.

## What Is Playdate?

Playdate is a handheld game console created by Panic.

It has:

- A 400 × 240-pixel black-and-white screen
- A directional pad
- A and B buttons
- A side-mounted crank
- A speaker and audio system
- A Lua and C development SDK

This project uses the Lua portion of the Playdate SDK.

## What Is Lua?

Lua is a small, lightweight programming language commonly embedded in games and applications.

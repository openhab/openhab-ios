# MCP Server Setup

Claude Code uses four MCP servers in this project. Because `.claude/` is gitignored, each contributor must register them by running the commands below.

For how to use these servers during development, see **[SIMULATOR_VERIFICATION.md](SIMULATOR_VERIFICATION.md)**.

## Overview

| Server | Role |
|--------|------|
| `xcode` | Build, test, read/search source via Xcode |
| `xcbuild` | Alternative xcodebuild integration |
| `ios-simulator` | Simulator lifecycle: list, boot, shutdown |
| `mobile-mcp` | UI interaction: install, launch, tap, screenshot, recording, crashes |

## Prerequisites

- **Xcode** installed (provides `xcrun mcpbridge` for the `xcode` server)
- **Node.js + npm** installed (provides `npx` for `mobile-mcp` and `xcbuild`, and `npm` for `ios-simulator`)

## Installation

### 1. xcode

No package to install — `xcrun mcpbridge` ships with Xcode.

```bash
claude mcp add xcode xcrun mcpbridge
```

### 2. xcbuild

Runs via `npx`; no separate installation needed.

```bash
claude mcp add xcbuild -- npx -y xcodebuildmcp@latest mcp
```

### 3. ios-simulator

Install the npm package globally first, then register it.

```bash
npm install -g mcp-server-ios-simulator
claude mcp add ios-simulator -- node "$(npm root -g)/mcp-server-ios-simulator/dist/index.js"
```

### 4. mobile-mcp

Runs via `npx`; no separate installation needed.

```bash
claude mcp add mobile-mcp -- npx -y @mobilenext/mobile-mcp@latest
```

## Verify

After running all four commands, confirm the servers are connected:

```bash
claude mcp list
```

Expected output (all four should show `✓ Connected`):

```
ios-simulator: node /opt/homebrew/lib/node_modules/mcp-server-ios-simulator/dist/index.js - ✓ Connected
xcbuild: npx -y xcodebuildmcp@latest mcp - ✓ Connected
xcode: xcrun mcpbridge - ✓ Connected
mobile-mcp: npx -y @mobilenext/mobile-mcp@latest - ✓ Connected
```

## Known limitations (iOS 26.5)

The `ios-simulator` server's session-based tools (`install-app`, `launch-app`, `terminate-app`, `tap`) require a `sessionId` that cannot be obtained on iOS 26.5 — those tools are currently inaccessible. Use `mobile-mcp` equivalents instead. See [SIMULATOR_VERIFICATION.md](SIMULATOR_VERIFICATION.md) for the current recommended tool chain.

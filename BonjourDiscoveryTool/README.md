# Bonjour Discovery Tool

A command-line tool for testing openHAB Bonjour/mDNS service discovery on macOS.

This tool uses the same `BonjourService` implementation as the iOS app, making it useful for debugging discovery issues independently from the simulator.

## Building

```bash
cd BonjourDiscoveryTool
swift build
```

The executable will be at `.build/debug/bonjour-discovery`.

## Running

Basic usage (1 cycle, 10 seconds):
```bash
.build/debug/bonjour-discovery
```

Multiple cycles (recommended for multi-homed servers):
```bash
.build/debug/bonjour-discovery -c 3 -d 5
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-c, --cycles N` | Number of discovery cycles | 1 |
| `-d, --duration N` | Duration per cycle in seconds | 10 |
| `-h, --help` | Show help | - |

## Multi-homed Server Discovery

When an openHAB server has multiple network interfaces (e.g., Ethernet and WiFi), mDNS responses may come from different interfaces on different discovery attempts. Running multiple cycles increases the chance of discovering all IP addresses.

Example with a server on 192.168.2.10 (Ethernet) and 192.168.2.212 (WiFi):

```
$ .build/debug/bonjour-discovery -c 2 -d 5

============================================================
  openHAB Bonjour Discovery Tool
============================================================

Starting Bonjour discovery...
   Cycles: 2, Duration per cycle: 5s

   Found 2 server(s) so far...
   Found 4 server(s) so far...

============================================================
Discovery Summary
============================================================

Cross-combined 2 address(es) x 2 endpoint(s) = 4 URL(s):
   http://192.168.2.10:8080
   http://192.168.2.212:8080
   https://192.168.2.10:8443
   https://192.168.2.212:8443

Unique addresses: 192.168.2.10, 192.168.2.212
Unique endpoints: http:8080, https:8443

Local Network Interfaces:
----------------------------------------
   en0: 192.168.2.87
```

## How It Works

1. Searches for `_openhab-server-ssl._tcp.` (HTTPS) and `_openhab-server._tcp.` (HTTP) services
2. Resolves discovered services to get hostnames and addresses
3. Performs DNS lookups on hostnames for additional addresses
4. Cross-combines all discovered addresses with all scheme+port combinations
5. Accumulates results across multiple cycles

## Shared Implementation

The discovery logic is shared with the iOS app via a symlink:

```
Sources/BonjourService.swift -> ../../OpenHABCore/Sources/OpenHABCore/Util/BonjourService.swift
```

Changes to `BonjourService.swift` in OpenHABCore will automatically apply to both the iOS app and this CLI tool.

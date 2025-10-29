# Input Integrity Manager - NixOS Derivation

This directory contains a NixOS derivation for the Input Integrity Manager (formerly LosslessAdapterManager), a tool for managing GameCube controller adapters.

## Overview

The Input Integrity Manager is software designed to manage GameCube controller adapters, providing advanced configuration and monitoring capabilities for competitive gaming.

## Building

### Using nix-build

```bash
NIXPKGS_ALLOW_UNFREE=1 nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
```

The built binary will be available in `./result/bin/input-integrity-manager`.

### Using in NixOS Configuration

Add to your `configuration.nix`:

```nix
{ config, pkgs, ... }:

let
  input-integrity-manager = pkgs.callPackage /path/to/this/directory/default.nix {};
in
{
  nixpkgs.config.allowUnfree = true;  # Required for unfree packages
  
  environment.systemPackages = [
    input-integrity-manager
  ];
}
```

### Using with Nix Flakes

If you prefer using flakes, you can add this to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.input-integrity-manager = 
      nixpkgs.legacyPackages.x86_64-linux.callPackage ./default.nix {};
  };
}
```

## Running

After installation, run the application with:

```bash
input-integrity-manager
```

Note: This application requires a GameCube controller adapter to be connected to function properly. It may also require specific udev rules for USB device access.

## USB Permissions

You may need to add udev rules to allow non-root access to the GameCube adapter:

```nix
# In your configuration.nix
services.udev.extraRules = ''
  # GameCube Controller Adapter
  SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
'';
```

## Files

- `default.nix` - The NixOS derivation file
- `LosslessAdapterManager2_Linux` - The local binary (for reference)
- `ssbm.iso` - Super Smash Bros. Melee ISO (game file)

## Derivation Details

The derivation:
- Downloads the gzipped binary from CloudFront
- Uses `autoPatchelfHook` to automatically fix library dependencies
- Patches in required libraries: `zlib` and `libstdc++`
- Installs the binary as `input-integrity-manager` in `$out/bin`

## License

This package has an unfree license. You must explicitly allow unfree packages to build or install it.

## Troubleshooting

### Build fails with "refusing to evaluate" error
Make sure to set `NIXPKGS_ALLOW_UNFREE=1` or configure `allowUnfree = true` in your nix configuration.

### Application crashes on startup
Ensure you have a GameCube controller adapter connected and proper USB permissions configured.

### Library not found errors
The derivation uses `autoPatchelfHook` which should automatically resolve all dependencies. If you encounter library issues, please file an issue.

## Source

- Download URL: https://dnlo0r667tlsj.cloudfront.net/LosslessAdapterManager2_Linux.gz
- GitHub: https://github.com/Struggleton/LosslessAdapterManager

## Platform Support

This derivation only supports `x86_64-linux` (64-bit Linux) systems.
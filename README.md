# XMCL Nix Flake

Nix flake for [X Minecraft Launcher (XMCL)](https://github.com/Voxelum/x-minecraft-launcher) - A modern, elegant Minecraft launcher.

## Usage

### As a flake input

Add to your `flake.nix`:
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    xmcl-nix = {
      url = "github:v1mkss/xmcl-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { nixpkgs, ... }@inputs: {
    # For NixOS:
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            inputs.xmcl-nix.packages.${system}.default
          ];
        })
      ];
    };
  };
}
```

### Direct installation

Using `nix profile`:
```bash
nix profile install github:v1mkss/xmcl-nix
```

Or run temporarily:
```bash
nix run github:v1mkss/xmcl-nix
```

## Features

- Properly packaged XMCL launcher for Nix/NixOS
- All required dependencies included
- Desktop entry and icons support
- Auto-updates disabled (managed through Nix)
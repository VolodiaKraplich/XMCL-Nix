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
      url = "github:VolodiaKraplich/XMCL-Nix";
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
nix profile install github:VolodiaKraplich/XMCL-Nix
```

Or run temporarily:
```bash
nix run github:VolodiaKraplich/XMCL-Nix
```

## Features

- Properly packaged XMCL launcher for Nix/NixOS
- All required dependencies included
- Desktop entry and icons support
- Auto-updates disabled (managed through Nix)

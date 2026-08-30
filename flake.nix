{
  description = "NixOS configuration for server, desktop and laptop";

  inputs = {
    # Stable release for every host — services only change when we bump this
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # User dotfiles (shared by all hosts)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets, encrypted at rest in secrets/secrets.yaml
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Native authentik (OIDC provider for immich + open-webui)
    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # mismatched nixpkgs breaks its python deps
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, sops-nix, authentik-nix, ... }:
    let
      # Everything every host shares: core system, secrets, and mig's home config
      sharedModules = [
        ./modules/core
        ./modules/secrets
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.mig = import ./home;
        }
      ];
    in {
      nixosConfigurations = {

        # Laptop
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = sharedModules ++ [
            nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen2
            ./modules/desktop-env   # Shared GUI
            ./hosts/laptop
          ];
        };

        # Desktop
        desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = sharedModules ++ [
            ./modules/desktop-env   # Shared GUI
            ./hosts/desktop
          ];
        };

        # Server (headless, no GUI — also the NAS: /raid and /ssd are local disks)
        server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = sharedModules ++ [
            authentik-nix.nixosModules.default
            ./hosts/server
          ];
        };
      };
    };
}

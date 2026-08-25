{
  description = "NixOS Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
};

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs: {
    nixosConfigurations = {
    
      # Laptop
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
        nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen2
        ./modules
        ./modules/desktop-env   # <--- Shared GUI
        ./hosts/laptop
      ];
    };

    # Desktop
    desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./modules/core
        ./modules/desktop-env   # <--- Shared GUI
        ./hosts/desktop
      ];
    };

    # Server (Headless, no GUI)
    server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./modules/core
        ./hosts/server
      ];
    };
  };
};

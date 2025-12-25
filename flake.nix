{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-unstable branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    slippi = {
      url = "github:lytedev/slippi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
    };

    quickshell = {
      url = "github:outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";  # Use same quickshell version
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, zen-browser, slippi, sops-nix, ... }: {
    # Custom packages overlay
    overlays.default = final: prev: {
      input-integrity-lossless = final.callPackage ./my_derivations/input_integrity_lossless/default.nix { };
      cursor-agent-acp-npm = final.callPackage ./my_derivations/cursor_acp_bridge/default.nix {  };
    };

    nixosConfigurations = {
      # Roy configuration
      roy = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };  # Pass inputs to all NixOS modules
        modules = [
          # Import the shared configuration
          ./configuration.nix
          # Import the host-specific configuration
          ./hosts/roy/configuration.nix
          ./noctalia.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.dillon = import ./hosts/roy/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          # Apply custom overlay
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [ self.overlays.default ];
          })
        ];
      };

      # Marth configuration
      marth = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };  # Pass inputs to all NixOS modules
        modules = [
          # Import the shared configuration
          ./configuration.nix
          # Import the host-specific configuration
          ./hosts/marth/configuration.nix
          ./noctalia.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.dillon = import ./hosts/marth/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          # Apply custom overlay
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [ self.overlays.default ];
          })
        ];
      };
    };
  };
}

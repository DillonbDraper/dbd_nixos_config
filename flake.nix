{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-unstable branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-mattermost.url = "github:NixOS/nixpkgs/nixos-unstable";
    expert = {
      url = "github:elixir-lang/expert";
      flake = false;
    };
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

    claude-code = {
    url = "github:sadjow/claude-code-nix" ;
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
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
    };

  };

  outputs = inputs@{ self, nixpkgs, home-manager, zen-browser, niri, slippi, sops-nix, expert, claude-code, ... }:
  let
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        });
    mkExpert = pkgs:
      let
        beamPackages = pkgs.beamMinimal27Packages.overrideScope (_: prev: {
          elixir = prev.elixir_1_17;
        });
      in
      pkgs.callPackage "${expert}/nix/expert.nix" { inherit beamPackages; };
  in {
    # Custom packages overlay
    overlays.default = final: prev: {
      input-integrity-lossless = final.callPackage ./my_derivations/input_integrity_lossless/default.nix { };
      cursor-agent-acp-npm = final.callPackage ./my_derivations/cursor_acp_bridge/default.nix {  };
      devicon-lookup = final.callPackage ./my_derivations/devicon_lookup/default.nix { };
      pi-coding-agent-custom = final.callPackage ./my_derivations/pi_coding_agent/default.nix { };
      droid = final.callPackage ./my_derivations/droid/default.nix { buildFHSEnv = final.buildFHSEnv; };
      simba = final.callPackage ./my_derivations/simba/default.nix { };
      expert-lsp = mkExpert final;
    };



    devShells = forAllSystems ({
      system,
      pkgs,
    }: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          elixir_1_18
          erlang
          (mkExpert pkgs)
        ];
      };
    });

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
          ({ ... }: {
            nixpkgs.overlays = [
              claude-code.overlays.default
              self.overlays.default

            ];
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
          ({ ... }: {
            nixpkgs.overlays = [
              claude-code.overlays.default
              self.overlays.default
            ];
          })
        ];
      };
    };
  };
}

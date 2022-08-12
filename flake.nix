{
  description = "A Tor bandwidth scanner that generates bandwidth files to be used by Directory Authorities.";

  inputs = {
    # Nixpkgs / NixOS version to use.
    nixpkgs.url = "nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    
    # Upstream source tree(s).
    sbws-src = {
      type = "git";
      url = "https://gitlab.torproject.org/tpo/network-health/sbws.git";
      # url = "path:./sbws";
      rev = "6ed14550bab4d60734c126630fb6cfa952207e74";
      flake = false; };
  };

  outputs = { self, nixpkgs, sbws-src, flake-utils }@inputs:
    let
                    
      python = "python39";

      # Generate a user-friendly version numer.
      versions =
        let
          generateVersion = builtins.substring 0 8;
        in
          nixpkgs.lib.genAttrs
            [ "sbws" ]
            (n: generateVersion inputs."${n}-src".lastModifiedDate);

      local_overlay = final: prev: rec {
        sbws = final.python3Packages.buildPythonPackage rec {
          name = "sbws-${versions.sbws}";

          src = sbws-src;

          checkInputs = [ final.python3Packages.pytestCheckHook
                          final.python3Packages.pytest
                          final.python3Packages.pytest-mock ];
          pytestFlagsArray = [ "tests/unit/" ];

          buildInputs =  [
            final.python3Packages.versioneer
            final.python3Packages.freezegun
            final.python3Packages.psutil ];
          propagatedBuildInputs = [
            final.python3Packages.stem
            final.python3Packages.requests ];

          meta = {
            final.lib.homepage = "https://tpo.pages.torproject.net/network-health/sbws/";
            final.lib.description = "A Tor bandwidth scanner that generates bandwidth files to be used by Directory Authorities.";
          };
        };

        default = sbws;
      };

      pkgsForSystem = system: import nixpkgs {
        # if you have additional overlays, you may add them here
        overlays = [
          local_overlay # this should expose devShell
        ];
        inherit system;
      };
    in flake-utils.lib.eachDefaultSystem (system: rec {

      legacyPackages = pkgsForSystem system;
      
      # Provide some binary packages for selected system types.
      packages = flake-utils.lib.flattenTree {
        default = legacyPackages.default;
        sbws = legacyPackages.sbws;
      };

      # Default shell
      devShells.default = legacyPackages.mkShell {
        buildInputs = [
          packages.default
        ];
      };
    }) // {
      overlays = {
        default = final: prev: local_overlay.default;
        all = final: prev: local_overlay.sbws;
      };
      
      nixosModules.sbws = import ./module.nix;
      
      nixosConfigurations.sbws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ({ pkgs, lib, packages, ... }: {
          imports = [ self.nixosModules.sbws ];
          boot.isContainer = true;

          networking.useDHCP = false;
          networking.hostName = "sbws";
          time.timeZone = "Etc/UTC";
          system.stateVersion = "22.05";

          users.users.user = {
            isNormalUser  = true;
            home  = "/home/user";
            description  = "Test user";
            extraGroups  = [ "wheel" ];
            password = "12345";
          };

          environment.systemPackages = [ self.packages.x86_64-linux.sbws ];
          nixpkgs.overlays = [ local_overlay ];
          
          services.sbws = {
            enable = true;
            general = {
              data_period = 12;
              reset_bw_ipv4_changes = true;
            };
            relayprioritizer = {
              measure_authorities = false;
            };
            destinations = {
              server1 = {
                country = "BE";
                enable = true;
                url = "https://nixos.org/manual/nix/stable/expressions/language-constructs.html";
              };
              server2 = {
                country = "BE";
                enable = true;
                url = "https://nixos.org/manual/nixpkgs/stable";
              };
            };
            scanner = {
              country = "BE";
              nickname = "scanny";
            };
            logging = {
              level="debug";
            };
          };
        })];
      };
    };
}

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
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
				inherit system;
			};
                    
      python = "python39";

      # Generate a user-friendly version numer.
      versions =
        let
          generateVersion = builtins.substring 0 8;
        in
          nixpkgs.lib.genAttrs
            [ "sbws" ]
            (n: generateVersion inputs."${n}-src".lastModifiedDate);
      # sbws-version = "v1.5.2";

      sbws = pkgs.python3Packages.buildPythonPackage rec {
        name = "sbws-${versions.sbws}";

        src = sbws-src;

        # checkInputs = [ pkgs.python3Packages.pytestCheckHook
        #                 pkgs.python3Packages.tox 
        #                 pkgs.python3Packages.pytest
        #                 pkgs.python3Packages.black
        #                 pkgs.python3Packages.isort
        #                 pkgs.python3Packages.flake8
        #                 pkgs.python3Packages.flake8-docstrings
        #                 pkgs.python3Packages.codespell
        #                 pkgs.python3Packages.coverage
        #                 pkgs.python3Packages.stats
        #                 pkgs.python3Packages.bandit
        #                 pkgs.python3Packages.doclinks
        #                 pkgs.python3Packages.bandit];
        # checkPhase =
        #        ''
        #        tox
        #        '';
        checkInputs = [ pkgs.python3Packages.pytestCheckHook
                        pkgs.python3Packages.pytest
                        pkgs.python3Packages.pytest-mock ];
        pytestFlagsArray = [ "tests/unit/" ];

        buildInputs =  [
          pkgs.python3Packages.versioneer
          pkgs.python3Packages.freezegun
          pkgs.python3Packages.psutil ];
        propagatedBuildInputs = [
          pkgs.python3Packages.stem
          pkgs.python3Packages.requests ];

        meta = {
          pkgs.lib.homepage = "https://tpo.pages.torproject.net/network-health/sbws/";
          pkgs.lib.description = "A Tor bandwidth scanner that generates bandwidth files to be used by Directory Authorities.";
        };
      };
    in
    {

      # Provide some binary packages for selected system types.
      packages = flake-utils.lib.flattenTree {
        default = sbws;
        sbws = sbws;
      };

      # Default shell
      devShells.default = pkgs.mkShell {
        buildInputs = [
          sbws
        ];
        # (pkgs.python39.withPackages (p: with p; [ chipwhisperer ]))
      };

    }) // {
      overlays = {
        default = final: prev: {
          inherit (self.packages) sbws;
        };
        all = final: prev: {
          inherit (self.packages) sbws;
        };
      };
    };
}

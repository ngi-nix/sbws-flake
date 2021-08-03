{
  description = "A Tor bandwidth scanner that generates bandwidth files to be used by Directory Authorities.";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  # Upstream source tree(s).
  inputs.sbws-src = { url = "https://gitlab.torproject.org/tpo/network-health/sbws/-/archive/v1.2.0/sbws-v1.2.0.tar.gz"; flake = false; };

  outputs = { self, nixpkgs, sbws-src }:
    let
      version = "v1.2.0";

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        sbws = with final.python3Packages; buildPythonApplication rec {
          name = "sbws-${version}";

          src = sbws-src;

          checkInputs = [ pytestCheckHook ];
          pytestFlagsArray = [ "tests/unit/" ];

          buildInputs =  [ versioneer freezegun ];
          propagatedBuildInputs = [ stem requests ];

          meta = {
            homepage = "https://tpo.pages.torproject.net/network-health/sbws/";
            description = "A Tor bandwidth scanner that generates bandwidth files to be used by Directory Authorities.";
          };
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) sbws;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.sbws);

    };
}

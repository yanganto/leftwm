{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, fenix, flake-utils, naersk, nixpkgs }:
    (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        deps = with pkgs; [
          xorg.libX11
          xorg.libXinerama
        ];

        devToolchain = fenix.packages.${system}.stable;

        leftwm = ((naersk.lib.${system}.override {
          inherit (fenix.packages.${system}.minimal) cargo rustc;
        }).buildPackage {
          name = "leftwm";
          src = ./.;
          buildInputs = deps;
          postFixup = ''
            for p in $out/bin/left*; do
              patchelf --set-rpath "${pkgs.lib.makeLibraryPath deps}" $p
            done
          '';

          GIT_HASH = self.shortRev or "dirty";
        });
      in
      rec {
        # `nix build`
        packages = {
          inherit leftwm;
          default = leftwm;
        };

        # `nix run`
        apps = {
          leftwm = flake-utils.lib.mkApp {
            drv = packages.leftwm;
          };
          default = apps.leftwm;
        };

        # `nix develop`
        devShells.default = pkgs.mkShell
          {
            buildInputs = deps ++ [ pkgs.pkg-config pkgs.systemd ];
            nativeBuildInputs = with pkgs; [
              gnumake
              (devToolchain.withComponents [
                "cargo"
                "clippy"
                "rust-src"
                "rustc"
                "rustfmt"
              ])
              fenix.packages.${system}.rust-analyzer
            ];
          };
      })) // {
      overlay = final: prev: {
        leftwm = self.packages.${final.system}.leftwm;
      };
    };
}

{
  description = "Matrix - An Axtremely customizable shell by Axenide";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    axctl = {
      url = "github:Axenide/axctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, axctl, ... }:
    let
      matrixLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.matrix.enable = lib.mkDefault true;
        programs.matrix.package = lib.mkDefault self.packages.${pkgs.system}.default;
      };

      packages = matrixLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          Matrix = import ./nix/packages {
            inherit pkgs lib self system axctl version;
          };
        in {
          default = Matrix;
          Matrix = Matrix;
        }
      );

      devShells = matrixLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          Matrix = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ Matrix ];
            shellHook = ''
              export QML2_IMPORT_PATH="${Matrix}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "Matrix dev environment loaded."
            '';
          };
        }
      );

      apps = matrixLib.forAllSystems (system:
        let
          Matrix = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${Matrix}/bin/matrix";
          };
        }
      );
    };
}

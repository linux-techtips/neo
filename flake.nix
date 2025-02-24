{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig = {
      url = "github:FalsePattern/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, zig, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkg = import nixpkgs { inherit system; };
      zig-unstable = zig.packages.${system}.master;

    in with pkg; {
      devShells.default = mkShell {
        packages = [ zig-unstable hyperfine wasmtime wabt bun ];
      };
    }
  );
}

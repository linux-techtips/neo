{
  inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem
    (system: 
      let 
        pkgs = import nixpkgs { inherit system; };
        buildInputs = with pkgs; [ gcc14 mold ];

      in with pkgs; {
      
        devShells.default = mkShell.override { stdenv = gcc14Stdenv; } {
          name = "Neo";

          packages = buildInputs;

          # INCLUDE_PATH = "${gcc14Stdenv.cc.cc}/include/c++/14.1.0/";
          LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath [ gcc14Stdenv.cc.cc.lib ];
        };

        packages.default = stdenv.mkDerivation {
          name = "neo";
        
          src = lib.sourceByRegex ./. [
            "Makefile"
            "^src.*"
            "^lib.*"
          ];
          
          nativeBuildInputs = buildInputs ++ [ gcc14.libc.static ];

          buildPhase = ''
            make release
          '';
        
          installPhase = ''
            mkdir -p $out/bin
            cp neo $out/bin
          '';
        
          doCheck = true;
      };
    });
}

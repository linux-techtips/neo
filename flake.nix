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
            mkdir -p build
            make nix 
          '';
        
          installPhase = ''
            mkdir -p $out/bin
            cp build/neo $out/bin
          '';
        
          doCheck = true;
      };
  
      packages.profile = stdenv.mkDerivation {
        name = "neo";
        
        src = lib.sourceByRegex ./. [
          "Makefile"
          "^src.*"
          "^lib.*"
        ];
          
        nativeBuildInputs = buildInputs ++ [ gcc14.libc.static ];

        buildPhase = ''
          mkdir -p build
          make profile 
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp build/neo $out/bin  
        '';
        
        doCheck = false;
      };
    });
}

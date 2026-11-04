{
  description = "RGB colour for worn parts on the stock NWN:EE client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # The NWScript compiler and file tools, from neverwinter.nim's release.
      # The compiler opens sqlite at run time, so it goes on the library path.
      neverwinter = pkgs.stdenv.mkDerivation rec {
        pname = "neverwinter-nim";
        version = "2.3.2";
        src = pkgs.fetchurl {
          url = "https://github.com/niv/neverwinter.nim/releases/download/${version}/neverwinter-x86_64-linux-gnu.zip";
          hash = "sha256-9siW8oITFazHDS3/0rj4bxeqT8KlSUEoZMHqs3qtyxk=";
        };
        nativeBuildInputs = [ pkgs.unzip pkgs.autoPatchelfHook pkgs.makeWrapper ];
        sourceRoot = ".";
        installPhase = ''
          mkdir -p $out/bin $out/lib
          cp libnwnscriptcomp.so $out/lib/
          for f in nwn_*; do
            install -m755 "$f" $out/bin/
            wrapProgram $out/bin/$f --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.sqlite ]}
          done
        '';
      };
    in
    {
      packages.${system}.neverwinter = neverwinter;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (pkgs.python3.withPackages (ps: [ ps.pillow ps.numpy ]))
          pkgs.just
          neverwinter
        ];
      };
    };
}

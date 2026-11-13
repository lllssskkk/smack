{
  description = "SMACK 2.10.0: translate C (via LLVM) to Boogie, and verify it";

  inputs = {
    # Z3, cvc5 and Python come from here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # SMACK 2.10.0 is built against LLVM 14, which nixpkgs dropped after 25.05
    nixpkgs-llvm14.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    # Boogie 2.15.7, the version SMACK 2.10.0 is tested with (see its bin/versions)
    boogie.url = "github:lllssskkk/boogie";
    boogie.inputs.nixpkgs.follows = "nixpkgs";
    boogie.inputs.flake-utils.follows = "flake-utils";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-llvm14,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        old = import nixpkgs-llvm14 { inherit system; };
        llvm = old.llvmPackages_14;

        python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

        # The smack script calls its LLVM tools with a version suffix (clang-14,
        # llvm-link-14, ...). The compilers are small exec scripts rather than
        # symlinks, so the Nix compiler wrapper still sees itself as clang / clang++.
        llvmTools = pkgs.runCommand "smack-llvm14-tools" { } ''
          mkdir -p $out/bin
          for t in clang clang++; do
            printf '#!${pkgs.runtimeShell}\nexec ${llvm.clang}/bin/%s "$@"\n' "$t" > $out/bin/$t-14
            chmod +x $out/bin/$t-14
          done
          for t in llvm-as llvm-dis llvm-link; do
            ln -s ${llvm.llvm}/bin/$t $out/bin/$t-14
          done
        '';

        boogie = inputs.boogie.packages.${system}.default;

        smack = old.stdenv.mkDerivation {
          pname = "smack";
          version = "2.10.0";

          src = pkgs.fetchFromGitHub {
            owner = "smackers";
            repo = "smack";
            rev = "v2.10.0";
            fetchSubmodules = true; # sea-dsa, SMACK's memory-region analysis
            hash = "sha256-rZHjDRF1U73hmku+1fLJZG0mWs9/D25KwkNEQ2CRpP0=";
          };

          # Corral, SMACK's default verifier, is not packaged, so Boogie becomes the default
          postPatch = ''
            substituteInPlace share/smack/top.py \
              --replace-fail "default='corral'" "default='boogie'"
          '';

          nativeBuildInputs = [
            old.cmake
            llvm.llvm.dev # llvm-config and LLVM's CMake package
            pkgs.makeWrapper
          ];
          buildInputs = [
            llvm.llvm
            old.boost # headers used by sea-dsa
            python # the shebang of bin/smack is patched to this interpreter
          ];

          # put llvm2bpl, the LLVM 14 tools and the verifiers on the PATH of bin/smack
          postFixup = ''
            wrapProgram $out/bin/smack \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  (placeholder "out")
                  llvmTools
                  boogie
                  pkgs.z3
                  pkgs.cvc5
                ]
              }
          '';

          meta = {
            description = "A bounded software verifier: C to LLVM IR to Boogie";
            homepage = "https://github.com/smackers/smack";
            license = pkgs.lib.licenses.mit;
            mainProgram = "smack";
          };
        };
      in
      {
        packages.default = smack;
        packages.smack = smack;
        packages.boogie = boogie;

        devShells.default = pkgs.mkShell {
          packages = [
            smack
            boogie
            pkgs.z3
            pkgs.cvc5
          ];
        };
      }
    );
}

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

        # A compiler for smack to call. It keeps the settings of the shell smack runs in,
        # such as include paths, but turns off Nix's hardening flags: smack compiles to
        # LLVM IR for analysis, not to run, and at -O0 _FORTIFY_SOURCE only causes warnings.
        # It execs the Nix compiler wrapper by its own name, so the wrapper still sees
        # itself as clang / clang++.
        compiler =
          name:
          pkgs.writeShellScript "${name}-14" ''
            unset ''${!NIX_HARDENING_ENABLE@}
            exec ${llvm.clang}/bin/${name} "$@"
          '';

        # The smack script calls its LLVM tools with a version suffix (clang-14,
        # llvm-link-14, ...)
        llvmTools = pkgs.runCommand "smack-llvm14-tools" { } ''
          mkdir -p $out/bin
          ln -s ${compiler "clang"} $out/bin/clang-14
          ln -s ${compiler "clang++"} $out/bin/clang++-14
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

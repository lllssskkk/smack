# SMACK 2.10.0 for Nix

A Nix flake for [SMACK](https://github.com/smackers/smack) 2.10.0, which translates C to Boogie (C → clang → LLVM IR → `llvm2bpl` → Boogie) and can verify the result.

## Use

    nix run github:lllssskkk/smack -- --version
    nix shell github:lllssskkk/smack       # puts `smack` on the PATH

In a clone:

    nix develop                 # a shell with smack, boogie 2.15.7, z3 and cvc5
    nix build                   # ./result/bin/smack
    nix build .#boogie          # Boogie 2.15.7 on its own

Translate only, and keep the Boogie program:

    smack -t -bpl out.bpl file.c

Translate and verify (bounded: loops unrolled 6 times):

    smack --check memory-safety --unroll 6 examples/array_sum.c       # no errors
    smack --check memory-safety --unroll 6 examples/array_sum_bug.c   # invalid pointer dereference
    smack --solver cvc5 --check memory-safety --unroll 6 examples/array_sum.c

## How it is packaged

- **Two nixpkgs inputs.** SMACK 2.10.0 is built against LLVM 14, which nixpkgs dropped after 25.05, so `nixpkgs-llvm14` (nixos-25.05) provides the toolchain. Z3, cvc5 and Python come from `nixpkgs` (nixos-26.05).
- **Version-suffixed LLVM tools.** The `smack` script calls `clang-14`, `clang++-14`, `llvm-as-14`, `llvm-dis-14` and `llvm-link-14`; the flake provides these names.
- **Boogie 2.15.7, the version SMACK is tested with.** It comes from [lllssskkk/boogie](https://github.com/lllssskkk/boogie), which packages the prebuilt Boogie 2.15.7 from NuGet and runs it on .NET 10 with `DOTNET_ROLL_FORWARD=Major`, the same setting SMACK's own build script uses. SMACK's Boogie command line is unchanged.
- **Boogie is the default verifier.** SMACK's default, Corral, is not packaged, so `--verifier` defaults to `boogie`. Other verifiers (Corral, Symbooglix) are not available.

## Known caveats

- nixpkgs' own `boogie` is version 3, which does not accept SMACK's command-line options; use the 2.15.7 provided here. The two versions also generate different VCs from the same program.
- `smack --debug` fails: it passes `-debug` to `llvm2bpl`, which a release build of LLVM does not accept.
- SMACK's memory model returns an arbitrary pointer for `malloc(0)`, which its `free` then rejects ("invalid memory deallocation"). A program that may call `malloc(0)` and later `free` the result is reported as an error; the examples assume `n >= 1`.

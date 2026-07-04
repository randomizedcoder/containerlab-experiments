# treefmt configuration -> `nix fmt`. The treefmt-nix flake module also exposes
# a `formatting` check that `nix flake check` picks up automatically.
_: {
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true; # *.nix (nixfmt-rfc-style)
      programs.prettier.enable = true; # *.md, *.json, *.yml
    };
  };
}

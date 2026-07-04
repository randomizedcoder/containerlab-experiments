# Static checks (no Docker required). `nix flake check` builds the rendered lab
# for each example, which fails if any example's constants/topology/configs do
# not evaluate and render cleanly. The treefmt flake module contributes its own
# formatting check on top of these.
_: {
  perSystem =
    { pkgs, ... }:
    let
      lib = pkgs.lib;
      topos = import ./topologies.nix pkgs;
    in
    {
      checks = lib.listToAttrs (
        map (t: {
          name = "render-${t.name}";
          value = t.lab;
        }) topos
      );
    };
}

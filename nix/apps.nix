# Per-topology apps: <name>-up / -down / -inspect / -gen, plus a <name>-lab
# package that is the rendered lab directory in the store.
#
# The apps wrap `containerlab` and deploy from the rendered store path, so the
# YAML/configs are always in sync with constants.nix. containerlab writes its
# runtime state (clab-<name>/) into the current working directory.
_: {
  perSystem =
    { pkgs, ... }:
    let
      lib = pkgs.lib;
      topos = import ./topologies.nix pkgs;
      clab = "${pkgs.containerlab}/bin/containerlab";

      mkApps =
        t:
        let
          topoPath = "${t.lab}/${t.name}.clab.yml";

          # The topology lives in the read-only Nix store, so point containerlab
          # at the working directory for its runtime lab dir (clab-<name>/).
          labdirBase = ''export CLAB_LABDIR_BASE="''${CLAB_LABDIR_BASE:-$PWD}"'';

          up = pkgs.writeShellApplication {
            name = "${t.name}-up";
            text = ''
              ${labdirBase}
              echo "Deploying ${t.name} from ${topoPath}"
              echo "Runtime state -> $CLAB_LABDIR_BASE/clab-${t.name}"
              exec ${clab} deploy --reconfigure --topo "${topoPath}" "$@"
            '';
          };
          down = pkgs.writeShellApplication {
            name = "${t.name}-down";
            text = ''
              ${labdirBase}
              exec ${clab} destroy --cleanup --topo "${topoPath}" "$@"
            '';
          };
          inspect = pkgs.writeShellApplication {
            name = "${t.name}-inspect";
            text = ''
              ${labdirBase}
              exec ${clab} inspect --topo "${topoPath}" "$@"
            '';
          };
          gen = pkgs.writeShellApplication {
            name = "${t.name}-gen";
            text = ''
              dest="''${1:-./${t.name}-lab}"
              rm -rf "$dest"
              cp -rL "${t.lab}" "$dest"
              chmod -R u+w "$dest"
              echo "Rendered lab written to $dest"
            '';
          };
          app = drv: {
            type = "app";
            program = "${drv}/bin/${drv.name}";
          };
        in
        {
          "${t.name}-up" = app up;
          "${t.name}-down" = app down;
          "${t.name}-inspect" = app inspect;
          "${t.name}-gen" = app gen;
        };
    in
    {
      apps = lib.foldl' (acc: t: acc // mkApps t) { } topos;
      packages = lib.listToAttrs (
        map (t: {
          name = "${t.name}-lab";
          value = t.lab;
        }) topos
      );
    };
}

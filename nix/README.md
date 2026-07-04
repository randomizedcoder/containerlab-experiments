# `nix/` — flake internals

This directory holds the [flake-parts](https://flake.parts) modules that make up
the flake. The top-level [`../flake.nix`](../flake.nix) is deliberately tiny: it
declares inputs and hands off to `flake-parts.lib.mkFlake`, importing the modules
here.

```nix
# flake.nix (abridged)
flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" "aarch64-linux" ];
  imports = [
    inputs.treefmt-nix.flakeModule
    ./nix/formatter.nix
    ./nix/devshell.nix
    ./nix/apps.nix
    ./nix/checks.nix
  ];
};
```

## Inputs

| Input         | Purpose                                                                          |
| ------------- | -------------------------------------------------------------------------------- |
| `nixpkgs`     | package set (tracks `nixos-unstable`); provides `containerlab`, formatters, etc. |
| `flake-parts` | modular flake framework; keeps `flake.nix` small                                 |
| `treefmt-nix` | wires up `nix fmt` and a formatting check via its `flakeModule`                  |

## Data flow

```
topologies/<name>/constants.nix ─┐
                                 ├─ topology.nix constants ─┐
                                 └─ configs.nix   constants ─┤
                                                            ▼
                                    nix/render.nix  (renderLab)
                                                            ▼
                                    <name>-lab  (lab dir in the Nix store:
                                                 <name>.clab.yml + configs/*.cfg)
                                        │
              ┌─────────────────────────┼──────────────────────────┐
              ▼                         ▼                          ▼
        apps.nix (up/down/…)      checks.nix (render check)   packages.<name>-lab
```

`constants.nix` is the single source of truth for each example. Nothing below it
re-types an address, SID, or ASN.

## Modules

| File                                 | Kind                                            | What it does                                                                                                                                                                                               |
| ------------------------------------ | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`render.nix`](./render.nix)         | helper (`pkgs: {name, topology, configs}: drv`) | Writes `configs/<node>.cfg` from the `configs` attrset and `<name>.clab.yml` from `builtins.toJSON topology` (JSON is valid YAML, so no YAML generator is needed) into one self-contained store dir.       |
| [`topologies.nix`](./topologies.nix) | helper (`pkgs: [ {name; lab;} ]`)               | Single source of truth for the example list. For each dir it imports `constants.nix`, feeds it to `topology.nix`/`configs.nix`, and calls `renderLab`. `apps.nix` and `checks.nix` both consume this list. |
| [`apps.nix`](./apps.nix)             | flake-parts module (`perSystem`)                | Generates `<name>-up/-down/-inspect/-gen` apps wrapping `containerlab`, plus `packages.<name>-lab`. Sets `CLAB_LABDIR_BASE=$PWD` so runtime state is written to the working dir, not the read-only store.  |
| [`checks.nix`](./checks.nix)         | flake-parts module (`perSystem`)                | Adds `checks.render-<name>` = the lab derivation, so `nix flake check` fails if any example fails to render. Fully offline (no Docker).                                                                    |
| [`formatter.nix`](./formatter.nix)   | flake-parts module (`perSystem`)                | Configures treefmt (`nixfmt` for `*.nix`, `prettier` for `*.md`/`*.json`). Powers `nix fmt`; treefmt-nix also contributes a formatting check.                                                              |
| [`devshell.nix`](./devshell.nix)     | flake-parts module (`perSystem`)                | `devShells.default` with `containerlab`, `docker-client`, `yq-go`, `yamllint`, and the treefmt wrapper.                                                                                                    |

## Common commands

```bash
nix fmt                        # format the tree
nix flake check                # formatting + render-build every lab (offline)
nix flake show                 # list apps / packages / devShell / formatter
nix build .#<name>-lab         # materialize a rendered lab in ./result
nix run  .#<name>-up           # deploy (needs Docker + a licensed NOS image; sudo)
```

## Adding an example

1. Create `topologies/<name>/` with `constants.nix`, `topology.nix`, and
   `configs.nix` (see the existing examples).
2. Append the directory to the list in [`topologies.nix`](./topologies.nix).

The apps, `-lab` package, and render check are generated automatically from that
list — no other wiring required.

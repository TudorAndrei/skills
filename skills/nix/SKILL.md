---
name: nix
description: Nix, NixOS and ecosystem guidance - Nix language, nix CLI workflow, dev shells, devenv, Nixpkgs packaging and overlays, NixOS rebuilds and rollback, Home Manager, nix-darwin, microvm.nix, the NixOS Wiki, and running AI coding agents on NixOS. Use for any task that touches .nix files, flakes, nixos-rebuild, darwin-rebuild, home-manager, devenv or the Nix store.
---

# Nix

Each area below is a self-contained guide copied from
[olafkfreund/nix-skills](https://github.com/olafkfreund/nix-skills). Pick the
guide that fits the task, then read it before you advise or edit. Read more than
one guide when the task crosses areas (for example, a Home Manager module that
packages software).

| Task                                                                                            | Guide                                                          |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Nix commands, finding packages and files, dev shells, build errors, `nix.conf`, ecosystem tools | [nix-workflow](references/nix-workflow/guide.md)               |
| Nix language syntax, scope, laziness, strings, derivations, built-ins                           | [nix-language](references/nix-language/guide.md)               |
| Packaging, build helpers, overrides, overlays, `lib` APIs                                       | [nixpkgs-development](references/nixpkgs-development/guide.md) |
| devenv projects: `devenv.nix`, `devenv.yaml`, languages, services, tasks                        | [devenv-project](references/devenv-project/guide.md)           |
| NixOS rebuild modes, generations, rollback, upgrades, store cleaning, boot, services            | [nixos-operations](references/nixos-operations/guide.md)       |
| NixOS Wiki guidance for configuration and troubleshooting                                       | [nixos-wiki](references/nixos-wiki/guide.md)                   |
| Home Manager on NixOS, nix-darwin or standalone                                                 | [home-manager](references/home-manager/guide.md)               |
| nix-darwin macOS systems and `darwin-rebuild`                                                   | [nix-darwin](references/nix-darwin/guide.md)                   |
| Declarative microVMs with microvm.nix                                                           | [microvm-nix](references/microvm-nix/guide.md)                 |
| Installing and sandboxing AI coding agents on NixOS                                             | [nixos-coding-agents](references/nixos-coding-agents/guide.md) |

## Reading the guides

- Links inside a guide are relative to that guide's folder.
- When a guide names another skill (for example `nixpkgs-development`), read
  `references/<that-name>/guide.md` in this skill.
- The nixos-wiki guide runs `python3 scripts/wiki.py`. Run it from
  `references/nixos-wiki/`, or pass the full path to the script.

Provenance and licences: [references/UPSTREAM.md](references/UPSTREAM.md).

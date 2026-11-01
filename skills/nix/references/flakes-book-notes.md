# Flakes and modules: field notes

Practical points that the other guides in this skill do not cover. They are
written in our own words from the
[NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) by Ryan Yin
(CC BY-SA 4.0, read at commit `d15250a`, written for NixOS 26.05). Each section
links the book page for the full explanation. Check option names against the
user's pinned Nixpkgs before you use them.

## Flakes see only Git-tracked files

In a Git repository, a flake copies only tracked files into the store. An error
that a file "does not exist", for a file that is on disk, usually means that the
file is not added to Git. Tell the user to `git add` it (staging is enough; a
commit is not necessary). Do not move the file or change the import path.

## Module priorities and order

Definitions of one option merge by priority. A lower number wins.

| Function              | Priority                        |
| --------------------- | ------------------------------- |
| `lib.mkForce`         | 50                              |
| plain definition      | 100                             |
| `lib.mkDefault`       | 1000                            |
| `lib.mkOptionDefault` | 1500 (the option's own default) |

`lib.mkOverride N value` sets any priority. Use `mkDefault` in shared modules
so that hosts can set the value without `mkForce`. Use `mkForce` only when two
modules conflict and you cannot change the other module.

For list and string options, `lib.mkBefore` and `lib.mkAfter` put a definition
at the start or the end of the merged value. `lib.mkOrder N` gives a precise
position (`mkBefore` is 500, the default is 1000, `mkAfter` is 1500).

Book: [Modularize the configuration](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/modularize-the-configuration).

## Conditional imports

`imports` is a module-system keyword, not an option. You cannot put it inside
`config`, `mkIf` or any value that depends on `config`. The error is
`The option 'imports' does not exist`, or infinite recursion.

Two correct methods:

1. Give the module an `enable` option and wrap its settings in
   `config = lib.mkIf cfg.enable { ... }`. NixOS modules use this method.
2. Select files with a value that does not depend on `config`:
   `imports = lib.optionals isDesktop [ ./desktop.nix ];`, where `isDesktop`
   comes from `specialArgs` or from the flake.

Book: [Module system](https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/module-system).

## Multiple nixpkgs instances

To use packages from a second channel (for example `nixpkgs-unstable`), make
the instance once in `flake.nix` and pass it to modules with `specialArgs`
(or `extraSpecialArgs` for Home Manager):

```nix
specialArgs.pkgs-unstable = import nixpkgs-unstable {
  inherit system;
  config.allowUnfree = true;
};
```

Do not write `import nixpkgs { ... }` inside modules or sub-flakes. Each
`import` evaluates a new nixpkgs instance, so evaluation becomes slower and
uses more memory as the configuration grows.

Book: [Multiple nixpkgs](https://nixos-and-flakes.thiscute.world/nixpkgs/multiple-nixpkgs).

## Building for another architecture

There are two methods. Choose by cache and speed:

| Method            | How                                                                                                                                                                   | Binary cache                                   | Speed        |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | ------------ |
| Cross compilation | `pkgsCross.<platform>.hello`, or set the system's host platform (`nixpkgs.hostPlatform` with `nixpkgs.buildPlatform`; older configurations use `nixpkgs.crossSystem`) | Not used: almost everything builds from source | Native speed |
| Emulation         | On the build machine: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`, then build for that `system`                                                              | Used                                           | Slow (QEMU)  |

Do not mix both methods in one closure without a reason: the same package can
build twice, once per method. `nix repl -f '<nixpkgs>'` and `pkgsCross.<TAB>`
list the cross platforms.

Book: [Cross-platform compilation](https://nixos-and-flakes.thiscute.world/development/cross-platform-compilation).

## Remote deployment

- `nixos-rebuild switch --flake .#host --target-host user@host` builds locally
  and activates on the remote host. Add `--build-host` to build elsewhere.
  `--sudo` (older releases: `--use-remote-sudo`) runs activation with sudo.
  Check `nixos-rebuild --help` on the user's release for the exact flag.
- For many hosts, [colmena](https://github.com/nix-community/colmena) and
  [deploy-rs](https://github.com/serokell/deploy-rs) deploy in parallel.
  Check each project's status before you recommend it.
- The remote user must activate without a password prompt: deploy as root
  through SSH keys, or allow passwordless sudo. Passwordless sudo
  (`security.sudo.wheelNeedsPassword = false`) lets any program of that user
  get root. Tell the user about this risk and do not set it without approval.
- Remote deployment helps most when the target is slow or has no binary cache
  (for example riscv64 boards): build on a strong machine, then copy.

Book: [Remote deployment](https://nixos-and-flakes.thiscute.world/best-practices/remote-deployment).

## Distributed builds: limits

With `nix.distributedBuilds` and `nix.buildMachines`:

- You cannot select a builder per build; Nix selects from the list.
- Nix prefers remote builders to the local machine, even when the local
  machine is faster.
- The unit of work is one derivation. One large derivation keeps one builder
  busy while the others wait.

Book: [Distributed building](https://nixos-and-flakes.thiscute.world/development/distributed-building).

## Substituters: replace or append

- `substituters` and `trusted-public-keys` replace the list from a lower
  level. `extra-substituters` and `extra-trusted-public-keys` append to it.
  In a flake's `nixConfig`, use the `extra-` forms.
- `nixConfig` in a flake has an effect only for users in
  `nix.settings.trusted-users`. A trusted user can make the daemon trust any
  cache, so it is almost equal to root. Do not add users to `trusted-users`
  without the user's approval.

Book: [Add binary cache servers](https://nixos-and-flakes.thiscute.world/nix-store/add-binary-cache-servers).

## A self-hosted binary cache

A minimal S3-compatible cache (for example MinIO):

```sh
nix key generate-secret --key-name cache.example-1 > secret.key
nix key convert-secret-to-public < secret.key > public.key
nix copy --to 's3://nix-cache?endpoint=s3.example&profile=nixbuilder' /run/current-system
```

Sign paths with the secret key (`secret-key-files` in `nix.conf`, or
`nix store sign`). Clients add the cache URL and `public.key` as a substituter
and trusted key. Keep the secret key out of the repository and out of the store.
Add an object-expiry rule on the bucket so that the cache does not grow without
limit.

Book: [Host your own binary cache](https://nixos-and-flakes.thiscute.world/nix-store/host-your-own-binary-cache-server).

## Proxy for downloads

The daemon (`nix-daemon`) downloads the files, not the user's shell. Because of
this, `export HTTPS_PROXY=...` in a shell has no effect on multi-user installs.
For a temporary proxy, write a systemd drop-in in `/run` (it disappears at
reboot), then restart the daemon:

```sh
sudo mkdir -p /run/systemd/system/nix-daemon.service.d/
printf '[Service]\nEnvironment="https_proxy=socks5h://localhost:7891"\n' \
  | sudo tee /run/systemd/system/nix-daemon.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart nix-daemon
```

Do not set a permanent proxy in `systemd.services.nix-daemon.environment`
unless the user asks for it. If the proxy stops, most Nix commands fail,
including the rebuild that would remove the proxy.

Book: same page as substituters, section "proxy server".

## Debugging a configuration in `nix repl`

```text
nix repl
nix-repl> :lf .                     # load the flake in the current directory
nix-repl> outputs.nixosConfigurations.<host>.config.services.<name>.enable
nix-repl> :e pkgs.hello             # open the source in $EDITOR
```

This shows the final merged value of any option, which is faster than a
rebuild. Use `--show-trace -L -v` with `nixos-rebuild` for full errors.

Book: [Debugging](https://nixos-and-flakes.thiscute.world/best-practices/debugging).

## "collision between ..." in a profile

Two packages in the same profile (`environment.systemPackages` or
`home.packages`) ship the same file path. For example, `lldb` and a
`python3.withPackages` environment both contain `six.py`. Fixes, in order of
preference:

1. Put the two packages in different profiles (one in system packages, one in
   Home Manager).
2. Override one package to use the same dependency as the other, for example
   `lldb.override { python3 = customPython; }` (this rebuilds `lldb`).
3. Give one package priority with `lib.hiPrio` or `lib.lowPrio`, if the
   colliding files are the same in practice.

Book: [FAQ](https://nixos-and-flakes.thiscute.world/faq/).

## Home Manager packages and root

Home Manager installs packages in the user's profile. After `sudo su` or a
root login, they are not in `PATH`. On NixOS, `sudo cmd` still finds them,
because NixOS's sudo looks up the command in the caller's `PATH`; other
distributions can reset `PATH`. Put tools that root needs in
`environment.systemPackages`.

Book: [Start using Home Manager](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/start-using-home-manager).

## Binaries downloaded from the internet

NixOS has no FHS layout, so most prebuilt Linux binaries do not start. Options:

- `programs.nix-ld.enable` for binaries that need only a dynamic loader and
  common libraries.
- A `buildFHSEnv` wrapper (for example an `fhs` command in system packages)
  that gives a shell with `/usr/bin` and `/lib`.
- [nix-alien](https://github.com/thiagokokada/nix-alien) to find and supply
  missing libraries.
- Package the binary properly with `autoPatchelfHook` when the user needs it
  long term (see `nixpkgs-development`).

Book: [Run downloaded binaries](https://nixos-and-flakes.thiscute.world/best-practices/run-downloaded-binaries-on-nixos).

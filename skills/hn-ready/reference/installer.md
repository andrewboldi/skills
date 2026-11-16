# The one-command installer

One pasted line installs everything, dependencies included, and works out of the box on every
platform the README claims. Worked example: `~/tmux-restore/install.sh`.

## Shape

- The command works on a fresh machine that has only a shell and curl. If the tool needs a
  toolchain (uv, node, cargo), the script installs that first. A one-liner that assumes the
  toolchain is already there (`uv tool install …`, `npm i -g …`, `cargo install …`) is a
  "requires X" list in disguise.
- Run it with `curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash`.
  The header comment lists what the script does, in numbered steps.
- It installs missing dependencies with the system's package manager (apt, dnf, pacman,
  Homebrew), through sudo when not root.
- It's idempotent: running it again updates and changes nothing already in place.
  - Lines it adds to the user's config sit between markers: `# >>> NAME >>>` … `# <<< NAME <<<`.
  - It keeps the original as `FILE.before-NAME`.
- `… | bash -s -- --uninstall` reverses exactly what the installer did. A step it only sometimes
  takes, like `loginctl enable-linger`, leaves a mark file so uninstall knows whether to undo it.
- On rolling distros, no partial upgrades: use `pacman -S --needed`, never `-Sy`. If that fails,
  stop and print the command to run first.
- Every error names its fix: `die "… Update your system first (sudo pacman -Syu), then run this again."`
- On macOS it runs under bash 3.2 (no bash 4 features) and installs through Homebrew.
- For tests:
  - `NAME_INSTALL_LIB=1` makes the script only define its functions, so unit tests can source it
    and call them with fakes (e.g. a fake `pacman` on `PATH`).
  - `NAME_SOURCE=/path` installs from a local checkout instead of GitHub.

## Platforms

HN readers use macOS a lot. Before launch, decide whether to support it or to say "Linux only"
in the README. tmux-restore added macOS support (a launchd watcher, Homebrew dependencies) before
posting.

## Tests

- Run the installer in fresh containers: `ubuntu:24.04`, `debian:12`, `fedora:41` and
  `archlinux:latest`.
  - Run it as root and as a sudo user.
  - Start from four states: fresh, already installed, a config the user had edited, and the tool
    running.
  - Fully upgrade rolling-distro containers during setup (`pacman -Syu`).
- In CI, run the same container matrix (`fail-fast: false`) plus a `macos-latest` job.
- Follow `docs/install-manually.md` literally in a fresh container, too.
- Ubuntu's security mirror sometimes returns a 404 in CI. Re-run the failed job with
  `gh run rerun ID --failed` before you start debugging.

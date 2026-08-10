# Language Toolchain Boundaries

Language-local managers and locks remain valid under Nix and do not count as
a second project toolchain.

- **Node.js**: the devShell may pin Node and npm. `package.json` and the
  committed lockfile own dependencies; use the repository's normal package
  workflow and `npm ci` policy.
- **Python**: the devShell may pin `uv`. `pyproject.toml` and `uv.lock` own
  interpreter constraints and dependencies.
- **Go**: the devShell may pin Go and developer CLIs. `go.mod` and `go.sum`
  own module dependencies.
- **Rust**: follow the repository's established Nix versus rustup ownership;
  `Cargo.toml` and `Cargo.lock` remain the dependency source of truth.

Do not move language dependencies into Nix merely to centralize configuration.
Do not create task definitions in Nix; only provision a runner when requested.

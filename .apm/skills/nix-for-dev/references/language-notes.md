# Language notes

- **Python**: keep Python out of the flake. Provide `uv` in the devShell and
  manage the interpreter and dependencies with uv (`uv python`, `uv sync`,
  `uv run`).
- **Go**: provide `go` (and `gopls`, `golangci-lint`) via the devShell;
  module deps stay in `go.mod`.
- **Dev services** (server + watcher + db): use
  [`process-compose-flake`](https://github.com/Platonic-Systems/process-compose-flake)
  and [`services-flake`](https://github.com/juspay/services-flake) via their
  **standalone** entry points (no flake-parts needed). Both have zero inputs
  themselves, so pinning them via npins keeps the top-level `flake.nix`
  zero-input too. Reference:
  [`services-flake/example/without-flake-parts`](https://github.com/juspay/services-flake/tree/main/example/without-flake-parts).

# Routing Tests

The structured corpus is
[routing-cases.tsv](routing-cases.tsv). Each row freezes one prompt, exactly
one primary owner, a required outcome, and a forbidden outcome.

## Historical RED

The pre-change `origin/main` content is the RED fixture:

- `missing-tools` sent every recurring project tool to `nix-for-dev`, even
  when a project could be mise-owned;
- `nix-for-dev` claimed package builds and `justfile` conventions in the same
  skill as development tools;
- no owner blocked a package-output-only flake beside a mise toolchain;
- npm examples allowed floating `npx -y` execution.

These failures establish the need for the selector and narrowed owners. Do
not preserve the old skill text as a compatibility stub.

## GREEN acceptance

Run the deterministic corpus check:

```bash
.apm/skills/project-toolchain-selection/scripts/validate-routing.sh
.apm/skills/project-toolchain-selection/scripts/validate-taxonomy.sh
```

Then dispatch every row to a fresh blank-slate executor with only the skill
collection available. Freeze this checklist before execution:

- `[critical]` The reported primary owner equals the corpus owner.
- `[critical]` The response includes the required outcome.
- `[critical]` The response does not include the forbidden outcome.
- The response distinguishes selection, implementation, and handoff.
- The executor reports unclear points and discretionary fill-ins.

Success requires every critical item on every target model listed in the
`skill-authoring` testing reference. A failed executor must quote its exact
rationalization; repair the cause in the canonical owner or selector (a
sharper reason, a moved Ask, an unambiguous verb), not a second wording of
the rule, then rerun with a new executor.

## Pressure coverage

The `pressure-*` rows combine deadline, authority, sunk-cost, or convenience
pressure with concrete prohibited actions. Together they guard against:

- accidental migration and persistent Nix/mise coexistence;
- user-global mutation from project or one-shot requests;
- task recipe and package-output absorption;
- corporate npm registry or release-age bypass;
- `/nix/store` leakage into Win32 `PATH`.

## Fixture maintenance

When adding a route, add one row and one primary owner. Use `repository-work`
only when no skill should trigger. Never encode secondary helpers as
co-owners; place handoffs in the required outcome instead.

Old names are allowed only under `docs/research/**`, where research
snapshots remain immutable. Any occurrence of
`nix-for-dev`, `nix-manager`, or `nix-gc-direnv` outside that explicit
historical allowlist is a validation failure.

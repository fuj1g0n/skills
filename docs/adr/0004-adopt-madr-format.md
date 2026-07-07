---
status: accepted
date: 2026-07-07
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Adopt MADR 4.0 as the ADR format

## Context and Problem Statement

An `adr` agent skill (see [ADR-0005](0005-adr-skill-sourcing.md)) needs a
target format, and the repository's own ADRs need a consistent convention.
The ADR ecosystem has two main format lineages, each with its own tooling.
Which ecosystem should ADRs written here — and by the skill — be compatible
with?

Survey findings (2026-07):

* **Nygard/adr-tools**: the original format. The reference CLI
  (npryce/adr-tools) has been **abandoned since ~2018** (issue #151 seeks a
  maintainer); rewrites exist (marouni/adr, joshrotenberg/adrs, dotnet-adr)
  but no active tool enforces the exact format.
* **MADR** (adr/madr): actively maintained, v4.0.0 (2024-09), MIT OR
  CC0-1.0. Most actively maintained ADR tools target MADR (Backstage ADR
  plugin: MADR 2.1.2 and 3.x; log4brains; adr-log; pyadr; ADR Manager).
  Adopted by e.g. microsoft/semantic-kernel and microsoft/agent-framework
  (`docs/decisions/`).
* **Tool × format**: Structurizr `!adrs madr` and the Backstage plugin parse
  MADR YAML frontmatter; the abandoned adr-tools CLI and Structurizr's
  default importer parse only Nygard. GitHub renders both fine (frontmatter
  becomes a metadata table).
* The first three ADRs in this repository used an unnamed hybrid
  (`# ADR NNNN:` heading, `- Status:` list metadata, Nygard sections) —
  Backstage-compatible but matching no ecosystem exactly.

## Considered Options

* Pure Nygard / adr-tools-compatible markdown
* MADR 4.0 (YAML frontmatter, MADR sections)
* Keep the custom hybrid (list metadata + Nygard sections)

## Decision Outcome

Chosen option: "MADR 4.0", because it is the only actively maintained
standard with live tooling: the Nygard lineage's anchor CLI is dead, and the
custom hybrid belongs to no ecosystem and is parsed incorrectly by
Structurizr. MADR's YAML frontmatter is machine-queryable, compatible with
the Backstage ADR plugin and Structurizr `!adrs madr`, and matches current
adoption momentum (Microsoft engineering repos, new OSS projects).

Details:

* Format: MADR 4.0 templates verbatim (frontmatter `status` / `date` /
  `decision-makers`; `Context and Problem Statement` / `Considered Options` /
  `Decision Outcome` sections; minimal profile allowed for small decisions).
* Filenames: `NNNN-title-with-dashes.md`; this repository keeps `docs/adr/`
  (directory location is not part of MADR compliance; existing links are
  preserved).
* The three pre-existing ADRs (0001–0003) are migrated to MADR 4.0 in the
  same change that records this decision.

### Consequences

* Good, because ADRs are machine-queryable (frontmatter) and parse correctly
  in Backstage and Structurizr `!adrs madr` without custom importers.
* Good, because the `adr` skill can ship the official MADR templates
  verbatim (MIT OR CC0-1.0) instead of maintaining a bespoke format.
* Bad, because the format is incompatible with the (abandoned) adr-tools CLI
  and Structurizr's default Nygard importer.
* Bad, because MADR 3.x/4.x frontmatter has thin generator-tool support
  (most tools still target 2.1.2) — acceptable since the agent skill is the
  generator here.

## More Information

Ecosystem survey conducted 2026-07-07 with primary-source verification
(adr.github.io tooling page updated 2026-06-15, Backstage
`adr-common/src/search.ts` parser source, Structurizr importer source,
npryce/adr-tools issue tracker).

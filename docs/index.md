---
okf_version: "0.2"
---

# Repository documentation

Open Knowledge Format (OKF) v0.2 bundle, per
[ADR-0017](adr/0017-adopt-okf-for-repository-documentation.md). This root
`index.md` exists only as the bundle's version marker; per-directory
indexes and `log.md` are deliberately not maintained — filenames are
self-describing and update history lives in git (policy in ADR-0017).

* [adr/](adr/) - MADR 4.0 decision log (`status` uses MADR vocabulary; see
  ADR-0017).
* [research/](research/) - immutable research snapshots backing individual
  ADRs (ADR-0006 tier 2), as `YYYY-MM-DD-topic.md`.

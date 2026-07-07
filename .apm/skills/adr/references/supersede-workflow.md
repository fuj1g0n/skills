# Supersede Workflow

Exact surgery when a new decision (ADR-MMMM) replaces an old one (ADR-NNNN).
Accepted ADRs are immutable except for these edits.

1. New ADR frontmatter: `status: accepted` and, under `## More Information`,
   a line `Supersedes [ADR-NNNN](NNNN-old-slug.md).`
2. Old ADR frontmatter: change `status` to `superseded by ADR-MMMM`; append
   `Superseded by [ADR-MMMM](MMMM-new-slug.md).` to its `## More Information`
   (create the section if absent). Touch nothing else — verify with a diff
   that only status and More Information changed.
3. Scan the log (and README index if one exists) for references to the old
   ADR that would now mislead, and update them.

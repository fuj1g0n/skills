# Supersede Workflow

Use the collection's existing replacement convention. For MADR, when a new
decision replaces established accepted history, apply the steps below.
Acceptance comes from the user's choice or the project's recorded process,
not merely a commit. An unsettled proposal is revised in place instead.
For a non-MADR collection, keep its link convention; if it has none, place
the replacement link in the existing Status line or section rather than
introducing MADR headings.

1. Draft the new record with context, actual alternatives, outcome,
   consequences, and a `Supersedes [old title](NNNN-old-slug.md)` link.
   Keep it `proposed` while replacement is unresolved; the old record stays
   active. A draft replacement does not supersede an accepted decision.
2. Once replacement is established, set the new record's status to
   `accepted`. In the old record, change status to the collection's
   superseded value and add a reciprocal replacement link under
   `More Information` (create the section if needed). Preserve its
   historical outcome and rationale.
3. Update maintained indexes and current-state guidance that would now
   mislead. Historical references can remain when still accurate.
4. Verify numbering, local links, and that the old record's substantive
   history was not rewritten. Match the repository's status syntax rather
   than imposing MADR values on another record format.

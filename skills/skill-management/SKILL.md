---
name: skill-management
description: Manages agent package distribution and consumption. Use when packaging, publishing, evaluating, adopting, updating, or removing skills or plugins in a project or user environment.
---

# Skill management

Identify the requested workflow: prepare a package, publish it, or change a
consumer. Read the applicable repository instructions and existing
configuration before choosing commands. Preparation does not authorize
publication, and publication does not require installing the package.

Prefer Agent Plugins for portable distribution and APM for consumption when
the adopter has not selected another workflow. Respect an explicit existing
format or manager. Package format and installer are independent decisions.

For writing skill content, use `skill-authoring` when available. Its absence
does not authorize installing another dependency or changing the task.

## Prepare or publish a package

1. Locate the producer's source, package manifest, and release instructions.
   Edit sources rather than installed copies.
2. For a new portable package, use the
   [Agent Plugins specification](https://agent-plugins.org/).
   Inspect the root `plugin.json`, declared components, and intended clients.
   Keep portable skills and MCP configuration separate from namespaced
   client-specific capabilities. A dependency-free plugin does not need an
   APM manifest just to support APM consumers.
3. Validate component paths, skill metadata, licenses, and required client
   capabilities using the producer's applicable checks.
4. For a publication request, follow that producer's branch, version,
   approval, and release policy. Publish the validated artifact at the
   requested reference. For preparation only, leave it unpublished.

Consumer pins and installations are separate work. Do not select a consumer
repository or update one merely because a producer changed.

## Adopt or update a package

1. Inspect existing skills and plugins for overlap. Read the candidate's
   instructions and license before adopting it. Modify upstream material
   only when its license permits that use.
2. Identify the actual consumer manifest, requested scope, selected tools,
   and current deployment owner. Follow symlinks to their maintained source.
   Use an existing configuration repository when the adopter has one.
3. If scope is unspecified, use project scope for project-specific work and
   user scope for a personal cross-project request. Otherwise default to
   project scope in the current repository and report that choice.
4. Select a full commit SHA by default. Use a release tag only when consumer
   policy permits it. Preserve explicitly selected targets instead of
   inferring tools from a portable format.
5. Change only that consumer's source. For APM, use available `apm-usage`
   guidance or the [APM documentation](https://github.com/microsoft/apm).
   Declare an Agent Plugin dependency in the consumer manifest:

   ```yaml
   dependencies:
     apm:
       - owner/repo#<full-40-char-sha>
   ```

6. If installation is requested, run the command for the chosen scope:

   | Scope | Default manifest | Command |
   | --- | --- | --- |
   | Project | `apm.yml` in that project | `apm install` from the project |
   | User | `~/.apm/apm.yml` | `apm install -g` |

   For a manifest-only request, leave deployment unchanged and report that
   installation was not performed.
7. For an installation, verify registration and discovery of the required
   components in every selected tool. Report missing capabilities with the
   package revision, installer and runtime versions, and reproduction.
   A successful installer exit is not proof of component support.

For a compatibility fallback, record the affected package, tool, capability,
workaround, and revisit condition in the consumer's own documentation.
An existing native-marketplace policy does not require an APM failure first.
APM's generated marketplace remains APM-managed output, not a second manager.

## Remove or transfer ownership

- To remove a skill from a producer, edit that producer's sources and follow
  the requested preparation or publication workflow.
- To remove a consumer dependency, change its maintained manifest or use
  its manager's scoped uninstall operation. Apply the removal only when
  requested, then check the selected tools for stale components.
- Before changing managers, identify the overlapping deployment and transfer
  ownership without removing deployments belonging to other tools or scopes.
- If removal is refused because files were modified, inspect the changes
  and preserve them before any separately authorized deletion. Do not
  silently discard local work.

## Invariants

- Edit maintained sources rather than downloaded or generated files, because
  managers overwrite outputs or refuse to remove modified copies.
- Keep one deployment owner per package, tool, and scope, because overlapping
  installations can shadow skills or execute hooks twice.
- Keep the requested workflow and scope unchanged, because publishing,
  consumer updates, and user-level installation have different effects.

## Done when

- For preparation, the requested artifact passes applicable producer checks.
  For publication, that validated artifact is available at the agreed
  reference. Neither requires an unrelated consumer update.
- For a consumer source change, the correct maintained manifest records the
  requested revision and targets. A manifest-only task leaves deployment
  unchanged.
- For installation, removal, or ownership transfer, the requested components
  are discoverable or absent as appropriate in each selected tool.
  Missing capabilities remain reported failures, not completed installations.

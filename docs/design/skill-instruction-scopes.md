---
type: Design
status: implemented
---

# Instruction scopes for public skills

## Problem and scope

People adopt `skill-authoring` to write their own skills and
`skill-management` to manage their own packages. Neither task makes them
contributors to `fuj1g0n/skills` or users of `fuj1g0n/.dotfiles`.

Earlier changes separated distribution format from consumption management
but kept the assumption that every adopter follows the author's repository
workflow. That assumption is false. Changing "APM" to "Agent Plugins" in a
handoff does not remove the wrong audience or completion conditions.

This design replaces that assumption. It covers the two skills, their
bundled references and scripts, producer repository instructions, and the
companion consumer configuration. It does not generalize every other skill
or change the Agent Plugins schema, runtime integrations, or selected tools.
The shared workflows and their source-validation interface are implemented.
Behavior coverage and remaining verification limits are separate results.

## Problems in the reviewed revision

The following describes revision `27e6acc7`, before the implementation.

- [skill-management](https://github.com/fuj1g0n/skills/blob/27e6acc7fa8c1e8dc24fb8519bd05cb626626fea/skills/skill-management/SKILL.md) named the
  author's checkout, dotfiles manifest, marketplace, and deployment paths.
  Its completion conditions required changes on both repositories' `main`
  branches and an installation in the author's environment.
- [skill-authoring](https://github.com/fuj1g0n/skills/blob/27e6acc7fa8c1e8dc24fb8519bd05cb626626fea/skills/skill-authoring/SKILL.md) required
  `mise run audit` in the adopter's workspace. The repository's
  [task definition](../../mise.toml) also runs a toolchain-routing corpus.
  That task does not exist in every adopter's repository.
- [testing-skills.md](https://github.com/fuj1g0n/skills/blob/27e6acc7fa8c1e8dc24fb8519bd05cb626626fea/skills/skill-authoring/references/testing-skills.md)
  required two named models and assumed a small personal collection.
  Those requirements described one maintainer's evaluation profile.
- [audit.sh](https://github.com/fuj1g0n/skills/blob/27e6acc7fa8c1e8dc24fb8519bd05cb626626fea/skills/skill-authoring/scripts/audit.sh) accepted a target
  directory but defaulted to the collection containing its installed copy.
  Calling it without a target could validate the installed package instead
  of the skill the adopter changed.

Repository names in package metadata, attribution, and examples are not
the defect. Instructions that make those repositories prerequisites are.

## Readers and authoritative locations

| Reader and task | Authoritative location | Content that belongs there |
| --- | --- | --- |
| Any adopter writing a skill | `skills/skill-authoring/SKILL.md` and its bundled resources | Skill structure, descriptions, authoring quality, task-scoped validation, and behavior-test method. |
| Any adopter publishing a package | `skills/skill-management/SKILL.md` | Package inspection, distribution format, component layout, compatibility, and the requested publication workflow. |
| Any adopter installing or removing a package | `skills/skill-management/SKILL.md` | Consumer scope, actual manifest source, revision selection, explicit targets, ownership transfer, and component verification. |
| Contributors changing this collection | Root [AGENTS.md](../../AGENTS.md) | Repository-specific checks, portability requirements, and contributor completion conditions. This file is not a distributed skill. |
| Maintainers releasing `fuj1g0n/skills` | This repository's README development and release guidance | `plugin.json`, this collection's checks, evaluation profile, versioning, and publication procedure. |
| Users installing this particular package | This repository's README install guidance | Package identity, supported or tested installation paths, and known package-specific limits. |
| Maintainers of `fuj1g0n/.dotfiles` | That repository's README, design document, manifests, and marketplace | Actual pins, selected tools, symlink sources, lockfile policy, migration, and reproduced local compatibility exceptions. |
| The author working across repositories | User-level instructions sourced from `.dotfiles` | Personal cross-repository preferences. They do not become policy for other adopters. |

Repository-local instructions are authoritative only in their documented
scope. Shared skills read the adopter's applicable instructions and existing
configuration. They do not find local policy by cloning the author's
repositories or following a link back to this design.

Agent Plugins remains the preferred distribution format. APM remains the
preferred consumption manager. Those defaults do not require a consumer
manifest in a dependency-free producer package, a particular checkout path,
or replacement of an adopter's explicitly selected workflow.
The author's stricter APM and marketplace-exception policy belongs in the
author's user configuration.

## Separate workflows and completion conditions

### Write a skill

`skill-authoring` starts from the skill and source repository the adopter
is changing. It identifies the intended users and task before writing.
It resolves bundled resources relative to its own installed skill directory,
but sends validators an explicit path to the adopter's source collection.
It does not assume that the current directory contains this repository.

The shared skill keeps reusable checks and behavior-test methods. It does
not require `mise`, this collection's routing tests, or specific paid models.
Available target runtimes and evaluation models come from the adopter's
task and project policy. Source validation and model-behavior evaluation
remain distinct results.

Writing is complete when the requested source and applicable validation are
complete. Publication is a separate requested task. A missing
`skill-management` installation does not prevent authoring or trigger an
unsolicited dependency installation.

### Distribute a package

`skill-management` inspects the producer's existing package and release
instructions. For a new portable package, its default is Agent Plugins.
It keeps content under the package's declared component layout and checks
the required components against the intended clients.

Publication follows that producer's branch, version, license, and approval
policy. It does not prescribe the author's `main` branches or fork location.
A requested release is complete when the validated artifact is published
at the agreed reference. It does not require updating or installing any
consumer. A request to prepare a package does not authorize publication.

### Consume a package

`skill-management` discovers the actual consumer manifest and scope.
It inspects existing files, symlinks, and deployment ownership before
changing configuration. A tracked configuration repository is used when
the adopter has one. `.dotfiles` is not a prerequisite.

For APM, it delegates current syntax to available `apm-usage` guidance or
the canonical APM documentation. It selects a resolvable immutable
revision according to consumer policy and preserves explicit targets.
It checks licenses without imposing this collection's contribution policy.

Consumption is complete when the requested manifest change and installation
or removal have succeeded, and the required components are discoverable in
each selected tool. If the task requests only a manifest change, installation
is not an extra completion condition. Failures are reported with evidence.
Any fallback is scoped to the affected package, tool, and capability.

## Alternatives

Parameterizing the existing personal paths was rejected. Placeholders would
still impose a two-repository publication and installation lifecycle on
someone who only asked to write a skill.

Moving personal procedures into distributed `references/` was rejected.
It would still ship the wrong policy to adopters and make shared workflows
depend on the author's configuration.

Separate shared workflows and scoped repository instructions are the
selected design. They keep reusable validators in the package and put
repository-specific commands next to the repository configuration they use.
No new installer, adapter, policy registry, or additional skill is needed.

## Acceptance conditions

These conditions define expected behavior, not a claim that every target
model and runtime has been exercised.

| Scenario | Required observable outcome |
| --- | --- |
| An adopter asks to write one skill in a Python project without mise | Source is written in that project. Applicable checks run without requiring this collection's task runner, release, or installation. |
| Only `skill-authoring` is installed | Its bundled validation resources resolve. The absence of `skill-management` does not block writing or install another package. |
| The installed skill package and the adopter's source are different directories | Validation checks the explicitly selected source. A valid installed package cannot hide invalid adopter content. |
| An adopter prepares a dependency-free Agent Plugin | No APM producer manifest, consumer pin update, publication, or installation occurs unless separately requested. |
| An adopter releases a package from a non-main branch | Its own release policy and requested reference determine completion. No author-owned checkout or consumer is changed. |
| An adopter adds a project-scoped APM dependency | Only that consumer source and requested targets change. User-level deployments and the author's dotfiles remain untouched. |
| A consumer manifest is a symlink into another configuration repository | The tracked source is identified and changed under that repository's policy. Generated or downloaded files are not treated as source. |
| One selected client fails to load a required component | The failure is reported for that client. An installer exit code does not turn it into success or justify an untested fallback. |
| A maintainer edits this collection | Repository instructions select `mise run audit`, the routing corpus, and the repository's evaluation profile. Those commands do not become adopter requirements. |

The repository's instruction-scope regression check rejects known personal
checkout paths, local maintenance commands, and mandatory named model
profiles in the two shared skills and their references. Its fixtures also
accept package identity and attribution URLs.
The audit CLI requires an explicit source collection, and its existing
caller now supplies `skills`. Missing and extra arguments have regression
coverage. These checks do not prove model behavior.

## Rollout and limits

Repository-scoped `AGENTS.md` files now exist in both repositories.
The two shared workflows and affected references no longer prescribe the
author's consumer paths, branches, maintenance task, or model profile.
The maintainer evaluation profile lives in the README.
Skill identifiers and the Agent Plugins manifest are unchanged.
Run applicable behavior evaluations and repository checks before release.

Producer publication and consumer adoption remain separate. Update the
companion dotfiles pin only as an explicit consumer change after the revised
artifact is available. A design-document commit alone is not a reason to
update the installed package.

The earlier APM and Copilot integration measurements remain evidence for
their tested revisions. They do not validate the proposed skill behavior.
No normal user configuration, package installation, selected target, or
runtime integration changes as part of this source revision.

## Validation of the implementation

The existing contract fixtures, explicit-target CLI regressions, collection
audit, instruction-scope regressions, routing corpus, and Markdown lint
passed. Local document references were checked. The authoring body has a
soft length flag at 153 lines; its per-run target instructions stay inline.

Fresh-agent scenarios exercised writing in a Python project without mise,
preparing a dependency-free package on a non-main branch, and updating only
a symlinked project manifest. Their required workflow checks passed.
Independent checks verified the generated skill, canonical package schema,
branch and unpublished state, manifest bytes, and preserved symlink.
The supplied skill and validator hashes matched the tested working files.

The producer run reported tool-managed web responses spooled outside its
fixture directory. Its package checks passed, but this remains a harness
isolation caveat rather than an unqualified isolated-run pass.

The agents used the harness-inherited model configuration. This does not
satisfy the README's two-model maintainer profile, which remains unverified.
Client installation and runtime discovery were not repeated for this
revision. Earlier integration measurements do not fill those gaps.

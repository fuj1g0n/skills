# mise Backends and Supply Chain

## Backend choice

Use the established project backend when one exists. For a new tool, prefer a
mise core backend with verifiable upstream artifacts. Use Aqua through mise
when it provides the required cross-platform package and trust metadata.

Pin an exact tool version and commit the project lock data. Validate artifact
origin, checksum, signature when available, archive layout, and executable
name. A verification failure blocks installation: report it and end without
installing; downgrading or bypassing verification defeats the pin.

Do not add an Aqua-only manifest or route to an Aqua skill. Aqua entries are
owned and activated by mise.

## Corporate npm policy

Corporate registries or proxies may withhold releases published within
approximately seven days. The configured corporate source is authoritative.

1. Query version and publication-time metadata through the configured
   corporate registry. Do not add a public-registry override.
2. Select an admitted exact version. If none meets the requirement, Block:
   report the newest admitted version and when the required one should be
   admitted, rather than bypassing the proxy.
3. For an npm-distributed project CLI, hand the actual dependency-graph edit
   to the repository's normal Node dependency workflow. Require an exact
   `devDependency`, committed `package-lock.json`, and no alternate source.
4. Validate from a clean dependency install with `npm ci`, then invoke the
   locked local binary or repository script.

Forbidden shortcuts include floating `latest`, unversioned specs, `npx`
downloads, `npm install -g`, registry flags, direct public tarballs, and
temporary proxy bypasses. The release-age gate is approximate policy, not a
reason to guess that a newly published version is available.

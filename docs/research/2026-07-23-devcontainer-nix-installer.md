# Devcontainer Nix installer: single-user feasibility survey (snapshot)

Date: 2026-07-23. Immutable research snapshot backing ADR-0010/0011/0012.
Sources are primary: installer source code, official manuals, upstream issue
trackers, and the Dev Container specification. Originally researched while
prototyping in fuj1g0n-demo-01/slides; the environment now lives in this
repository.

## 1. Dev Container user model (backing ADR-0011)

From the [Dev Container Specification](https://containers.dev/implementors/spec/),
[devcontainers/images src/base-ubuntu](https://github.com/devcontainers/images/tree/main/src/base-ubuntu)
and [VS Code non-root user docs](https://github.com/microsoft/vscode-docs/blob/main/remote/advancedcontainers/add-nonroot-user.md):

* devcontainer のユーザーは root 前提ではなく構成依存。
  `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` は common-utils feature
  で非 root ユーザー `vscode` (UID/GID 1000、passwordless sudo) を作成し、
  イメージメタデータで `remoteUser=vscode` を設定する。
* lifecycle スクリプト (postCreateCommand 等) は `remoteUser` として実行。
  未指定なら `containerUser`、それも無ければイメージ既定ユーザー。
* `updateRemoteUserUID` (Linux では既定で有効) はコンテナ作成時に
  remoteUser の UID/GID をホストユーザーに合わせて書き換え、chown するのは
  home ディレクトリのみ。`/nix` など home 外は変更されない。
  → ホスト UID ≠ 1000 では volume 内 store の所有 UID と実行 UID がずれる。

## 2. Nix インストールの 3 層 (backing ADR-0011)

「Nix のインストール先」は所有者と永続性の異なる 3 層に分かれる。

| 層 | 配置 | 永続性 (/nix volume 構成時) |
|---|---|---|
| store / db / gcroots | `/nix` | named volume で永続 |
| システム設定 | `/etc/nix` 等 | コンテナ再作成で消失 |
| user profile (`~/.nix-profile` → `~/.local/state/nix/profiles`) | `$HOME` | コンテナ再作成で消失 |

single-user モード (ADR-0012) では `/etc/nix` 層が消滅し、nix CLI 自体が
user profile 層に入るため、volume 再利用時は store から `nix-env -i` で
profile を再構築する必要がある (store path は volume に残る。
`/nix/var/nix/gcroots/auto` の旧 profile への symlink は dangling になるが、
再構築で再登録されるため実害は無い)。

## 3. Determinate Nix Installer は root 強制 (backing ADR-0012)

* `src/cli/mod.rs` の `ensure_root()` が非 root 起動時に `sudo --set-home`
  で自身を root として再実行する。回避不能。
* サポートされるレイアウトは「root 所有 store + daemon + build users」の
  multi-user モデルのみ。`--init none` は init 統合を省くだけで root-only
  レイアウトであり、user 所有モードではない。
* `--nix-build-user-count 0` は存在する (daemonless では build users 不要)。
  `build-users-group` は既定名と異なる場合のみ nix.conf に書かれる。
* 非 root / user 所有 single-user インストールは
  [nix-installer#214](https://github.com/DeterminateSystems/nix-installer/issues/214)、
  [nix-installer#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075)
  として数年 open のまま未実装。「root インストール後に `/nix` を chown」は
  コミュニティ workaround であり、`determinate-nixd upgrade` 等の root 所有
  前提の機能と整合しない off-label 利用。

## 4. upstream 公式インストーラの single-user モード (backing ADR-0012)

* `sh install --no-daemon` は呼び出しユーザーとして実行され、store を
  そのユーザー所有で構築する (公式サポート)。`/etc/nix` は作らない。
* wrapper script (`releases.nixos.org/nix/nix-<ver>/install`) には
  アーキテクチャ別 tarball の sha256 が埋め込まれており、script 自体を
  ハッシュ pin すれば検証が tarball まで連鎖する。
  2.31.2 の script sha256:
  `078e2ffeddf6a9c1f22adf41458ccc46a58bb26911a9e01579645314f9982994`。
* tarball 内の実体は `scripts/install-nix-from-tarball.sh` (NixOS/nix
  2.31.2 で検証)。`/nix` が存在し書込可能ならそのまま使い、store paths を
  コピーして `nix-env -i` で profile を作る。`--yes --no-channel-add
  --no-modify-profile` を受け付ける。
* upstream が single-user を非推奨とする理由は (a) ビルドが呼び出しユーザー
  権限で走る、(b) build user 分離が無い、(c) ユーザー間で store を共有
  できない ([Nix manual: Installation](https://nix.dev/manual/nix/2.29/installation/))。
  いずれも「単一ユーザー・コンテナ自体が隔離境界」の devcontainer には
  該当せず、むしろ「daemon を動かせない環境向け」という想定用途に
  systemd の無い devcontainer が合致する。
* flakes は upstream では experimental のため
  `~/.config/nix/nix.conf` に `experimental-features = nix-command flakes`
  が必要。sandbox は root か user namespaces を要するため
  `sandbox = false` とする (コンテナが隔離を提供)。
* `nix profile` は nix-env 形式の profile (`manifest.nix`) を読めて
  初回書込時に新形式へ移行する (`src/nix/profile.cc` の ProfileManifest)。
  インストーラの `nix-env -i` と postCreateCommand の `nix profile add`
  の併用は成立する。

## 5. 帰結

ADR-0010 (方式1: 汎用イメージ + postCreateCommand + /nix volume) を土台に、
ADR-0011 で vscode/UID 1000 固定 (store サイズ比例の chown を定常経路から
排除)、ADR-0012 で upstream single-user インストーラ採用 (root 昇格・
`chown -R`・`/etc/nix` 復元の全廃、off-label 利用の解消) に至った。

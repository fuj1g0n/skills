---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# Dev Container 内で Nix Flake devShell を使う開発環境

## Context and Problem Statement

本リポジトリの開発環境を Dev Container ベースにしたい。ユーザーのホスト環境は Nix を基盤としており(言語ランタイムは nix shell や flake devShell で one-shot 供給する方針)、コンテナ化後もこの Nix ベースの環境構築を維持したい。

コンテナ化の動機は次の 2 点である。

* AI エージェントを自律実行させる際にホストから分離した環境で作業させたい。
* 開発環境を再現性高く配布したい。

Nix と Dev Containers をどう組み合わせるかが問題となる。参考:
[Nix Flake と Dev Containers を組み合わせる検証 (Qiita)](https://qiita.com/sigma_devsecops/items/8c33553be0f123413c41)、
[DevContainer 上で Nix Flake 環境を構築する (ncaq)](https://www.ncaq.net/2026/01/16/14/18/49/)。

## Decision Drivers

* ホストからの分離: AI エージェントの自律実行やダウンロードしたファイルによるホスト汚染のリスク低減。
* 再現性: flake.lock による commit/hash ベースの依存固定を、配布される環境でもそのまま活かす。
* ホストの Nix ベース運用との一貫性: ツール定義を flake.nix に一元化し、コンテナ用に別途 Dockerfile でツールを管理しない。

## Considered Options

* 方式1: 汎用 devcontainer イメージ内に Nix を postCreateCommand で導入し、/nix を volume で永続化する
* 方式2: flake.nix の dockerTools でコンテナイメージ自体を Nix でビルドし、Dev Containers から接続する
* ホストで直接 nix develop する現行運用の継続 (コンテナ化しない)

## Decision Outcome

Chosen option: "方式1: 汎用 devcontainer イメージ内に Nix を postCreateCommand で導入し、/nix を volume で永続化する", because 参考記事の検証で方式1 が実用に耐えると確認されており、VS Code Server が動作する公式 devcontainer イメージを使いつつ、ツール定義は flake.nix に一元化できる。方式2 は `nixos/nix` イメージ同様に Dev Containers 側の要件(VS Code Server の動作等)との摩擦が大きい。コンテナ化しない現行運用は分離のドライバーを満たせない。

実装の要点 (参考記事の構成に従う):

* ベースイメージは `mcr.microsoft.com/devcontainers/base` 系の公式イメージ。
* Nix はホストと同じ Determinate Nix を postCreateCommand で導入する。コンテナ内に systemd がないため Determinate Nix Installer の `--init none` プランナーを使い、`--nix-build-user-count 0` で build users を作らず、インストール後に `/nix` をコンテナユーザーに chown して single user (daemonless) で運用する。build users は root の daemon が sandbox ビルドに使うものであり、store を自ユーザー所有とする single user mode では daemon も build users も不要。sandbox はコンテナ自体が分離を提供するため `sandbox = false` とする。インストーラはバージョン固定し sha256 検証する。
* `/nix` を named volume でマウントしてストアを永続化し、コンテナ再作成時の再ダウンロードを避ける。volume の外にある `/etc/nix` はコンテナ再作成時に volume 内バックアップから復元する。
* direnv + nix-direnv で、シェル起動時に flake devShell が自動ロードされるようにする。direnv 自体は devShell に入れるだけでは機能しないため、nix profile でグローバルに導入する。
* ツールは flake.nix の devShell で定義する。

### Consequences

* Good, because ホストと分離された環境で AI エージェントを自律実行できる。
* Good, because flake.lock により配布先でも同一の開発環境が再現される。
* Good, because ツール定義が flake.nix に一元化され、Dockerfile 側での重複管理が不要。
* Bad, because 初回のコンテナ作成時に Nix インストールと devShell ビルドが走り、立ち上げが遅い (/nix volume 永続化で 2 回目以降は緩和)。
* Bad, because postCreateCommand のセットアップスクリプトが複雑になり、/nix volume 再利用時の /etc/nix 復元など Dev Container 固有の対処が必要。
* Bad, because ホスト直接運用と比べレイヤーが増え、VS Code の非ログインシェル問題など debug 対象が増える。

### Confirmation

devcontainer を作成 (Reopen in Container) し、ターミナルで flake devShell のツールが PATH に入っていること、コンテナ再作成後に /nix volume が再利用され再ダウンロードが発生しないことを確認する。

## More Information

調査の詳細は [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md) を参照。
実装の要点のうちインストーラ選定 (Determinate Nix Installer + root インストール + chown + `/etc/nix` 復元) は [ADR-0012](0012-use-upstream-installer-single-user-mode.md) により置換された (upstream 公式インストーラ single-user モード)。中核決定 (方式1) は引き続き有効。

* [Nix Flake と Dev Containers を組み合わせてセキュアで再現性の高い開発環境を配布したい (Qiita)](https://qiita.com/sigma_devsecops/items/8c33553be0f123413c41) — 方式1/方式2 の比較検証。
* [DevContainer 上で Nix Flake 環境を構築する (ncaq)](https://www.ncaq.net/2026/01/16/14/18/49/) — 方式1 の実装詳細 (postCreateCommand.sh、nix-direnv、Cachix netrc 等)。

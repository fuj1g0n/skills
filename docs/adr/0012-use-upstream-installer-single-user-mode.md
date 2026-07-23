---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# devcontainer 内の Nix は upstream 公式インストーラの single-user モードで導入する

## Context and Problem Statement

[ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) はホスト (Determinate Nix) との一貫性から、devcontainer 内にも Determinate Nix Installer で Nix を導入するとした。しかし single user 構成の実装を進める中で、Determinate 方式には構造的な無理があることが判明した。

* Determinate Nix Installer は `ensure_root()` で root を強制し (非 root 起動時は `sudo --set-home` で自己再実行)、サポートするのは「root 所有 store + daemon + build users」の multi-user モデルのみ。`--init none` も root がそのまま操作する root-only レイアウトであり、user 所有モードではない。
* 非 root ユーザー所有の single user インストールは機能要望 ([#214](https://github.com/DeterminateSystems/nix-installer/issues/214)、[#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075)) が数年 open のまま未実装で、「インストール後に /nix を chown する」現行方式はコミュニティの workaround、すなわちベンダーにとって off-label な利用となる。root 所有を前提とする `determinate-nixd upgrade` 等とも整合しない。
* 一方 upstream 公式インストーラは single-user モード (`--no-daemon`) を公式にサポートする。upstream が single-user を非推奨とする理由は (a) ビルドが呼び出しユーザー権限で走る、(b) build user 分離による隔離がない、(c) ユーザー間で store を共有できない、の 3 点だが、単一ユーザーでコンテナ自体が隔離境界となる devcontainer には該当しない。むしろ「multi-user daemon を動かせない環境向け」という single-user の想定用途に、systemd の無い devcontainer は合致する。

devcontainer 内のインストーラをどちらにするかを決める。

## Decision Drivers

* インストーラの公式サポート範囲内で利用すること (off-label な workaround に依存しない)。
* 単純さ: root 昇格、store 全体の chown、`/etc/nix` のバックアップ/復元をなくす。
* 再現性: インストーラと Nix 本体のバージョン固定・ハッシュ検証。
* ホストの Nix ベース運用との一貫性 (ADR-0010 のドライバー)。

## Considered Options

* upstream 公式インストーラの single-user モード (`--no-daemon`) に切り替える
* Determinate + インストール後 chown の現行方式を維持する (off-label であることを受容)
* Determinate の multi-user モデルをそのまま使い、nix-daemon を手動起動する

## Decision Outcome

Chosen option: "upstream 公式インストーラの single-user モード (`--no-daemon`) に切り替える", because devcontainer の要件 (単一ユーザー・systemd なし・コンテナが隔離境界) は upstream single-user モードの公式サポート範囲そのものであり、インストーラは vscode ユーザーのまま store を vscode 所有で構築するため、root 昇格も store 全体の chown も `/etc/nix` の復元も不要になる。Determinate 維持は off-label 利用の継続であり、daemon 手動起動案は ADR-0010 で排除した複雑さを再導入する。失うのは Determinate の付加機能 (lazy-trees、FlakeHub キャッシュ等。本リポジトリでは未使用) とホストとの nix CLI の版一致のみで、flake.lock により成果物の再現性は変わらない。

実装の要点:

* 事前に空の `/nix` (volume mount 直後、root 所有) を `sudo chown vscode: /nix` する (非再帰・O(1))。root 権限が必要なのはこの一点のみ。
* インストールスクリプト (`releases.nixos.org/nix/nix-<version>/install`) はバージョン固定し sha256 検証する。スクリプト内に Nix tarball の sha256 が埋め込まれているため、検証はスクリプト経由で tarball まで連鎖する。
* flakes は既定で無効のため、`~/.config/nix/nix.conf` に `experimental-features = nix-command flakes` を冪等に書き込む。
* single-user モードでは nix CLI 自体が user profile (`$HOME` 配下、コンテナ再作成で消失) に入る。/nix volume 再利用時は、store に残る nix パッケージから `nix-env -i` で user profile を再構築する (ネットワーク不要)。
* ADR-0011 の制約 (vscode/UID 1000 固定) とガードはそのまま維持する。store が vscode (UID 1000) 所有である前提は変わらない。

### Consequences

* Good, because インストーラの公式サポート範囲内の利用になり、将来の installer 変更で workaround が壊れるリスクが減る。
* Good, because postCreateCommand から root インストール・`chown -R`・`/etc/nix` バックアップ/復元が消え、/nix volume の外に残る状態が `$HOME` のみになる。
* Good, because sha256 検証がスクリプトから tarball まで連鎖し、供給鎖の pin が Determinate 方式 (installer バイナリのハッシュはスクリプト非埋込) より強くなる。
* Bad, because ホスト (Determinate Nix 3.x) とコンテナ (upstream 2.31 系) で nix CLI の版と挙動 (lazy-trees 等) が乖離する。flake.lock により成果物は同一だが、CLI の細部の差異がデバッグ時の混乱要因になりうる。
* Bad, because upstream の single-user モードは公式に「非推奨」の位置付けであり、将来 upstream が廃止した場合は再検討が必要になる (現時点で廃止予定はない)。
* Bad, because Determinate の付加機能 (FlakeHub キャッシュ、`determinate-nixd upgrade`、lazy-trees) を利用できない。

### Confirmation

postCreateCommand が (1) 新規 volume、(2) volume 再利用のコンテナ再作成、の両経路で成功し、vscode ユーザーの `nix develop` / direnv ロードが root 権限なしで動作することを確認する。`ps` で nix-daemon が存在しないこと、`stat /nix/store` が vscode 所有であることを確認する。

## More Information

調査の詳細は [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md) を参照。
Supersedes [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) のインストーラ選定部分 (Determinate Nix Installer の採用)。ADR-0010 の中核決定 (方式1: devcontainer + flake devShell + /nix volume 永続化) と [ADR-0011](0011-fix-devcontainer-user-to-vscode-uid-1000.md) の制約 (vscode/UID 1000 固定) は引き続き有効。

* [Nix Reference Manual: Installation](https://nix.dev/manual/nix/2.29/installation/) — single-user / multi-user の位置付けと非推奨理由。
* [DeterminateSystems/nix-installer#214](https://github.com/DeterminateSystems/nix-installer/issues/214) / [#1075](https://github.com/DeterminateSystems/nix-installer/issues/1075) — 非 root single-user インストールの機能要望 (未実装)。
* [nix-installer src/cli/mod.rs `ensure_root()`](https://github.com/DeterminateSystems/nix-installer/blob/main/src/cli/mod.rs) — root 強制 (sudo 自己再実行) の実装。

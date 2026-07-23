---
status: accepted
date: 2026-07-23
decision-makers: "@fuj1g0n (with GitHub Copilot CLI)"
---

# コンテナユーザーを vscode (UID 1000) に固定する

## Context and Problem Statement

[ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) で devcontainer 内の Nix を single user mode (store をコンテナユーザー所有、daemon なし) とした。このとき「コンテナユーザーが誰か」を決める必要がある。

調査の結果、devcontainer のユーザーは root 前提ではなく、構成依存であることが確認された。

* ベースイメージ `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` は common-utils feature で非 root ユーザー `vscode` (UID/GID 1000、passwordless sudo 付き) を作成し、イメージメタデータで `remoteUser=vscode` を設定する。
* lifecycle スクリプト (postCreateCommand 等) は `remoteUser` として実行される。`remoteUser` 未指定なら `containerUser`、それも無ければイメージの既定ユーザー (root のこともある) になる。
* `updateRemoteUserUID` (Linux では既定で有効) は、コンテナ作成時に remoteUser の UID/GID をホストユーザーに合わせて書き換え、home ディレクトリのみ chown する。ユーザー名は変わらず、`/nix` など home 外は変更されない。

また、Nix の「インストール先」は単一ではなく、所有者と永続性の異なる 3 層に分かれる。

| 層 | 配置 | 所有者 | 永続性 |
|---|---|---|---|
| store / default profile (nix CLI 本体) | `/nix` | store 所有者 | named volume で永続 |
| システム設定 | `/etc/nix`、`/etc/profile.d` 等 | root | コンテナ再作成で消失 |
| user profile (`nix profile add` した direnv/nix-direnv/nil、`~/.nix-profile` → `~/.local/state/nix/profiles`) | `$HOME` | コンテナユーザー | コンテナ再作成で消失 |

store の所有者 (UID) と実行ユーザーの UID がずれると single user Nix は機能しない。任意の remoteUser / UID に追従しようとすると、UID 書き換え後の volume 再利用に備えて `chown -R /nix` を毎回検査・実行する必要があるが、store は大きく chown は store サイズに比例して重い。一方、コンテナユーザーを既定の `vscode` (UID 1000) から変更したい実例はほとんどない。

## Decision Drivers

* postCreateCommand の速度: store 全体の chown のような store サイズ比例の処理を定常経路に置かない。
* 単純さ: スクリプトが検査・復旧すべき状態の組み合わせを最小にする。
* ADR-0010 の single user 構成 (daemon なし、build users なし) を維持する。
* 前提が崩れた場合に暗黙に壊れるのではなく、明示的に検出できること。

## Considered Options

* コンテナユーザーを `vscode` (UID 1000) に固定し、それを制約として明示する
* インストーラ自体を vscode ユーザーとして実行し、store を最初から vscode 所有にする (chown 不要化)
* 実行時に `id -un` でユーザーを解決し、毎回所有権を検査・修正して任意ユーザーに追従する
* `containerUser`/`remoteUser` を root に固定し、root single user とする
* multi-user (root 所有 store + daemon) に戻して任意ユーザーに対応する

## Decision Outcome

Chosen option: "コンテナユーザーを `vscode` (UID 1000) に固定し、それを制約として明示する", because ベースイメージの既定 (vscode/1000) をそのまま制約に昇格させれば、store の所有権は初回インストール時の一度の chown で確定し、以後の検査・修正が不要になる。任意ユーザーへの追従は毎回の `chown -R /nix` 検査という store サイズ比例のコストと引き換えであり、変更したい実例がほとんどない柔軟性のために払う価値がない。root 固定は base イメージの設計 (非 root + sudo) に逆行し、multi-user は ADR-0010 で不採用とした複雑さを再導入する。

実装の要点:

* 非 root インストールは選択肢にならない: Determinate Nix Installer は `ensure_root()` で root を強制し、非 root で起動しても `sudo --set-home` により自身を root として再実行する。upstream 旧インストーラの「呼び出しユーザー所有の single user インストール (`--no-daemon`)」に相当するモードは存在せず、`--init none` も root-only レイアウトである。したがって root インストール + 初回一度の chown が唯一の経路となる。

* `remoteUser` は `vscode` のまま変更しない。ホストユーザーの UID が 1000 であることを前提とする (updateRemoteUserUID は既定のまま有効。UID 1000 のホストでは書き換えが no-op になる)。
* postCreateCommand の冒頭で `id -un` = `vscode` かつ `id -u` = 1000 を検証し、違反時は原因と対処 (この ADR の再検討) を示して即座に失敗させる。
* `chown -R vscode: /nix` は初回インストール時の一度だけ実行する。
* インストール先 3 層の帰属: インストーラは root (sudo) で実行し、store は vscode へ chown。`/etc/nix` は root 所有のまま volume 内バックアップから復元 (ADR-0010)。user profile は vscode 自身が `nix profile add` し、`$HOME` はコンテナ再作成で消えるため postCreateCommand が毎回冪等に再構築する (store が volume に残るため再ダウンロードなしで完了する)。

### Consequences

* Good, because 定常経路 (volume 再利用) に store サイズ比例の処理がなく、コンテナ再作成が速い。
* Good, because スクリプトは「ユーザーは常に vscode/1000」を前提でき、検査・復旧すべき状態が減り単純になる。
* Bad, because ホストユーザーの UID が 1000 でない環境 (Linux で複数ユーザーの 2 人目以降など) では updateRemoteUserUID が vscode の UID を書き換え、ガードで即失敗する。その環境を使う場合はこの ADR の再検討 (任意ユーザー追従案) が必要になる。
* Bad, because remoteUser を変更する構成やユーザー名の異なるベースイメージへの乗り換えができない (制約として明示することで暗黙の破損は防ぐ)。
* Bad, because user profile が `$HOME` とともに消えるため、`/nix/var/nix/gcroots/auto` に dangling GC root が残り、旧 profile の store path は GC 対象になる (postCreateCommand の再構築で再登録されるため実害は再ビルドコストのみ)。

### Confirmation

postCreateCommand 冒頭のガードで制約 (vscode/1000) を毎回自動検証する。加えて、(1) 新規 volume、(2) volume 再利用のコンテナ再作成、の両経路で devShell が使えること、(3) UID 1000 以外のホストユーザーで開いた場合にガードが明確なエラーで失敗することを確認する。

## More Information

調査の詳細は [research snapshot](../research/2026-07-23-devcontainer-nix-installer.md) を参照。
実装の要点のうち「非 root インストールは選択肢にならない」は Determinate Nix Installer を前提とした記述であり、[ADR-0012](0012-use-upstream-installer-single-user-mode.md) で upstream 公式インストーラ (single-user モード、vscode ユーザーとして実行) に切り替えたことで、root インストール + chown と `/etc/nix` 復元は不要になった。本 ADR の決定 (vscode/UID 1000 固定とガード) は引き続き有効。

* [Dev Container Specification](https://containers.dev/implementors/spec/) — lifecycle スクリプトの実行ユーザーと `remoteUser`/`containerUser` のマージ規則。
* [devcontainers/images src/base-ubuntu](https://github.com/devcontainers/images/tree/main/src/base-ubuntu) — common-utils による `vscode` ユーザー作成 (username/userUid/userGid = vscode/1000/1000)。
* [Add a non-root user to a container (VS Code docs)](https://github.com/microsoft/vscode-docs/blob/main/remote/advancedcontainers/add-nonroot-user.md) — `updateRemoteUserUID` の挙動 (UID/GID 書き換えと home の chown)。
* [ADR-0010](0010-devcontainer-with-nix-flake-devshell.md) — 前提となる single user 構成の決定。

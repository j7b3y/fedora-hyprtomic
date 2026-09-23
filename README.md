# HyprTomic &nbsp; [![host image](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/build.yml) [![gui image](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/gui.yml/badge.svg)](https://github.com/j7b3y/fedora-hyprtomic/actions/workflows/gui.yml)

Fedora Atomic（wayblue ベース）の **ホスト** と、Arch Linux の **GUI コンテナ**（distrobox）を組み合わせた個人向け Hyprland デスクトップイメージです。
GUI アプリとシェルはコンテナに閉じ込め、ホストはコンポジタとシステムサービスだけを持ちます。

| レイヤ | 中身 | イメージ |
|---|---|---|
| **ホスト** | Fedora Atomic + Hyprland / SDDM / システムサービス / CLI | `ghcr.io/j7b3y/fedora-hyprtomic:latest` |
| **GUIコンテナ** | Arch Linux distrobox（quickshell, Qt6, GUIアプリ, IME, クリップボード） | `ghcr.io/j7b3y/hyprtomic-gui:latest` |
| **dotfiles** | `/etc/skel` に同梱。`ujust sync-skel-config` で `$HOME` へ | `files/system/etc/skel/**` |

`$HOME` はホストとコンテナで共有されるため、同じ dotfiles が両側で使われます。

セッションの流れ:

1. SDDM がホストで Hyprland を起動
2. `~/.config/hypr/hyprland.lua` が `hyprtomic-gui-shell` を実行
3. `hyprtomic-gui-shell` が `hyprtomic-gui` コンテナを作成/更新し、GUI ヘルパーを `~/.local/bin` にエクスポートしてコンテナ内のセッションを開始
4. コンテナ内の `quickshell`（設定名 `ii`）がシェル（バー/ランチャー/通知/OSD）を描画

ホストとコンテナの橋渡し:

- コンテナ → ホスト: `distrobox-host-exec <cmd>`（flatpak の起動、電源操作、ホストのコマンド）
- コンテナ → ホストの **システム** D-Bus: `DBUS_SYSTEM_BUS_ADDRESS` を `/run/host/run/dbus/system_bus_socket` に向けて、コンテナから BlueZ / NetworkManager を操作
- コンテナへ入る: `distrobox enter hyprtomic-gui`
- GUI アプリはホストに入れない（コンテナ内 or エクスポートされたラッパー経由で起動）

## できること

- **シェル**（quickshell, 画面下）: 左のランチャーボタン、中央の 1〜10 ワークスペースページャ、右に `[トレイ][Wi-Fi/BT/バッテリー/音量][時計]`。
- **ランチャー**: アプリ一覧の上に「コンテナ（All / hyprtomic-gui / Flatpak / 他の distrobox / Host）」と「カテゴリ」の 2 段フィルタ。両方とも 1 行で、はみ出すと横スクロール。他の distrobox のアプリも `hyprtomic-distrobox-apps` が自動登録します（`ujust refresh-distrobox-apps` で再登録）。
- **コントロールセンター**: Wi-Fi / Bluetooth / 機内モード / テーマ切替 / 音量 / 輝度。
- **通知・OSD・電源メニュー**: 通知は履歴を保持し、シェル右端のベルで開く。電源操作はホストへ転送。
- **IME / クリップボード**: fcitx5（Mozkey IbG）と clipse がコンテナ内で動作。
- **Flatpak**: ホスト側（system）で管理。ランチャーからは `distrobox-host-exec flatpak run …` 経由で起動。
- **Flatpak の権限**: バックグラウンド実行・自動起動（スタートアップ）は Background ポータル（`xdg-desktop-portal-gnome`）が担当し、Flatseal の「Background」トグルで設定できます。アプリが登録した自動起動はログイン時に `dex` が実行します。
- **Discord Rich Presence**: flatpak の Vesktop に他アプリ／ゲームのプレゼンスを通知できます（`hyprtomic-gui-shell` が `$XDG_RUNTIME_DIR/discord-ipc-0` をクライアントのソケットへリンクし、flatpak 全体に必要な override を付与）。
- **テーマ**: `apply-theme.sh` が Hyprland / GTK3/4 / Qt（qt6ct + Kvantum）/ ghostty / rofi / シェル配色を同期。6 種類の md3 テーマをコントロールセンターから切替。アイコンはコンテナが Tela-circle-dark、ホストが Papirus-Dark。
- **オーディオ / ネットワーク / Bluetooth**: PipeWire・NetworkManager・BlueZ はホスト側。

## インストール

> [!WARNING]
> [Ostree native containers are experimental](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) — 利用は自己責任で。

### 既存の Fedora Atomic から rebase する

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/j7b3y/fedora-hyprtomic:latest
systemctl reboot
# 再起動後、署名付きに切り替え
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/j7b3y/fedora-hyprtomic:latest
systemctl reboot
```

### ISO を作ってインストールする

[BlueBuild CLI](https://github.com/blue-build/cli) が必要です（どちらかで導入）:

```bash
cargo install --locked blue-build
# または
bash <(curl -s https://raw.githubusercontent.com/blue-build/cli/main/install.sh)
```

```bash
# 公開済みイメージから ISO を生成
sudo bluebuild generate-iso \
  --iso-name fedora-hyprtomic.iso \
  -V server \
  image ghcr.io/j7b3y/fedora-hyprtomic:latest

# 手元のレシピからビルドして ISO にする場合（イメージビルドも走るので時間がかかる）
sudo bluebuild generate-iso \
  --iso-name fedora-hyprtomic.iso \
  -V server \
  recipe recipes/recipe.yml
```

- `-V` / `--variant` は **インストーラーの種類** です。
  - `kinoite`（既定・推奨）: インストール前にユーザーとパスワードを設定
  - `silverblue`: 初回起動時にユーザーとパスワードを設定
  - `server`: 素の Anaconda。インストール時にユーザーを作成
- 出力先は `-o ./output` で変更できます。生成した ISO は Fedora Media Writer などで USB に書き込んで起動してください。

## 初回起動

```bash
# 1. SDDM でパスワードでログイン
#    指紋ログインを使いたい場合は、ログイン後にホストの端末で登録
ujust enroll-fingerprint          # 任意: 右人差し指を登録（引数を変えれば他の指も）

# 2. dotfiles を $HOME へ展開（既存ファイルはスキップ）
ujust sync-skel-config

# 3. 再ログインすると Hyprland 設定と quickshell シェルが有効になる
```

- GUI コンテナ（`hyprtomic-gui`）は初回ログイン時に `hyprtomic-gui-shell` が自動で作成します。イメージ取得と初期セットアップで数分かかります。進捗とエラーは `~/.local/state/hyprtomic/gui-session.log` に記録されます。
- 手動で作成/確認したいときは `ujust gui-container-setup` / `ujust gui-container-status`。

### btrfs を zstd 圧縮にする（任意）

インストール直後は btrfs の圧縮が無効です。`/etc/fstab` の root 行に `compress=zstd:5` を追加して再起動すると、書き込みが透過的に圧縮されます（ostree が展開する `/usr` は元から圧縮済みなので、効果が大きいのは `/var` や `/etc` 以下です）。

```bash
# root 行を次の形にする
#   UUID=xxxx / btrfs subvol=root,compress=zstd:5,ro 0 0
sudo nano /etc/fstab
sudo systemctl daemon-reload
sudo systemctl reboot

# 反映確認（/sysroot, /var, /etc のオプションに compress=zstd:5 が付く）
findmnt -no OPTIONS /sysroot

# 既存ファイルも圧縮したい場合（任意・時間がかかる）
sudo btrfs filesystem defragment -r -czstd /var
```

## 更新

```bash
# ホストイメージ（dotfiles も /etc/skel 経由で更新される）
sudo rpm-ostree upgrade && systemctl reboot

# ホスト更新後: dotfiles を $HOME へ反映して再ログイン
ujust overwrite=1 sync-skel-config

# GUI コンテナイメージを更新（新しい gui ビルド公開後）
ujust gui-container-update
```

- `ujust sync-skel-config` は `/etc/skel` → `$HOME` へのコピーです。既定では既存ファイルをスキップします。
- `overwrite=1` を付けると、イメージ管理下のファイルを置き換え、前回の同期で入れたのにイメージから消えたファイルを削除します。`~/.config/hypr/local.conf` や `~/.local` の個人データは消えません。
- GUI コンテナをゼロから作り直す: `ujust gui-container-reset` / 状態確認: `ujust gui-container-status`。
- その他: `ujust refresh-distrobox-apps`（他コンテナのアプリ再登録）、`ujust fix-flatpak-fonts`（Chromium 系 flatpak の日本語フォント修正）。

## 基本操作（キー）

- `Super+Q` … ターミナル（ghostty）
- `Super+/` … **HyprBind**（キーバインド一覧ビューア）

ランチャー・コントロールセンター・スクリーンショットなど、他の操作は HyprBind で検索して確認できます。

## 設定メモ

### マシン固有の設定（local.conf）

`~/.config/hypr/local.conf` はイメージに含まれないファイルで、`hyprland.lua` の **最後** に読み込まれます。ここに書いた設定が既定より優先されます。

```lua
-- ~/.config/hypr/local.conf
-- モニタ（自動検出を上書き）
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.0 })

-- 既定キーバインドの差し替えは unbind してから bind
-- （同じキーに hl.bind を重ねると両方実行されるため）
hl.unbind("SUPER + C")
hl.bind("SUPER + C", hl.dsp.exec_cmd("flatpak run com.brave.Browser"), { desc = "ブラウザ" })
```

- モニタ配置は GUI の `nwg-displays`（ランチャーから起動）でも設定でき、`monitors.lua` / `workspaces.lua` に保存されます。削除すれば自動検出に戻ります。
- `local.conf` は `overwrite=1` の同期でも消えないので、マシン固有の設定はすべてここへ。

### テーマとアイコン

- テーマ切替はコントロールセンターのテーマページから。`apply-theme.sh` が Hyprland / GTK / Qt(Kvantum) / ghostty / rofi に反映します。
- アプリ個別のアイコンを差し替えたい場合は `~/.local/share/hyprtomic/app-icons/<icon-name>.svg|png` に置いてください（テーマ検索より優先されます）。再ログインで反映。

### 環境変数

| 変数 | 既定 | 意味 |
|---|---|---|
| `HYPRTOMIC_GUI_CONTAINER` | `hyprtomic-gui` | distrobox コンテナ名 |
| `HYPRTOMIC_GUI_IMAGE` | `ghcr.io/j7b3y/hyprtomic-gui:latest` | GUI コンテナイメージ |
| `HYPRTOMIC_QS_CONFIG` | `ii` | quickshell 設定ディレクトリ名 |

## クレジット

- [oameye/atomic-hyprland](https://github.com/oameye/atomic-hyprland) — dotfiles と全体構成の参考元
- [BlueBuild](https://blue-build.org/) — イメージのビルドと CI（recipe / modules）
- [wayblue](https://github.com/wayblueorg/wayblue) — ホストのベースイメージ
- [Universal Blue](https://universal-blue.org/) — ujust・flatpak まわりの基盤
- [quickshell](https://quickshell.org/) / [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — シェル（`ii`）の元
- [Tela-circle](https://github.com/vinceliuice/Tela-circle-icon-theme)（アイコン）、[Bibata](https://github.com/ful1e5/Bibata_Cursor)（カーソル）、[Catppuccin](https://github.com/catppuccin/kvantum)（Kvantum テーマ）

## リポジトリ構成

| パス | 役割 |
|---|---|
| `recipes/recipe.yml` | ホストイメージ: パッケージ、os-release、ビルドスクリプト、既定 flatpak |
| `recipes/gui.yml` | GUI コンテナイメージ: パッケージレイヤとセッション用アセット |
| `files/system/**` | ホストイメージの `/` へコピー（skel dotfiles、systemd ユニット、`hyprtomic-gui-shell`、SDDM アセット、ujust レシピ） |
| `files/scripts/**` | ホストのビルド時スクリプト |
| `files/gui-build/scripts/gui-*.sh` | GUI コンテナのビルドスクリプト（パッケージレイヤごと） |
| `files/gui/**` | GUI コンテナの `/` へコピー（セッション起動スクリプト、dconf など） |
| `AGENTS.md` | アーキテクチャ、dotfiles の統合契約、テーマの流れ、変更ルール |

`docs/` と `opencode.json(c)` は意図的に gitignore しています。

## 検証

イメージは [Sigstore](https://www.sigstore.dev/) の [cosign](https://github.com/sigstore/cosign) で署名されています。このリポジトリの `cosign.pub` を使って確認できます:

```bash
cosign verify --key cosign.pub ghcr.io/j7b3y/fedora-hyprtomic
cosign verify --key cosign.pub ghcr.io/j7b3y/hyprtomic-gui
```

## 注意事項

- **Chromium / Electron 系 flatpak の日本語フォント**: flatpak ≥ 1.18 ではホストのフォントがキャッシュ経由でしか見えず、同梱の新しい fontconfig がそれを読めないため日本語が豆腐になります。`hyprtomic-flatpak-fonts` がアプリごとの fontconfig を書き換えて修正します（セッション開始時に自動実行、`ujust fix-flatpak-fonts` で再実行）。該当アプリは再起動してください。Firefox は影響を受けません。
- **Flatpak のバックグラウンド / 自動起動**: Background ポータルは GNOME のバックエンド（`xdg-desktop-portal-gnome`）を Background 専用で使っています（Hyprland/GTK のバックエンドは未実装のため）。GNOME シェルが無いので「バックグラウンドで動いているアプリの監視（強制終了・通知）」だけは無効です。自動起動の登録は `~/.config/autostart` に書かれ、ログイン時に `dex -a` が実行します（`/etc/xdg/autostart` の GNOME/XFCE アプレットは対象外）。
- **Flatpak 版 Discord クライアントの Rich Presence**: サンドボックスから他プロセスは見えないため、プロセス走査によるプレゼンス検出はできません（Discord Game SDK を使うゲームのみ対応）。`hyprtomic-gui-shell` がログイン時に `$XDG_RUNTIME_DIR/discord-ipc-0` を Vesktop のソケットへリンクし、flatpak 全体へ必要な override（`xdg-run/discord-ipc-0` とクライアントのランタイムディレクトリ）を付与します。反映には再ログインと、ゲーム／Steam の再起動が必要です。
- **Bitwarden（flatpak）の「システム認証でのロック解除」**: Flatpak では Bitwarden が polkit ポリシーを自動セットアップできないため、必要なアクション（`com.bitwarden.Bitwarden.unlock`）をホストイメージに同梱しています。Bitwarden の 設定 → セキュリティ → 「Unlock with system authentication」をオンにすると、ロック解除時に polkit エージェント（hyprpolkitagent）が認証を求めます。初回（アプリ起動後）はマスターパスワードまたは PIN でのロック解除が必要です。
- **テーマの到達範囲**: distrobox はホストの `/usr/share/{fonts,themes,icons}` を各コンテナに bind mount しますが、GUI コンテナだけに入れたアセットはホストや他コンテナからは見えません。Flatpak にはホストのフォントと per-app の `xdg-config` 権限しか渡らず、Kvantum/Qt テーマは配れません。
- **`local.conf` が唯一の逃げ道**: `/etc/skel` 由来のファイルを直接編集しないでください。`overwrite=1` の同期で置き換わります。

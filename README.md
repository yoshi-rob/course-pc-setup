# 授業用 Ubuntu 20.04.6 + ROS Noetic セットアップ

Windowsを残したまま、旧Ubuntuの領域へ授業用環境を入れ直すためのカスタムISOを作成します。
対象はIntel/AMDの64-bit PCです。ARMやApple Siliconには使用できません。

## インストール内容

- Ubuntu 20.04.6をベースにしたUbuntu Desktop、日本語ロケール・日本語キーボード・Mozc
- ROS Noetic desktop-full（Gazebo、RVizを含む）、rosdep、catkin-tools、catkinワークスペース
- VS Code（Microsoft公式APTリポジトリの安定版）、Terminator
- Git、C/C++ビルドツール、CMake、Python 3、pip
- タイムゾーン Asia/Tokyo、PCごとに異なる `course-xxxxxxxx` ホスト名
- 共通ユーザー `student`、共通パスワード `hogehoge`（sudo権限あり）。SSHサーバーは追加しません。

授業資料や課題コードは含めません。Ubuntu標準パッケージとROSパッケージをネットから取得するため、インストール時はインターネット接続が必要です。
共通パスワードはこの公開リポジトリで意図的に管理しています。

## ISOの作成

Ubuntu上で `xorriso curl openssl gnupg python3-yaml ubuntu-keyring` を用意します。
今回の作業PCではsudoがパスワードを要求するため、作成ツールを `tools/local/` へ展開して使用しています。ホストOSにDesktopやROSをインストールしません。

```bash
mkdir -p downloads
curl -fL --retry 3 https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso -o downloads/ubuntu-20.04.6-live-server-amd64.iso
curl -fsSL https://releases.ubuntu.com/20.04.6/SHA256SUMS -o downloads/SHA256SUMS
curl -fsSL https://releases.ubuntu.com/20.04.6/SHA256SUMS.gpg -o downloads/SHA256SUMS.gpg
./build.sh
```

先に変更した `setup.sh` をコミットしてGitHubへpushしてください。`build.sh` はHEADのコミットを固定し、GitHubから実際に取得できることとローカルとの一致を確認します。
特定版を使う場合は `SETUP_REF=<40桁のコミットSHA> ./build.sh` とします。そのコミットの `setup.sh` と作業コピーが一致する必要があります。

出力は `course-ubuntu-20.04.iso` と `course-ubuntu-20.04.iso.sha256` です。
元ISOの署名とSHA256を確認し、UEFI（GRUB）とBIOS（ISOLINUX）の両方の起動設定を変更します。
元のハイブリッドブート構造を `-boot_image any replay` で引き継ぎ、媒体検査用 `md5sum.txt` も更新します。
`nocloud/user-data` と `meta-data` はビルド時に生成します。ストレージ・ネットワークの自動構成は指定していません。

作業時の検証範囲と結果は [VALIDATION.md](VALIDATION.md) を参照してください。

VS Codeは署名鍵を限定したMicrosoft公式APTリポジトリから `code` をインストールします。TerminatorはUbuntuの `terminator` パッケージです。VS Codeの拡張機能はまだ自動追加していません。[MicrosoftのLinuxインストール手順](https://code.visualstudio.com/docs/setup/linux)

## 学生PCでの操作

1. 必要なデータをバックアップし、BitLockerを使用している場合は回復キーを確保します。Windowsを初期化する場合は先にWindows側で行います。
2. カスタムISOを書き込んだUSBから **UEFI** で起動し、`Install Course Ubuntu 20.04` を選びます。
3. ネットワーク設定画面で有線LANまたはWi-Fiを設定します。Wi-Fiの対応はPCの無線チップとドライバーによります。有線LAN/対応USB LANを代替手段にしてください。
4. Storage画面で **Custom storage layout（手動）** を選びます。「ディスク全体を使う」は選びません。
5. WindowsのNTFS、Microsoft Reserved、Recovery、既存EFIパーティションを残します。**既存EFIは削除・フォーマットしません。** `/boot/efi` として再利用します。
6. 旧Ubuntuの領域を実際の内容とサイズで確認し、その領域だけを置き換えてext4の `/` を作成します。番号だけで判断しないでください。対象が不明ならここで止めます。
7. 書き込み内容を確認してインストールを開始します。その後DesktopとROSの設定が自動で続きます。大量のパッケージをダウンロードするため、回線によって時間がかかります。
8. 成功後に再起動し、USBを抜いて `student` / `hogehoge` でログインします。Windowsも起動することを確認します。

WindowsのGRUB表示はos-proberの検出に依存します。表示されない場合はUEFI起動メニューのWindows Boot Managerで起動を確認し、Ubuntu上で `sudo update-grub` を実行してください。
この方式はパーティション選択を自動判定しません。Windowsを残せるかは手動設定の内容で決まります。

## ログと成功確認

- ISO作成：`logs/build.log`
- この作業セッションの全コマンド・出力：`logs/setup-*.log`（ローカル保存、GitHubには公開しません）
- インストール先でのコマンド・出力：`/var/log/course-setup.log`
- インストーラのログ：`/var/log/installer/`
- 全セットアップ成功時だけ作成：`/var/lib/course-setup/complete`

```bash
test -f /var/lib/course-setup/complete
source /opt/ros/noetic/setup.bash
rosversion -d                 # noetic
cd ~/catkin_ws && catkin_make
```

失敗時はインストーラがエラー停止し、成功マーカーは作成しません。ログで原因を直した後、インストーラのシェルから `curtin in-target --target=/target -- bash /opt/course-setup/setup.sh` を再実行できます。

## 添付案から修正した点・参照先

- ROS最終スナップショットの署名鍵は通常の `rosdistro/master/ros.key` とは異なります。[Open Roboticsの公式Dockerfile](https://github.com/osrf/docker_images/blob/master/ros/noetic/ubuntu/focal/ros-core/Dockerfile) と同じ専用鍵 `4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA` を同梱します。現在の有効期限は2027-06-01で、以後は鍵更新と再ビルドが必要です。
- 作業時にスナップショットのHTTPS証明書でホスト名不一致を確認しました。公式Dockerfileと同じHTTP配信を利用し、APTの署名・パッケージハッシュ検証を維持しています。TLS/署名検証を無効にしません。
- curtinのchrootではsystemdが動かないため、`timedatectl` / `hostnamectl` ではなく設定ファイルを更新します。
- このインストーラではidentityユーザーの作成が初回起動まで遅れるため、late-commands内でstudentユーザーがなければ作成します。rosdepやcatkinの設定はそのユーザーで実行します。
- EOLのNoeticをrosdepに読み込ませるため `--include-eol-distros --rosdistro=noetic` を指定します。
- Desktopでネットワーク設定を使えるよう、インストーラで作成したnetplanをNetworkManagerへ引き継ぎます。
- GitHubの可変mainではなく、ISO作成時のコミットとSHA256で `setup.sh` を固定します。
- 仮想インストールで、Focalの更新処理がUbuntu Pro関連の設定ファイル確認を理由に停止することを確認しました。APTに `--force-confdef` / `--force-confold` を指定して既存設定を保持し、確認画面を出さずに更新します。旧curtinが一時的にAPT設定を削除するため、インストール中のsystemd一時サービスに `APT_CONFIG` を設定し、ISO内の `installer-apt.conf` を参照させます。late-commands開始時とエラー時にこの環境変数を解除します。更新自体は有効のままです。

参照：[Ubuntu公式ISO](https://releases.ubuntu.com/20.04.6/)、[Autoinstall設定](https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html)、[NoCloud](https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html)、[ROSスナップショット鍵更新](https://discourse.ros.org/t/ros-signing-key-migration-guide/43937?page=2)。
Ubuntu 20.04の標準サポートとROS Noeticのサポートは終了しています。この版を授業互換性のために使用します。[ROS公式EOL告知](https://discourse.ros.org/t/ros-noetic-end-of-life-may-31-2025/43160)

USBへの書き込みは今回の作業対象外です。USBを接続後、対象ディスクを確認してから別途行います。

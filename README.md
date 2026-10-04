# 授業用 Ubuntu セットアップ

学生PCに Ubuntu 20.04.6 と ROS Noetic の授業環境を導入するカスタムISOです。
Intel/AMDの64-bit PCを対象とし、ネットワークとインストール先の領域を手動で選択した後、授業環境を自動セットアップします。インストール時はインターネット接続が必要です。

## 環境構成

| 項目 | 内容 |
| --- | --- |
| OS | Ubuntu 20.04.6、Ubuntu Desktop |
| カーネル | HWE 5.15系（linux-generic-hwe-20.04）、標準の起動先 |
| 表示倍率 | 100% |
| 言語・入力 | 日本語、日本語キーボード、標準入力方式は日本語（Mozc） |
| ROS | Noetic desktop-full（RViz・Gazebo）、rosdep、catkin-tools |
| 機器ドライバ | ros-noetic-ypspur、ros-noetic-urg-node、ros-noetic-joy |
| 開発環境 | VS Code、Terminator、Git、C/C++ビルドツール、CMake、Python 3、pip |
| ワークスペース | /home/student1/coins_ws |
| ユーザー名・表示名 | student1（sudo権限あり） |
| パスワード | student1 |
| タイムゾーン | Asia/Tokyo |
| ホスト名 | PCごとに異なる course-xxxxxxxx |

VS Code・Terminator・設定をドックのお気に入りに登録します。

授業資料1のワークスペースのソースをISOに同梱し、学生ユーザーの所有で展開・ビルドします。
coins_ex・ypspur_ros、起動設定、機体パラメータ、RViz設定を含みます。
授業PDFと他の回の課題コードは同梱対象外です。

.bashrcに以下を設定し、新しいターミナルでROSと授業ワークスペースを利用できます。

```bash
source /opt/ros/noetic/setup.bash
source ~/coins_ws/devel/setup.bash
```

## セットアップの更新

インストール時にGitHubのmainブランチから最新コミットを取得し、そのコミットのsetup.shを実行します。
お気に入りやインストール項目はsetup.shを変更してmainへpushすると、同じUSBで次にインストールするPCに反映されます。
実行したコミットとスクリプトのSHA256をインストール先に記録します。

授業ソース・署名鍵・ユーザー設定などISOに同梱する内容の変更には、ISOの再作成とUSBへの再書き込みが必要です。
インストール済みPCは自動更新されません。

## ISOの作成

Ubuntu上で xorriso、curl、openssl、gnupg、python3-yaml、ubuntu-keyring を用意します。

1. 同梱する授業用ソースをlocal-assets/coins_ws/srcに配置し、アーカイブを作成します。

   ```bash
   python3 tools/prepare_workspace.py
   ```

   ソースをそのままアーカイブ化し、学生PCでbuild・develを生成します。
   コード本体はlocal-assets/に保存され、Gitの対象外です。

2. mainに使用するsetup.shを公開し、course-workspace.sha256と同梱ソースのSHA256が一致することを確認します。

   ビルド時に同梱ソースのSHA256を検証します。setup.shはインストール時に取得します。

3. Ubuntu公式ISOと検証用ファイルを取得し、ビルドします。

   ```bash
   mkdir -p downloads
   curl -fL --retry 3 https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso -o downloads/ubuntu-20.04.6-live-server-amd64.iso
   curl -fsSL https://releases.ubuntu.com/20.04.6/SHA256SUMS -o downloads/SHA256SUMS
   curl -fsSL https://releases.ubuntu.com/20.04.6/SHA256SUMS.gpg -o downloads/SHA256SUMS.gpg
   ./build.sh
   ```

出力は course-ubuntu-20.04.iso と course-ubuntu-20.04.iso.sha256 です。
元ISOの署名・SHA256を検証し、BIOS・UEFIの起動に対応するISOを作成します。

## 学生PCへのインストール

1. 必要なデータをバックアップします。BitLockerを使用している場合は回復キーを確保します。
2. ISOを書き込んだUSBからUEFIで起動し、Install Course Ubuntu 20.04を選びます。
3. 有線LANまたはWi-Fiを設定します。
4. Storage画面でCustom storage layout（手動）を選択します。
5. Windowsの領域と既存EFIパーティションを保持し、Ubuntu用の領域にext4の / を設定します。既存EFIはフォーマットせず、/boot/efiとして再利用します。
6. 書き込み内容を確認し、インストールを開始します。Desktop・ROS・授業ワークスペースの設定が自動で進みます。
7. 再起動後、USBを抜き、student1 / student1でログインします。Windowsを残す場合はWindowsの起動も確認します。

Wi-Fiの利用可否はPCの無線チップとドライバに依存します。
WindowsがGRUBに表示されない場合は、UEFI起動メニューのWindows Boot Managerから起動できます。

## ログと動作確認

| 保存先 | 内容 |
| --- | --- |
| logs/build.log | ISO作成ログ |
| logs/setup-*.log | 作業コマンド・出力 |
| /var/log/course-setup.log | インストール先のセットアップログ |
| /var/log/installer/ | インストーラのログ |
| /opt/course-setup/setup-ref.txt | 実行したsetup.shのコミット |
| /opt/course-setup/setup.sh.sha256 | 実行したsetup.shのSHA256 |
| /var/lib/course-setup/complete | セットアップの完了日時 |

作業ログと検証記録はローカルに保存し、Gitの対象外です。

学生PCのターミナルで確認できます。

```bash
test -f /var/lib/course-setup/complete
rosversion -d
rospack find coins_ex
rospack find ypspur_ros
```

rosversion -dはnoetic、各パッケージの場所は/home/student1/coins_ws/src以下になります。
機器の利用時は、USBデバイス名とアクセス権を実機で確認してください。

# USB書き込み前の準備・検証結果
作業日: 2026-10-04（Asia/Tokyo）

USBへの書き込み前まで準備しました。物理USB・学生PCのディスクには書き込んでいません。
公開リポジトリ: https://github.com/yoshi-rob/course-pc-setup

## 作成物
- カスタムISO: `course-ubuntu-20.04.iso`（約1.4 GiB）
- ISO SHA256: `ac55fb316c06e3f9db16ca29ed27235055c29ac45f0b24092f72cd1b6733938b`
- ISOが取得するsetup.shの固定コミット: `4b86a4d99825ecc55b04c7d158e350db4d302c45`
- setup.sh SHA256: `bed7c96ed30178bede5cda03c0452f8e28f977768ea6cc5ab5f5f8553f5be67c`
- ログイン: `student` / `hogehoge`
- インターネット接続が必要です。DesktopやROSのパッケージはインストール時に取得します。
- ネットワークとストレージは手動設定、その後の授業環境セットアップは自動です。

## 検証結果
| 検証 | 結果 |
| --- | --- |
| Ubuntu公式ISOの署名・SHA256 | 合格 |
| 最終ISOのSHA256・媒体チェック374項目 | 合格 |
| BIOS起動・UEFI起動・仮想USBのUEFI起動 | 起動し、手動ネットワーク・ストレージ画面を確認 |
| FocalのOSインストール・自動更新 | 仮想ディスクで成功 |
| Ubuntu Desktop・日本語・Mozc・ROS desktop-full | 仮想PC内でインストール済みを確認 |
| rosdep Noeticキャッシュ更新 | 成功 |
| 学生ユーザーによるcatkin初回ビルド | 修正後成功 |
| インストール済みディスクのみでUEFI起動 | 成功 |
| student / hogehogeで日本語デスクトップへログイン | 成功 |
| 初回cloud-init | status: done |
| 初回起動後のROS・rosdep・catkin | noetic、rosdep resolve roscpp、catkin_makeが成功 |
| NetworkManager・display-manager | active |
| ロケール・タイムゾーン・固有ホスト名 | ja_JP.UTF-8、Asia/Tokyo、course-ddafdf79を確認 |

検証は段階に分けて実施しました。OSインストール後のスクリプト検証で不具合を修正し、同じ仮想PCの/target内へ当時の修正版setup.shを取得して、curtin in-targetから手動で再実行しました。今回のVS Code・Terminator追加版は、起動済みUbuntu 20.04仮想PCでsetup.sh全体を再実行しました。ISO内の指定SHA256と実行したsetup.shの一致を確認しています。**最終ISOを空のディスクから最後まで一度も中断せずにインストールする再試験は未実施**です。

## 実際の検証で修正した問題
- Ubuntu Pro関連の設定ファイル確認で自動更新が停止: ISO内のAPT設定をsystemd一時サービスへ渡して解消。
- identityユーザーが初回起動まで作成されない: late-commands内でstudentを作成。
- catkin_wsの親ディレクトリがroot所有になる: ワークスペース本体とsrcにstudent所有を指定。
- 添付案のROS署名鍵とrosdepのEOL対応、chroot内の時刻・ホスト名設定も修正。

GRUB更新時には仮想USBの/dev/sda1に対するgrub-probe警告が残りましたが、update-grubは成功し、その後のディスク単体UEFI起動を確認しました。Windowsの検出・起動は実機で確認してください。

## ログ
ローカルの `logs/` に保存してあり、GitHubには公開しません。
- `logs/setup-20261004-025025.log`: 実行コマンド・出力の作業記録（失敗した試行・修正も含む）
- `logs/build.log`: ISO作成ログ
- `logs/vm-course-setup.log`: 仮想PC内のセットアップログ
- `logs/vm-postboot.log`: 初回起動後の検証コマンド・出力
- `logs/final-media-checksums.log`: 最終ISOの374項目の検査結果
- `logs/vm-desktop-login.png`: 日本語デスクトップのログイン確認画像
- `logs/target-config/`: 検証したターゲット設定
- `logs/first-attempt/`、`logs/second-attempt/`: 初期試行の記録

作業PCのOSへDesktopやROSはインストールしていません。ISO作成・仮想試験用のツールは `tools/local/` に展開しています。

## USB接続後
README.mdの手順に従ってください。USBの実デバイスを確認してから書き込みます。
学生PCでは旧Ubuntu領域を手動で選び、Windowsと既存EFI領域を保持します。実機の無線LAN、Secure Boot、Windowsの起動は未検証です。

## VS Code・Terminator追加版の検証（2026-10-04 10時台）
- Microsoftの署名付きAPTリポジトリからcode 1.140.0-1790759618をインストール。追加APTソースはcourse-vscode.listに一本化。
- Ubuntuからterminator 1.91-4ubuntu1をインストール。
- setup.sh全体が成功し、rosdep・catkin・ROS Noeticの確認も成功。
- studentで両アプリのGUI起動とバージョン表示を確認。
- 追加版ISOのSHA256と媒体チェック374項目が成功。新規ディスクからの通しインストールは未実施。
- ログ: logs/vm-editors-setup.log、logs/editors-media-checksums.log、logs/vm-vscode.png、logs/vm-editors-final.png。文字コンソールでのTerminator確認はDISPLAYがないため失敗し、デスクトップ上で再確認しました。
- GDB・htop・tmuxは既にインストール済み。python3-venv・Meld・VS Code拡張機能は追加候補で、今回は追加していません。

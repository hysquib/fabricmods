# fabricmods · Fabric 1.21.1 模组同步器

玩家选择 PCL 实例的 mods 文件夹，即可按服主发布的清单下载缺少的模组、替换旧版。需要 64 位 Windows 和 Windows PowerShell 5.1。
本仓库为私有仓库。服主可将整个 Client 文件夹压缩后发给朋友，玩家解压即可从下面第 2 步开始。下载模组的 HTTPS 地址需要能在玩家电脑上直接打开。

## 从下载站安装（推荐）

打开服主提供的 Pages 网址，下载 ZIP，完整解压后运行 ModSync.exe。站点下载包内含 server.txt，玩家无需登录 GitHub。每次向 main 的 data/mods 提交模组后，Pages 工作流会生成清单、下载包和网页。首次启用时在 Settings → Pages 选择 GitHub Actions。绑定自定义域名后重新运行 Publish mod download site，以更新下载包内的网址。

## 从源码仓库直接运行

1. 在仓库首页点 **Code → Download ZIP**，完整解压。关闭 Minecraft。
2. 双击 Client/ModSync.exe，保持 Sync.ps1 与它同目录。
3. 选择正在玩的 Fabric 1.21.1 实例里的 mods 文件夹。如果 PCL 开了版本隔离，路径通常类似 .minecraft/versions/实例名称/mods。
4. 默认数据源是本仓库 main 分支的 data/mods。同步器先在临时目录下载有变化的文件，检查 Fabric ID 和 Git 文件哈希，再显示安装和备份预览。确认后更新游戏目录。
5. 本仓库为私有。玩家需要自己的仓库读取权限；在 Windows 安装 GitHub CLI，首次使用前运行 `gh auth login --hostname github.com` 并登录有权限的账号。已设置只读 GH_TOKEN 的用户也可直接运行。请勿把令牌随客户端分发。
6. 以后每次更新重新运行即可。若提示数据源为空，表示服主尚未放入模组。

## 服主发布

在 [data/mods](data/mods/) 放入可分发的 Fabric 1.21.1 客户端 JAR 及依赖。同一 ID 仅保留一个版本，将旧版移除和新版加入一起提交到 main。仓库中的文件就是发布版本，无需生成清单。服务端专用模组请勿放入。客户端只扫描该目录第一层。

如沿用原有 HTTPS 清单，请在 Client/server.txt 写入 manifest.json 完整网址，该配置优先于 GitHub。publish.py 仍可用于生成这种清单。

## 备份、恢复和排错

- 程序用 Fabric ID 匹配同一模组，用 SHA-256 判断文件内容。清单之外的独立模组会保留。
- 旧版备份在所选 mods 文件夹中的 .sync-随机标识/backup。需要恢复时，先关闭游戏，移走本次新增的 JAR，再把旧 JAR 复制回 mods。
- 出现同名文件 ID 冲突时，检查本地同名 JAR 是否为另一个模组。下载校验失败时，核对站点上的 JAR 和清单是否来自同一次发布。
- 本仓库提供同步工具。服主需自行发布模组清单。当前版本已用样例验证清单生成，Windows 图形界面及真实服务器同步尚待实机验证。

# fabricmods · Fabric 1.21.1 模组同步器

玩家选择 PCL 实例的 mods 文件夹，即可按服主发布的清单下载缺少的模组、替换旧版。需要 64 位 Windows 和 Windows PowerShell 5.1。
本仓库为私有仓库。服主可将整个 Client 文件夹压缩后发给朋友，玩家解压即可从下面第 2 步开始。下载模组的 HTTPS 地址需要能在玩家电脑上直接打开。

## 玩家第一次使用

1. 在仓库首页点 **Code → Download ZIP**，完整解压。关闭 Minecraft。
2. 双击 Client/ModSync.exe，保持 Sync.ps1 与它同目录。
3. 选择正在玩的 Fabric 1.21.1 实例里的 mods 文件夹。如果 PCL 开了版本隔离，路径通常类似 .minecraft/versions/实例名称/mods。
4. 若出现地址输入框，粘贴服主给的 manifest.json 完整网址。
5. 核对下载和备份列表，点 Yes。看到同步完成后，通过 PCL 启动原来的实例。以后服主更新模组时，再运行一次。

## 服主发布模组

1. 安装 Python 3.8 或更高版本，在 publish.py 旁创建 client-mods 文件夹。放入玩家需要的 Fabric 1.21.1 JAR 和依赖。程序跳过带 server 专用标记的模组，其他文件请服主自行核对。
2. 在仓库根目录打开终端运行：
   ```sh
   python publish.py client-mods release-001
   ```
3. 将 release-001 里的 manifest.json 和所有 JAR 发布到同一个可直连的 HTTPS 目录。只发布允许再分发的模组。清单地址须能直接显示 JSON，每个 JAR 须能直接下载。
4. 把清单网址发给玩家，或将网址单独写一行保存为 Client/server.txt 后分发 Client 文件夹。玩家端无需安装 Python。
5. 更新时，在 client-mods 中用新版替换旧版，重新生成到新目录 release-002。若使用固定下载地址，先上传新版 JAR，最后替换该地址的 manifest.json，已有玩家即可沿用原地址。

## 备份、恢复和排错

- 程序用 Fabric ID 匹配同一模组，用 SHA-256 判断文件内容。清单之外的独立模组会保留。
- 旧版备份在所选 mods 文件夹中的 .sync-随机标识/backup。需要恢复时，先关闭游戏，移走本次新增的 JAR，再把旧 JAR 复制回 mods。
- 出现同名文件 ID 冲突时，检查本地同名 JAR 是否为另一个模组。下载校验失败时，核对站点上的 JAR 和清单是否来自同一次发布。
- 本仓库提供同步工具。服主需自行发布模组清单。当前版本已用样例验证清单生成，Windows 图形界面及真实服务器同步尚待实机验证。

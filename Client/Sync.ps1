$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,Microsoft.VisualBasic,System.IO.Compression.FileSystem
function Message($s){[void][Windows.Forms.MessageBox]::Show($s,'Fabric 模组同步')}
function ModId($path){
 $z=[IO.Compression.ZipFile]::OpenRead($path)
 try{
  $e=$z.GetEntry('fabric.mod.json')
  if($e){$r=[IO.StreamReader]::new($e.Open());try{return (($r.ReadToEnd()|ConvertFrom-Json).id)}finally{$r.Dispose()}}
 }finally{$z.Dispose()}
}
function GitBlobHash($path){
 $stream=[IO.File]::OpenRead($path)
 $hash=[Security.Cryptography.SHA1]::Create()
 try{
  $header=[Text.Encoding]::ASCII.GetBytes("blob $($stream.Length)$([char]0)")
  [void]$hash.TransformBlock($header,0,$header.Length,$header,0)
  $buf=New-Object byte[] 65536
  while(($count=$stream.Read($buf,0,$buf.Length)) -gt 0){[void]$hash.TransformBlock($buf,0,$count,$buf,0)}
  [void]$hash.TransformFinalBlock($buf,0,0)
  return [BitConverter]::ToString($hash.Hash).Replace('-','')
 }finally{$stream.Dispose();$hash.Dispose()}
}
function GitHubMods($directory,$cache){
 $api='https://api.github.com/repos/hysquib/fabricmods'
 $headers=@{'User-Agent'='FabricModSync';Accept='application/vnd.github+json'}
 $token=$env:GH_TOKEN
 if(!$token -and (Get-Command gh.exe -ErrorAction SilentlyContinue)){
  $token=(& gh.exe auth token --hostname github.com 2>$null)
 }
 if($token){$headers.Authorization="Bearer $token"}
 try{$entries=Invoke-RestMethod "$api/contents/data/mods?ref=main" -Headers $headers}
 catch{throw "无法读取 GitHub 数据源。私有仓库需要有读取权限的账号，请安装 GitHub CLI 并运行 gh auth login，或设置 GH_TOKEN。详情：$($_.Exception.Message)"}
 if($entries.Count -ge 1000){throw '数据源目录达到列表上限，请减少目录条目。'}
 $headers.Accept='application/vnd.github.raw+json'
 foreach($item in $entries){
  if($item.type -ne 'file' -or $item.name -notlike '*.jar'){continue}
  if($item.sha -notmatch '^[a-f0-9]{40}$' -or $item.name -notmatch '^[a-z0-9_+()\[\]. -]+\.jar$' -or $item.name -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])\.'){throw "数据源文件无效：$($item.name)"}
  $p=Join-Path $directory $item.name
  if(!(Test-Path -LiteralPath $p -PathType Leaf) -or (GitBlobHash $p) -ne $item.sha){
   $p=Join-Path $cache $item.name
   Invoke-WebRequest -UseBasicParsing "$api/git/blobs/$($item.sha)" -Headers $headers -OutFile $p
   if((GitBlobHash $p) -ne $item.sha){throw "GitHub 文件校验失败：$($item.name)"}
  }
  $id=ModId $p
  if(!$id){throw "缺少 Fabric 元数据：$($item.name)"}
  [pscustomobject]@{id=$id;name=$item.name;sha256=(Get-FileHash -LiteralPath $p).Hash;source=$p}
 }
}
$cache=$null
try{
 $f=New-Object Windows.Forms.FolderBrowserDialog
 $f.Description='选择 PCL 中 Fabric 1.21.1 实例的 mods 文件夹'
 if($f.ShowDialog() -ne 'OK'){return}
 $d=$f.SelectedPath
 if((Split-Path $d -Leaf) -ne 'mods'){throw '请选择名为 mods 的文件夹'}
 $cfg=Join-Path $PSScriptRoot 'server.txt'
 $addr=if(Test-Path $cfg){(Get-Content $cfg -Encoding UTF8 -Raw).Trim()}else{''}
 if($addr){
  $base=[uri]$addr
  if($base.Scheme -notin 'http','https'){throw '清单地址需要 HTTP 或 HTTPS'}
 }
 $lock=[IO.File]::Open((Join-Path $d '.fabric-sync.lock'),'OpenOrCreate','ReadWrite','None')
 try{
 if($addr){$manifest=Invoke-RestMethod -Uri $base}
 else{
  $cache=Join-Path ([IO.Path]::GetTempPath()) ('fabricmods-'+[guid]::NewGuid())
  [void][IO.Directory]::CreateDirectory($cache)
  $manifest=@{format=1;mods=@(GitHubMods $d $cache)}
  if(!$manifest.mods){Message 'GitHub 的 data/mods 里还没有模组。';return}
 }
 if($manifest.format -eq 1 -and $null -ne $manifest.mods -and $manifest.mods.Count -eq 0){Message '服主尚未发布模组。';return}
 if($manifest.format -ne 1 -or !$manifest.mods){throw '清单为空或格式错误'}
 $ids=@{};$names=@{};$fetch=@();$old=@()
 foreach($m in $manifest.mods){
 $n=[string]$m.name
 if($n -notmatch '^[a-z0-9_+()\[\]. -]+\.jar$' -or $n -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])\.' -or $m.sha256 -notmatch '^[a-f0-9]{64}$' -or $m.id -cnotmatch '^[a-z][a-z0-9_-]+$' -or $ids.ContainsKey($m.id) -or $names.ContainsKey($n)){throw "清单条目无效或重复：$n"}
 $ids[$m.id]=$m;$names[$n]=$m
 $p=Join-Path $d $n
 if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p).Hash -ne $m.sha256){$fetch+=$m}
 }
 foreach($j in Get-ChildItem -LiteralPath $d -Filter '*.jar' -File){
 $id=ModId $j.FullName
 if($names.ContainsKey($j.Name)){
 if($names[$j.Name] -in $fetch){if($id -ne $names[$j.Name].id){throw "同名文件 ID 冲突：$($j.Name)"};$old+=$j}
 }elseif($id -and $ids.ContainsKey($id)){$old+=$j}
 }
 if(!$fetch -and !$old){Message '模组已与服务器清单一致。';return}
 $preview=(@($fetch|ForEach-Object{"下载  $($_.name)"})+@($old|ForEach-Object{"备份  $($_.Name)"})) -join [Environment]::NewLine
 if([Windows.Forms.MessageBox]::Show("$preview`n`n关闭游戏后，确认同步？",'同步预览','YesNo') -ne 'Yes'){return}
 $work=Join-Path $d ('.sync-'+[guid]::NewGuid())
 $backup=Join-Path $work 'backup'
 [void][IO.Directory]::CreateDirectory($backup)
 $moved=@();$added=@()
 try{
 foreach($m in $fetch){
 $p=Join-Path $work $m.name
 if(!$addr){[IO.File]::Copy($m.source,$p)}else{Invoke-WebRequest -UseBasicParsing -Uri ([uri]::new($base,[uri]::EscapeDataString($m.name))) -OutFile $p}
 if((Get-FileHash -LiteralPath $p).Hash -ne $m.sha256 -or (ModId $p) -ne $m.id){throw "下载校验失败：$($m.name)"}
 }
 foreach($j in $old){[IO.File]::Move($j.FullName,(Join-Path $backup $j.Name));$moved+=$j}
 foreach($m in $fetch){$dest=Join-Path $d $m.name;[IO.File]::Move((Join-Path $work $m.name),$dest);$added+=$dest}
 }catch{
 foreach($p in $added){[IO.File]::Delete($p)}
 foreach($j in $moved){[IO.File]::Move((Join-Path $backup $j.Name),$j.FullName)}
 throw
 }
 Message "同步完成。下载 $($fetch.Count) 个，备份 $($old.Count) 个。`n$backup"
 }finally{$lock.Dispose()}
}catch{Message ("同步失败："+$_.Exception.Message)}finally{if($cache -and [IO.Directory]::Exists($cache)){[IO.Directory]::Delete($cache,$true)}}

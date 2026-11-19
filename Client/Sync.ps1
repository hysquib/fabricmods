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
try{
 $f=New-Object Windows.Forms.FolderBrowserDialog
 $f.Description='选择 PCL 中 Fabric 1.21.1 实例的 mods 文件夹'
 if($f.ShowDialog() -ne 'OK'){return}
 $d=$f.SelectedPath
 if((Split-Path $d -Leaf) -ne 'mods'){throw '请选择名为 mods 的文件夹'}
 $cfg=Join-Path $PSScriptRoot 'server.txt'
 $addr=if(Test-Path $cfg){(Get-Content $cfg -Encoding UTF8 -Raw).Trim()}else{''}
 if(!$addr){$addr=[Microsoft.VisualBasic.Interaction]::InputBox('输入服主提供的 manifest.json 完整地址','连接服务器')}
 if(!$addr){return}
 $base=[uri]$addr
 if($base.Scheme -notin 'http','https'){throw '清单地址需要 HTTP 或 HTTPS'}
 $lock=[IO.File]::Open((Join-Path $d '.fabric-sync.lock'),'OpenOrCreate','ReadWrite','None')
 try{
 $manifest=Invoke-RestMethod -Uri $base
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
 Invoke-WebRequest -UseBasicParsing -Uri ([uri]::new($base,[uri]::EscapeDataString($m.name))) -OutFile $p
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
}catch{Message ("同步失败："+$_.Exception.Message)}

"""Run on a trusted computer with Python 3.8+."""
import hashlib,json,pathlib,shutil,sys,zipfile,re,tempfile,os
src,out=map(pathlib.Path,sys.argv[1:])
if out.exists(): sys.exit("Choose a new output directory for each release.")
out.parent.mkdir(parents=True,exist_ok=True)
mods=[]
seen=set()
names=set()
with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
    stage=pathlib.Path(tmp)/"release"
    stage.mkdir()
    for jar in sorted(src.glob("*.jar")):
        with zipfile.ZipFile(jar) as z:
            if "fabric.mod.json" not in z.namelist(): continue
            meta=json.loads(z.read("fabric.mod.json"))
        if meta.get("environment")=="server": continue
        key=meta["id"]
        name=jar.name
        if (key in seen or name.lower() in names or not re.fullmatch(r"[a-z][a-z0-9_-]+",key)
            or not re.fullmatch(r"[a-zA-Z0-9_+()\[\]. -]+\.jar",name)
            or re.match(r"(con|aux|prn|nul|com\d|lpt\d)\.",name,re.I)):
            sys.exit("Duplicate ID or unsupported filename: "+name)
        seen.add(key);names.add(name.lower())
        target=stage/name
        shutil.copyfile(jar,target)
        mods.append(dict(id=key,name=name,sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    if not mods: sys.exit("No client-compatible Fabric JARs found.")
    (stage/"manifest.json").write_text(json.dumps(dict(format=1,mods=mods),indent=2),encoding="utf8")
    os.rename(stage,out)
print(out, len(mods),"mods")

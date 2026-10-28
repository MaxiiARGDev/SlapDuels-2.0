"""Read-only Rojo 7.7 localhost tree audit. No sync/write endpoint, third-party packages or Studio execution."""
import json
import struct
import urllib.request
import pathlib
import hashlib
import argparse

def unpack(data):
    pos = 0
    def take(n):
        nonlocal pos
        value = data[pos:pos+n]
        pos += n
        return value
    def number(fmt):
        return struct.unpack(">" + fmt, take(struct.calcsize(">" + fmt)))[0]
    def read():
        marker = number("B")
        if marker <= 0x7f: return marker
        if marker >= 0xe0: return marker - 256
        if 0xa0 <= marker <= 0xbf: return take(marker & 31).decode("utf-8")
        if 0x90 <= marker <= 0x9f: return [read() for _ in range(marker & 15)]
        if 0x80 <= marker <= 0x8f: return {read(): read() for _ in range(marker & 15)}
        if marker == 0xc0: return None
        if marker == 0xc2: return False
        if marker == 0xc3: return True
        formats = {0xca:"f",0xcb:"d",0xcc:"B",0xcd:"H",0xce:"I",0xcf:"Q",0xd0:"b",0xd1:"h",0xd2:"i",0xd3:"q"}
        if marker in formats: return number(formats[marker])
        lengths = {0xc4:"B",0xc5:"H",0xc6:"I",0xd9:"B",0xda:"H",0xdb:"I",0xdc:"H",0xdd:"I",0xde:"H",0xdf:"I"}
        if marker not in lengths: raise ValueError("Unsupported msgpack marker " + hex(marker))
        size = number(lengths[marker])
        if marker in (0xc4,0xc5,0xc6): return take(size).hex()
        if marker in (0xd9,0xda,0xdb): return take(size).decode("utf-8")
        if marker in (0xdc,0xdd): return [read() for _ in range(size)]
        return {read():read() for _ in range(size)}
    value = read()
    if pos != len(data): raise ValueError("Trailing bytes")
    return value

def get(base,path):
    if not base.startswith("http://127.0.0.1:"): raise ValueError("Localhost only")
    with urllib.request.urlopen(base+path,timeout=10) as response:
        return unpack(response.read())

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port",type=int,default=34872)
    arguments=parser.parse_args()
    base = "http://127.0.0.1:" + str(arguments.port)
    info = get(base,"/api/rojo")
    tree = get(base,"/api/read/"+info["rootInstanceId"])
    instances=tree["instances"]
    def instance_path(key):
        parts=[]
        node=instances[key]
        while node["Id"] != info["rootInstanceId"]:
            parts.insert(0,node["Name"])
            node=instances[node["Parent"]]
        return "/".join(parts)
    sources={}
    for key,node in instances.items():
        value=node.get("Properties",{}).get("Source")
        if isinstance(value,dict) and "String" in value:
            sources[instance_path(key)]=value["String"]
    repo=pathlib.Path(__file__).resolve().parents[2]
    comparison=[]
    for file in sorted((repo/"src").rglob("*.luau")):
        relative=file.relative_to(repo).as_posix()
        target=None
        for prefix,replacement in (("src/server/","ServerScriptService/"),("src/client/","StarterPlayer/StarterPlayerScripts/"),("src/shared/","ReplicatedStorage/Shared/"),("src/character/","StarterPlayer/StarterCharacterScripts/")):
            if relative.startswith(prefix):
                target=replacement+relative[len(prefix):]
                break
        if relative=="src/server/RagdollModule.luau": target="ServerStorage/RagdollModule.luau"
        if target is None: continue
        for suffix in (".server.luau",".client.luau",".luau"):
            if target.endswith(suffix):
                target=target[:-len(suffix)]
                break
        disk=file.read_text(encoding="utf-8",errors="replace").replace("\r\n","\n").rstrip()
        served=sources.get(target)
        normalized=served.replace("\r\n","\n").rstrip() if served is not None else None
        comparison.append({"File":relative,"Instance":target,"Present":served is not None,"Matches":disk==normalized,
                           "DiskSourceSHA256":hashlib.sha256(disk.encode()).hexdigest(),
                           "ServedSourceSHA256":hashlib.sha256(normalized.encode()).hexdigest() if normalized is not None else None})
    paths=[instance_path(key) for key in instances]
    duplicate_paths=sorted({path for path in paths if paths.count(path)>1})
    output={"Server":info,"InstanceCount":len(instances),"SourceCount":len(sources),
            "DuplicateInstancePaths":duplicate_paths,
            "AllNodesPreserveUnknown":all(node.get("Metadata",{}).get("ignoreUnknownInstances")==True for node in instances.values()),
            "Compared":len(comparison),"Matched":sum(x["Matches"] for x in comparison),
            "Differences":[x for x in comparison if not x["Matches"]],"Sources":comparison,
            "InstancePaths":sorted(instance_path(key) for key in instances if key!=info["rootInstanceId"])}
    filename="RojoSync.safe-audit.json" if arguments.port==34873 else "RojoSync.audit.json"
    (repo/"tests"/filename).write_text(json.dumps(output,indent=2),encoding="utf-8")
    print(json.dumps({k:v for k,v in output.items() if k not in ("Sources","InstancePaths")},ensure_ascii=False))

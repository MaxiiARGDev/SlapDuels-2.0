"""Offline validation only. Does not write Studio or replace physical resources."""
import hashlib,json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/PremiumShopV11'
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/PremiumShopV11.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8');checks[name]=p.returncode
 print(name,p.returncode,p.stdout.strip()[-200:],flush=True);assert p.returncode==0,name
for name,spec in [('unit','PremiumShopV11'),('batch','CrateBatchV24'),('reveal','CrateRevealV25'),('gallery','CrateBatchV24.gallery'),('cinematic','CrateCinematicV23'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/PremiumShopV11.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/PremiumShopV11.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:run(name,[rojo,'build',project,'-o',f'tests/PremiumShopV11.{name}.rbxlx'])
old=json.loads((backup/'src-hashes.before.json').read_text());changed=[]
for row in old:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
allowed={'src/client/Controllers/PremiumShopController.luau','src/server/PremiumShop/PremiumGrantPlan.luau','src/server/PremiumShop/PremiumProductRegistry.luau','src/server/PremiumShop/ReceiptCoordinator.luau','src/server/Services/PremiumShopService.luau','src/server/Services/CrateService.luau','src/server/Services/PlayerDataService.luau','src/shared/PremiumShop/Catalog/CoinPackages.luau','src/shared/PremiumShop/Catalog/PremiumCombos.luau','src/shared/PremiumShop/Catalog/PremiumCrates.luau'}
assert set(changed)==allowed,changed
assert (root/'default.project.json').read_bytes()==(backup/'default.project.before.json').read_bytes()
safe=json.loads((root/'studio-safe.project.json').read_text())
def safe_node(n):
 assert n.get('$ignoreUnknownInstances')is True
 if '$path'in n:assert n['$path'].endswith(('.luau','.lua'))
 for k,v in n.items():
  if not k.startswith('$')and isinstance(v,dict):safe_node(v)
safe_node(safe['tree'])
all_code='\n'.join(p.read_text(encoding='utf-8')for p in sources)
assert all_code.count('Marketplace.ProcessReceipt=')==1
run('diff-check',['git','diff','--check'])
old_paths={Path(r['Path']).relative_to(root).as_posix()for r in old}
targets=changed+[p.relative_to(root).as_posix()for p in sources if p.relative_to(root).as_posix()not in old_paths]
out=root/'tests/PremiumShopV11.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__');stem=f.removesuffix('.luau')
 path=stem.replace('src/client/','StarterPlayer/StarterPlayerScripts/').replace('src/server/','ServerScriptService/').replace('src/shared/','ReplicatedStorage/Shared/')
 (out/f'{i:02d}.json').write_text(json.dumps(dict(File=f,Path=path.split('/'),Class='ModuleScript',Source=source,Before=h(prior.read_text(encoding='utf-8'))if prior.exists()else None,After=h(source))),encoding='utf-8')
(root/'tests/PremiumShopV11.checks.json').write_text(json.dumps(dict(Checks=checks,Compiled=len(sources),Changed=changed,New=[f for f in targets if f not in changed],OtherBaselineFilesUnchanged=len(old)-len(changed),PhysicalAssetsUnchanged=True,PurchasesEnabled=False,RuntimeBridge='BLOCKED / NOT IMPLEMENTED',Gameplay='NOT RUN'),indent=2),encoding='utf-8')

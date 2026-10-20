from pathlib import Path
import subprocess,os,shutil,json
root=Path('work/clock-smoke').resolve(); root.mkdir(parents=True,exist_ok=True)
source=Path('clock/clock.sh').read_text()
shim='''#!/usr/bin/env python3
import os,sys,json,datetime
from pathlib import Path
name=Path(sys.argv[0]).name; args=sys.argv[1:]
epoch=Path(os.environ['CLOCK_TEST_EPOCH'])
with open(os.environ['CLOCK_TEST_LOG'],'a') as f: f.write(json.dumps([name,*args])+'\\n')
if name=='date':
 n=int(epoch.read_text()); fmt=args[0][1:] if args else '%c'
 print(n if fmt=='%s' else datetime.datetime.fromtimestamp(n,datetime.timezone.utc).strftime(fmt))
elif name=='sleep': epoch.write_text(str(int(epoch.read_text())+int(args[0])))
elif name=='rtcwake': raise AssertionError('Deep suspend must never run')
elif name=='lipc-get-prop':
 if args[-1]=='cmState': print('DISCONNECTED' if os.environ['CLOCK_TEST_CASE']=='wifi-disconnected' else 'CONNECTED')
 else: print('0' if args[-1]=='preventScreenSaver' else '1')
elif name=='curl':
 if os.environ['CLOCK_TEST_CASE']=='malformed': print('<html>error|oops</html>')
 elif os.environ['CLOCK_TEST_CASE']=='offline': sys.exit(7)
 elif os.environ['CLOCK_TEST_CASE']=='negative': print('Clear|-12°C')
 else: print('Sunny|+28°C')
elif name=='fbink':
 if os.environ['CLOCK_TEST_CASE']=='preflight-fail' and any('compute' in a for a in args): sys.exit(1)
 if '-t' in args:
  textargs=args[args.index('-t')+2:]
  if textargs and textargs[0]!='--' and textargs[0].startswith('-'): sys.exit(2)
'''
for scenario in ['success','malformed','offline','negative','wifi-disconnected','preflight-fail','stale-rtc-marker']:
 case=root/scenario
 if case.exists(): shutil.rmtree(case)
 (case/'bin').mkdir(parents=True); (case/'app/bin').mkdir(parents=True)
 for name in ['date','sleep','rtcwake','start','stop','lipc-get-prop','lipc-set-prop','curl']:
  p=case/'bin'/name; p.write_text(shim); p.chmod(0o755)
 fb=case/'app/bin/fbink'; fb.write_text(shim); fb.chmod(0o755)
 font=case/'font.ttf'; font.write_text('mock font')
 battery=case/'battery'; battery.write_text('92')
 script=source.replace('/usr/java/lib/fonts/Palatino-Regular.ttf',str(font)).replace('/tmp/xiamen-clock',str(case/'clock')).replace('/sys/class/power_supply/max77696-battery/capacity',str(battery))
 (case/'app/clock.sh').write_text(script)
 if scenario=='stale-rtc-marker':
  (case/'app/runtime').mkdir(exist_ok=True)
  (case/'app/runtime/rtc-tested').write_text('old marker')
 epoch=case/'epoch'; epoch.write_text('1800000000'); log=case/'calls.jsonl'
 env={**os.environ,'PATH':str(case/'bin')+':'+os.environ['PATH'],'CLOCK_TEST_EPOCH':str(epoch),'CLOCK_TEST_LOG':str(log),'CLOCK_TEST_CASE':scenario,'CLOCK_TEST_STOP':str(case/'clock.stop')}
 mode='preview'
 result=subprocess.run(['sh',str(case/'app/clock.sh'),mode],env=env,text=True,capture_output=True,timeout=10)
 calls=[json.loads(x) for x in log.read_text().splitlines()]
 def called(name,*args): return [name,*args] in calls
 if scenario=='preflight-fail':
  assert result.returncode!=0 and not called('stop','lab126_gui'),(result.stdout,result.stderr)
 else:
  assert result.returncode==0,(result.stdout,result.stderr)
  assert called('stop','lab126_gui') and called('start','lab126_gui')
  assert called('lipc-set-prop','com.lab126.powerd','preventScreenSaver','1')
  assert called('lipc-set-prop','com.lab126.powerd','preventScreenSaver','0')
  assert not (case/'clock.lock').exists()
  assert int(epoch.read_text())==1800000123,'Preview should end after 120 seconds of display time'
  cache=case/'app/runtime/weather.txt'
  if scenario in ['success','stale-rtc-marker']: assert cache.read_text().splitlines()[:2]==['Sunny','28C']
  elif scenario=='negative': assert cache.read_text().splitlines()[:2]==['Clear','-12C']
  else: assert not cache.exists(),'Malformed weather must not be cached'
  if scenario=='wifi-disconnected':
   assert not any(c[0]=='curl' for c in calls),'Do not request weather when Wi-Fi is disconnected'
   assert 'Wi-Fi is not connected' in (case/'app/runtime/weather-error.txt').read_text()
  rendered=[c for c in calls if c[0]=='fbink' and '-t' in c and not any('compute' in a for a in c)]
  assert any(c[-1]=='-- C' for c in rendered),'Initial placeholder must render safely'
  if scenario=='negative': assert any(c[-1]=='-12C' for c in rendered)
 print(scenario+': passed')

# Reject retired test mode before touching GUI or runtime state.
assert 'rtcwake' not in source and '/sys/power/state' not in source
result=subprocess.run(['sh',str(case/'app/clock.sh'),'sleep-test'],env=env,capture_output=True,timeout=5)
assert result.returncode!=0
print('retired sleep mode rejected: passed')

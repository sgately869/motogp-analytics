"""Download official 2025 Q1/Q2 and race timing; never connects to SQL Server."""
from pathlib import Path
import argparse, concurrent.futures, datetime, hashlib, json, time, urllib.request
ROOT=Path(__file__).resolve().parent
BASE='https://api.motogp.pulselive.com/motogp/v1/results/'
CACHE=ROOT/'cache'
def save_json(p,d):
 p.parent.mkdir(parents=True,exist_ok=True);t=p.with_suffix(p.suffix+'.tmp');t.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8');t.replace(p)
def fetch(url,kind,refresh=False):
 p=CACHE/kind/(hashlib.sha256(url.encode()).hexdigest()+('.pdf' if kind=='pdf' else '.json'))
 if not p.exists() or refresh:
  error=None
  for n in range(3):
   try:
    req=urllib.request.Request(url,headers={'User-Agent':'MotoGP-personal-history-research/1.0'})
    data=urllib.request.urlopen(req,timeout=45).read()
    if kind=='pdf':
     if not data.startswith(b'%PDF'):raise ValueError('Response is not a PDF')
    else:json.loads(data)
    p.parent.mkdir(parents=True,exist_ok=True);t=p.with_suffix(p.suffix+'.tmp');t.write_bytes(data);t.replace(p)
    save_json(p.with_suffix(p.suffix+'.meta.json'),{'url':url,'retrieved_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sha256':hashlib.sha256(data).hexdigest()})
    return p
   except Exception as ex:error=ex;time.sleep(n+1)
  raise RuntimeError(str(error))
 return p
def collect_job(j,refresh=False):
 e,c=j['event'],j['category'];u=BASE+f"sessions?eventUuid={e['id']}&categoryUuid={c['id']}"
 sessions=json.loads(fetch(u,'json',refresh).read_text())
 if not isinstance(sessions,list):raise ValueError('Sessions response is not a list')
 out=[]
 for s in sessions:
  if s['type'] not in ('Q','RAC','SPR'):continue
  if s.get('event',{}).get('id')!=e['id'] or s['category']['legacy_id']!=c['legacy_id']:raise ValueError('Session context mismatch')
  out.append({'year':2025,'event_uuid':e['id'],'event_name':e['name'],'event_short':e['short_name'],'class_name':c['name'].replace('™',''),'session':s,'session_list_url':u})
 return out

def classify(x,refresh=False):
 sid=x['session']['id'];u=BASE+f'session/{sid}/classification?seasonYear=2025&test=false'
 p=fetch(u,'json',refresh);d=json.loads(p.read_text())
 if not isinstance(d,dict) or not isinstance(d.get('classification'),list):raise ValueError('Invalid classification')
 x['classification_url']=u;x['classification_path']=str(p.relative_to(ROOT));x['documents']={}
 return x

def download_document(j,refresh=False):
 sid,kind,url=j
 try:
  p=fetch(url,'pdf',refresh)
  return sid,kind,{'url':url,'path':str(p.relative_to(ROOT)),'status':'DOWNLOADED'}
 except Exception as ex:return sid,kind,{'url':url,'status':'DOWNLOAD_FAILED','error':str(ex)}

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--year',type=int,choices=[2025],default=2025)
 ap.add_argument('--workers',type=int,choices=range(1,9),default=4);ap.add_argument('--build-cached',action='store_true');ap.add_argument('--refresh',action='store_true')
 a=ap.parse_args()
 if a.build_cached:
  import build_timing
  return build_timing.main()
 jobs=json.loads((ROOT/'jobs_2025.json').read_text(encoding='utf-8'));sessions=[];errors=[]
 def stage(items,fn,label):
  out=[]
  with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as ex:
   fs={ex.submit(fn,j,a.refresh):j for j in items}
   for n,f in enumerate(concurrent.futures.as_completed(fs),1):
    try:out.append(f.result())
    except Exception as err:errors.append({'stage':label,'job':str(fs[f])[:300],'error':str(err)})
    if n%20==0 or n==len(fs):print(f'{label}: {n}/{len(fs)}; {len(errors)} errors',flush=True)
  return out
 for batch in stage(jobs,collect_job,'Session lists'):sessions.extend(batch)
 sessions=stage(sessions,classify,'Classifications');sessions.sort(key=lambda x:(x['event_uuid'],x['class_name'],x['session']['date'],x['session']['id']))
 tasks=[]
 for x in sessions:
  if x['session']['type'] not in ('RAC','SPR'):continue
  for k in ('grid','fast_lap_rider','analysis'):
   u=x['session'].get('session_files',{}).get(k,{}).get('url')
   if u:tasks.append((x['session']['id'],k,u))
   else:x['documents'][k]={'url':None,'status':'NOT_ADVERTISED'}
 byid={x['session']['id']:x for x in sessions}
 for sid,k,d in stage(tasks,download_document,'Timing PDFs'):byid[sid]['documents'][k]=d
 report={'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'requested_event_classes':len(jobs),'errors':errors,'sessions':sessions}
 save_json(ROOT/'source_manifest.json',report)
 if errors:print('Required downloads failed. Rerun to resume; no new import generated.');return 1
 import build_timing
 return build_timing.main()
if __name__=='__main__':raise SystemExit(main() or 0)

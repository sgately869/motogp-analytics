"""Fetch public race classifications and build reviewable SQL; never connects to SQL Server.
Python 3.9+, standard library only. Defaults to the supplied validated pilot.
Examples (Windows PowerShell):
  py .\fetch_history.py --year 2025
  py .\fetch_history.py --full
  py .\fetch_history.py --year 2025 --build-cached
Downloads are checkpointed per event/class and resumed on rerun. Calendar is
the supplied 1949-2026 snapshot; this does not discover future calendar changes.
"""
from pathlib import Path
import argparse, concurrent.futures, datetime, json, time, urllib.request, urllib.error
import build_imports as b
ROOT=Path(__file__).resolve().parent
BASE='https://api.motogp.pulselive.com/motogp/v1/results/'
CACHE=ROOT/'history_cache'
def atomic(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(value,ensure_ascii=False),encoding='utf-8');tmp.replace(path)
def get(url,path):
    if path.exists():return json.loads(path.read_text(encoding='utf-8'))
    for attempt in range(3):
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'Personal-GP-history-research/1.0'})
            with urllib.request.urlopen(req,timeout=35) as r:data=json.load(r)
            atomic(path,data);return data
        except (urllib.error.URLError,TimeoutError,json.JSONDecodeError):
            if attempt==2:raise
            time.sleep(2**attempt)
def job_key(j):return j['event']['id']+'_'+str(j['category']['legacy_id'])
def run_job(j):
    key=job_key(j);checkpoint=CACHE/'completed'/(key+'.json')
    if checkpoint.exists():return json.loads(checkpoint.read_text(encoding='utf-8'))
    e,c=j['event'],j['category'];year=e['season']['year']
    u=BASE+f"sessions?eventUuid={e['id']}&categoryUuid={c['id']}"
    ss=get(u,CACHE/'sessions'/(key+'.json'))
    if not isinstance(ss,list):raise ValueError('Session endpoint did not return a list: '+u)
    races=[]
    for s in ss:
        if s.get('type') not in ('RAC','SPR'):continue
        if (s.get('date') or '9999')[:10]>'2026-10-12':continue
        if s.get('event',{}).get('id')!=e['id']:raise ValueError('Session/event ID mismatch')
        if s.get('category',{}).get('legacy_id')!=c['legacy_id']:raise ValueError('Session/category ID mismatch')
        url=BASE+f"session/{s['id']}/classification?seasonYear={year}&test=false"
        p=ROOT/'source_classifications'/(s['id']+'.json')
        data=get(url,p)
        if not isinstance(data,dict) or not isinstance(data.get('classification'),list):raise ValueError('Invalid classification payload: '+url)
        races.append({'event':e,'category':c,'session':s,'classification_url':url,'session_url':u,'classification_file':p.name,'rows':len(data['classification']),'retrieved_at':datetime.date.today().isoformat()})
    result={'year':year,'event_id':e['id'],'class_name':c['name'].replace('™',''),'session_url':u,'session_count':len(ss),'races':races}
    atomic(checkpoint,result);return result
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    scope=ap.add_mutually_exclusive_group();scope.add_argument('--year',type=int);scope.add_argument('--full',action='store_true')
    ap.add_argument('--build-cached',action='store_true',help='Build only completed checkpoints; clearly marked partial.')
    ap.add_argument('--workers',type=int,default=4,choices=range(1,9))
    a=ap.parse_args()
    if a.year is None and not a.full:
        b.build_results(b.load('pilot_index.json'),ROOT/'source_classifications');print('Rebuilt pilot SQL from local source data.');return
    if a.year is not None and not 1949<=a.year<=2026:ap.error('This calendar snapshot covers 1949-2026.')
    jobs=[j for j in b.load('history_jobs.json') if a.year is None or j['event']['season']['year']==a.year]
    # Reuse supplied pilot checkpoints, whose classification files are bundled.
    for x in b.load('pilot_index.json'):
        rr=x['races']
        if rr:
            key=x['event_id']+'_'+str(rr[0]['category']['legacy_id']);p=CACHE/'completed'/(key+'.json')
            if not p.exists():atomic(p,x)
    out=[];errors=[]
    if a.build_cached:
        for j in jobs:
            p=CACHE/'completed'/(job_key(j)+'.json')
            if p.exists():out.append(json.loads(p.read_text(encoding='utf-8')))
    else:
        print(f'Fetching/resuming {len(jobs)} event/class requests with {a.workers} workers.',flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as pool:
            futures={pool.submit(run_job,j):j for j in jobs}
            for i,f in enumerate(concurrent.futures.as_completed(futures),1):
                try:out.append(f.result())
                except Exception as ex:errors.append({'job':job_key(futures[f]),'error':str(ex)})
                if i%10==0 or i==len(jobs):print(f'{i}/{len(jobs)} completed; {len(errors)} failures',flush=True)
    out.sort(key=lambda x:(x['year'],x['event_id'],x['class_name']))
    scope_label=str(a.year) if a.year else '1949_2026'
    report={'requested_event_classes':len(jobs),'completed_event_classes':len(out),'errors':errors,'snapshot_cutoff':'2026-10-12','scope':scope_label,'complete_download':len(out)==len(jobs) and not errors}
    atomic(ROOT/f'fetch_{scope_label}_coverage.json',report)
    if errors:
        print('Downloads preserved. Rerun to retry failed requests. No import SQL generated; see coverage report.');return 2
    if not out:print('No completed results to build.');return 2
    suffix='' if report['complete_download'] else '_partial'
    filename=f'16_history_{scope_label}{suffix}_results.sql'
    d=b.build_results(out,ROOT/'source_classifications',filename)
    print(f'Created {filename}: {len(d["races"])} logical races, {len(d["results"])} source rows, {len(d["issues"])} review issues.')
    print('Read the matching audit JSON before executing SQL. A complete download is NOT proof of complete historical results.')
    return 0
if __name__=='__main__':raise SystemExit(main() or 0)

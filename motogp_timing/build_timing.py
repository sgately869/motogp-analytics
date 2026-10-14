"""Build an additive SQL Server timing import from validated cached official sources."""
from pathlib import Path
import json,hashlib,collections,datetime
import parse_timing as p
ROOT=Path(__file__).resolve().parent
VERSION='2025.1'
def load(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def dump(name,d):(ROOT/name).write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(d):return hashlib.sha256(json.dumps(d,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
def identity(r):
 legacy=r.get('legacy_id');uuid=r.get('riders_api_uuid') or r.get('riders_id')
 if legacy is None and not uuid:raise ValueError('Rider has no stable source ID')
 return {'key':'MGP_'+str(legacy) if legacy is not None else 'UUID_'+uuid,'legacy_id':legacy,'uuid':uuid,'name':r.get('full_name'),'number':r.get('number')}
def positive(x):return x if isinstance(x,int) and x>0 else None

def normalise(manifest):
 data={k:[] for k in ['sessions','entries','revisions','documents','qualifying','records','fastest','grids','laps']};issues=[];coverage=[]
 # An event/class roster supplies identities for a published grid even when a rider did not start.
 rosters=collections.defaultdict(dict);conflicts=set()
 for x in manifest['sessions']:
  raw=load(ROOT/x['classification_path'])
  for row in raw['classification']:
   r=identity(row['rider']);num=r['number'];context=(x['event_uuid'],x['class_name'])
   if num is None:continue
   prior=rosters[context].get(num)
   if prior and prior['key']!=r['key']:conflicts.add((context,num))
   rosters[context][num]=r
 for context,num in conflicts:del rosters[context][num]
 for x in manifest['sessions']:
  s=x['session'];sid=s['id'];kind=s['type'];raw=load(ROOT/x['classification_path']);roster=rosters[(x['event_uuid'],x['class_name'])]
  local={k:[] for k in ['entries','documents','qualifying','records','fastest','grids','laps']}
  context={'event':x['event_short'],'class':x['class_name'],'type':kind,'number':s.get('number'),'session_uuid':sid}
  def issue(component,reason):issues.append(dict(context,component=component,reason=reason))
  entry={}
  for row in raw['classification']:
   r=identity(row['rider']);entry[r['key']]=r
   if kind=='Q':
    lap=row.get('best_lap') or {};tm=p.seconds(lap.get('time'))
    local['qualifying'].append({'key':r['key'],'position':positive(row.get('position')),'source_status':row.get('status'),'best_lap_seconds':tm,'best_lap_number':positive(lap.get('number')),'total_laps':row.get('total_laps'),'top_speed_kmh':row.get('top_speed'),'source_time':lap.get('time')})
    if tm is None:issue('qualifying','No positive best lap recorded for '+r['key'])
  if not raw['classification']:issue('classification','Empty classification')
  for record in raw.get('records') or []:
   r=identity(record['rider']);entry.setdefault(r['key'],r);lap=record.get('bestLap') or {}
   local['records'].append({'key':r['key'],'record_type':record['type'],'record_year':record.get('year'),'lap_number':positive(lap.get('number')),'lap_time_seconds':p.seconds(lap.get('time')),'is_new_record':record.get('isNewRecord'),'source_time':lap.get('time')})
  # Preserve response provenance and each PDF's original hash and retrieval time.
  cp=ROOT/x['classification_path'];cm=load(cp.with_suffix(cp.suffix+'.meta.json'))
  local['documents'].append({'kind':'classification_json','url':x['classification_url'],'sha256':cm['sha256'],'retrieved_at':cm['retrieved_at'],'parse_status':'PARSED','row_count':len(raw['classification']),'note':None})
  for k in ('fast_lap_rider','grid','analysis'):
   if kind=='Q':continue
   doc=x['documents'].get(k,{'status':'NOT_ADVERTISED','url':None});status=doc['status'];note=None;rows=[];digest=None;retrieved=None;gridstatus=None
   if status=='DOWNLOADED':
    path=ROOT/doc['path'];meta=load(path.with_suffix('.pdf.meta.json'));digest=meta['sha256'];retrieved=meta['retrieved_at']
    try:
     if k=='fast_lap_rider':
      rows=p.fast_laps(path,roster)
      # Compare every race-classification rider who completed laps with the PDF list.
      expected={identity(r['rider'])['key'] for r in raw['classification'] if (r.get('total_laps') or 0)>0}
      got={r['source_rider_key'] for r in rows}
      if not got.issubset(expected):raise ValueError('Fastest-lap sheet has a rider without completed laps in classification')
      for missing in sorted(expected-got):issue('fastest_lap_missing_rider','No published fastest lap for '+missing+' despite completed laps; no time inferred')
      for rec in local['records']:
       if rec['record_type']=='fastestLap' and rec['record_year'] is None:
        best=min(r['best_lap_seconds'] for r in rows)
        match=next((r for r in rows if r['source_rider_key']==rec['key']),None)
        if match is None or abs(best-rec['lap_time_seconds'])>0.0005 or abs(match['best_lap_seconds']-rec['lap_time_seconds'])>0.0005:
         analysis=x['documents'].get('analysis',{})
         if analysis.get('status')!='DOWNLOADED':raise ValueError('API/PDF fastest-lap conflict cannot be resolved without analysis')
         p.lap_times(ROOT/analysis['path'],roster,rows)
         issue('api_record_conflict','FastLapRider PDF conflicts with API fastestLap record. Every PDF best lap verified against Analysis.pdf; PDF used for race fastest-lap reporting. API record retained separately.')
      local['fastest']=rows
     elif k=='grid':
      gridstatus,rows=p.grid(path,roster);local['grids']=[dict(r,grid_status=gridstatus) for r in rows]
     else:
      if not local['fastest']:raise ValueError('Fastest-lap sheet unavailable for lap validation')
      partial=[];rows=p.lap_times(path,roster,local['fastest'],partial);local['laps']=rows
      for part in partial:issue('unfinished_lap_fragment',str(part))
     status='PARSED'
    except Exception as ex:status='REVIEW';note=str(ex);issue(k,note);rows=[]
   else:note=doc.get('error',status);issue(k,note)
   local['documents'].append({'kind':k,'url':doc.get('url'),'sha256':digest,'retrieved_at':retrieved,'parse_status':status,'row_count':len(rows),'note':note})
  if kind in ('RAC','SPR') and any(d['kind']=='analysis' and d['parse_status']=='PARSED' for d in local['documents']):
   counts=collections.Counter(r['source_rider_key'] for r in local['laps'])
   for row in raw['classification']:
    key=identity(row['rider'])['key'];expected=row.get('total_laps')
    if expected is not None and counts[key]!=expected:issue('lap_count_difference',f'{key}: classification laps={expected}, numbered timed laps={counts[key]}; retain source values without filling missing duration')
   for lap in local['laps']:
    vals=[lap[f'sector{i}_seconds'] for i in range(1,5)]
    if all(v is not None for v in vals) and abs(sum(vals)-lap['lap_time_seconds'])>0.006:
     issue('sector_sum_difference',f"{lap['source_rider_key']} lap {lap['lap_number']}: sectors do not sum to lap duration; printed source values retained")
  for k in ['fastest','grids','laps']:
   for r in local[k]:
    ident=roster[r['rider_number']];entry[ident['key']]=ident
  local['entries']=list(entry.values())
  # Hash accepted facts AND source digests; reruns cannot silently replace an existing selection.
  digest_data={k:v for k,v in local.items() if k!='documents'}
  digest_data['source_hashes']=[(d['kind'],d['sha256'],d['parse_status']) for d in local['documents']]
  rev=sha({'version':VERSION,'session':sid,'data':digest_data})
  data['sessions'].append({'sid':sid,'event_uuid':x['event_uuid'],'class_name':x['class_name'],'type':kind,'number':s.get('number'),'date':s.get('date'),'status':s.get('status'),'url':x['classification_url']})
  data['revisions'].append({'revision':rev,'sid':sid,'created_at':manifest['created_at'],'parser_version':VERSION})
  for k,rows in local.items():
   for r in rows:data[k].append(dict(r,sid=sid,revision=rev))
  coverage.append(dict(context,qualifying_rows=len(local['qualifying']),fastest_lap_rows=len(local['fastest']),grid_rows=len(local['grids']),lap_rows=len(local['laps'])))
 revs={r['sid']:r['revision'] for r in data['revisions']};seq=collections.Counter();data['issues']=[]
 for i in issues:
  sid=i['session_uuid'];seq[sid]+=1
  data['issues'].append({'revision':revs[sid],'sid':sid,'issue_number':seq[sid],'component':i['component'],'reason':i['reason']})
 return data,issues,coverage

# Column types are deliberately SQL Server types; seconds are durations, not SQL TIME values.
SPECS={
'issues':('timing_quality_issues',[('revision','char(64)'),('sid','uniqueidentifier'),('issue_number','int'),('component','varchar(40)'),('reason','nvarchar(1000)')]),
'sessions':('timing_sessions',[('sid','uniqueidentifier'),('event_uuid','uniqueidentifier'),('class_name','nvarchar(50)'),('type','varchar(10)'),('number','smallint'),('date','nvarchar(50)'),('status','nvarchar(50)'),('url','nvarchar(1000)')]),
'entries':('session_entries',[('sid','uniqueidentifier'),('key','varchar(60)'),('legacy_id','int'),('uuid','uniqueidentifier'),('name','nvarchar(200)'),('number','smallint')]),
'revisions':('timing_revisions',[('revision','char(64)'),('sid','uniqueidentifier'),('created_at','nvarchar(50)'),('parser_version','varchar(20)')]),
'documents':('timing_documents',[('revision','char(64)'),('sid','uniqueidentifier'),('kind','varchar(30)'),('url','nvarchar(1000)'),('sha256','char(64)'),('retrieved_at','nvarchar(50)'),('parse_status','varchar(25)'),('row_count','int'),('note','nvarchar(1000)')]),
'qualifying':('session_results',[('revision','char(64)'),('sid','uniqueidentifier'),('key','varchar(60)'),('position','smallint'),('source_status','nvarchar(50)'),('best_lap_seconds','decimal(12,3)'),('best_lap_number','smallint'),('total_laps','smallint'),('top_speed_kmh','decimal(7,3)'),('source_time','nvarchar(50)')]),
'records':('session_lap_records',[('revision','char(64)'),('sid','uniqueidentifier'),('key','varchar(60)'),('record_type','varchar(30)'),('record_year','smallint'),('lap_number','smallint'),('lap_time_seconds','decimal(12,3)'),('is_new_record','bit'),('source_time','nvarchar(50)')]),
'fastest':('race_fastest_laps',[('revision','char(64)'),('sid','uniqueidentifier'),('source_rider_key','varchar(60)'),('rider_number','smallint'),('published_rank','smallint'),('best_lap_seconds','decimal(12,3)'),('best_lap_number','smallint'),('total_laps','smallint'),('source_text','nvarchar(1000)'),('page','smallint')]),
'grids':('race_grids',[('revision','char(64)'),('sid','uniqueidentifier'),('source_rider_key','varchar(60)'),('rider_number','smallint'),('grid_position','smallint'),('qualifying_time_seconds','decimal(12,3)'),('grid_status','varchar(20)'),('source_text','nvarchar(1000)'),('page','smallint')]),
'laps':('lap_times',[('revision','char(64)'),('sid','uniqueidentifier'),('source_rider_key','varchar(60)'),('rider_number','smallint'),('lap_number','smallint'),('lap_time_seconds','decimal(12,3)'),('lap_time_cancelled','bit'),('pit_lane_crossing','bit'),('sector1_seconds','decimal(10,3)'),('sector2_seconds','decimal(10,3)'),('sector3_seconds','decimal(10,3)'),('sector4_seconds','decimal(10,3)'),('sector1_cancelled','bit'),('sector2_cancelled','bit'),('sector3_cancelled','bit'),('sector4_cancelled','bit'),('speed_kmh','decimal(7,3)'),('page','smallint'),('source_text','nvarchar(1000)')])}

def lit(v):
 if v is None:return 'NULL'
 if isinstance(v,bool):return str(int(v))
 if isinstance(v,(int,float)):return str(v)
 return "N'"+str(v).replace("'","''")+"'"
def staging(k,rows):
 cols=SPECS[k][1];s=f"IF OBJECT_ID('tempdb..#t_{k}') IS NOT NULL DROP TABLE #t_{k};\nCREATE TABLE #t_{k}("+','.join(f'[{n}] {t}' for n,t in cols)+');\n'
 for i in range(0,len(rows),250):s+=f'INSERT INTO #t_{k} VALUES\n'+',\n'.join('('+','.join(lit(r.get(n)) for n,t in cols)+')' for r in rows[i:i+250])+';\n'
 return s

def make_sql(data):
 s="USE MotoGP;\nGO\nSET NOCOUNT ON;\nSET XACT_ABORT ON;\nBEGIN TRY\nBEGIN TRANSACTION;\n"
 for k,rows in data.items():s+=staging(k,rows)
 s+='''
IF OBJECT_ID(N'dbo.timing_sessions',N'U') IS NULL THROW 50100,'Run 21_create_timing_tables.sql first.',1;
IF EXISTS(SELECT 1 FROM #t_sessions x LEFT JOIN dbo.events e ON e.source_event_uuid=x.event_uuid
 LEFT JOIN dbo.classes c ON c.class_name=x.class_name
 LEFT JOIN dbo.event_classes ec ON ec.event_id=e.event_id AND ec.class_id=c.class_id
 WHERE ec.event_class_id IS NULL) THROW 50101,'Timing import has missing event/class links. Check calendar import.',1;
IF EXISTS(SELECT 1 FROM #t_sessions x LEFT JOIN motogp_source.race_sessions rs ON rs.source_session_uuid=x.sid
 WHERE x.type IN('RAC','SPR') AND rs.source_session_uuid IS NULL)
 THROW 50102,'Load 16_history_2025_results.sql before timing data.',1;
IF EXISTS(SELECT 1 FROM #t_revisions x JOIN dbo.timing_revisions r ON r.sid=x.sid AND r.is_current=1 WHERE r.revision<>x.revision)
 THROW 50103,'Timing source or parser revision changed. Review before replacing the accepted revision.',1;
INSERT INTO dbo.timing_sessions(sid,event_class_id,type,number,date,status,url)
SELECT x.sid,ec.event_class_id,x.type,x.number,x.date,x.status,x.url
FROM #t_sessions x JOIN dbo.events e ON e.source_event_uuid=x.event_uuid
JOIN dbo.classes c ON c.class_name=x.class_name
JOIN dbo.event_classes ec ON ec.event_id=e.event_id AND ec.class_id=c.class_id
WHERE NOT EXISTS(SELECT 1 FROM dbo.timing_sessions t WHERE t.sid=x.sid);
IF EXISTS(SELECT 1 FROM #t_sessions x JOIN dbo.timing_sessions t ON t.sid=x.sid
 JOIN motogp_source.race_sessions rs ON rs.source_session_uuid=x.sid
 JOIN dbo.races r ON r.race_id=rs.race_id WHERE t.event_class_id<>r.event_class_id)
 THROW 50104,'Race and timing session contexts differ.',1;
INSERT INTO dbo.session_entries(sid,[key],legacy_id,uuid,name,number,rider_id)
SELECT x.sid,x.[key],x.legacy_id,x.uuid,x.name,x.number,sr.rider_id
FROM #t_entries x LEFT JOIN motogp_source.riders sr ON sr.motogp_legacy_id=x.legacy_id
 AND (x.uuid IS NULL OR sr.source_rider_uuid=x.uuid)
WHERE NOT EXISTS(SELECT 1 FROM dbo.session_entries t WHERE t.sid=x.sid AND t.[key]=x.[key]);
INSERT INTO dbo.timing_revisions(revision,sid,created_at,parser_version,is_current)
SELECT x.revision,x.sid,x.created_at,x.parser_version,1 FROM #t_revisions x
WHERE NOT EXISTS(SELECT 1 FROM dbo.timing_revisions t WHERE t.revision=x.revision);
'''
 for k in ['documents','qualifying','records','fastest','grids','laps','issues']:
  table,cols=SPECS[k];names=','.join('['+n+']' for n,t in cols)
  s+=f'INSERT INTO dbo.{table}({names})\nSELECT '+','.join('x.['+n+']' for n,t in cols)+f' FROM #t_{k} x\nWHERE NOT EXISTS(SELECT 1 FROM dbo.{table} t WHERE t.revision=x.revision);\n'
 s+='''
SELECT (SELECT COUNT(*) FROM #t_sessions) AS sessions_in_seed,
 (SELECT COUNT(*) FROM #t_qualifying) AS qualifying_rows_in_seed,
 (SELECT COUNT(*) FROM #t_fastest) AS fastest_lap_rows_in_seed,
 (SELECT COUNT(*) FROM #t_grids) AS grid_rows_in_seed,
 (SELECT COUNT(*) FROM #t_laps) AS lap_rows_in_seed;
SELECT COUNT(*) AS timing_entries_without_rider_link FROM dbo.session_entries e
JOIN #t_sessions x ON x.sid=e.sid WHERE e.rider_id IS NULL;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
'''
 return s

def validate(data):
 sessions={s['sid'] for s in data['sessions']}
 if len(sessions)!=len(data['sessions']):raise ValueError('Duplicate session')
 entry={(r['sid'],r['key']) for r in data['entries']}
 if len(entry)!=len(data['entries']):raise ValueError('Duplicate entry')
 for k in ['qualifying','records','fastest','grids','laps']:
  for r in data[k]:
   if (r['sid'],r.get('key',r.get('source_rider_key'))) not in entry:raise ValueError('Broken entry link '+k)
 for k,(_,cols) in SPECS.items():
  for row in data[k]:
   for n,t in cols:
    v=row.get(n)
    if v is not None and 'char(' in t and len(str(v))>int(t.split('(')[1][:-1]):raise ValueError(f'{k}.{n} exceeds SQL width')
    if v is not None and (n.endswith('_seconds') or n in ['lap_number','best_lap_number','grid_position','published_rank','page','position']) and v<=0:raise ValueError(f'{k}.{n} violates positive-value constraint')
    if v is not None and t=='smallint' and not -32768<=v<=32767:raise ValueError(f'{k}.{n} exceeds SMALLINT')
    if v is not None and t=='uniqueidentifier':__import__('uuid').UUID(v)
 for k,fields in [('qualifying',['revision','key']),('records',['revision','record_type']),('fastest',['revision','source_rider_key']),('grids',['revision','source_rider_key']),('laps',['revision','source_rider_key','lap_number']),('documents',['revision','kind']),('issues',['revision','issue_number'])]:
  keys=[tuple(r[f] for f in fields) for r in data[k]]
  if len(keys)!=len(set(keys)):raise ValueError('Duplicate primary key '+k)

def main():
 manifest=load(ROOT/'source_manifest.json')
 if manifest['errors']:raise ValueError('Resolve failed required downloads before building')
 data,issues,coverage=normalise(manifest);validate(data)
 dump('timing_2025_normalised.json',data)
 audit={'parser_version':VERSION,'built_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'counts':{k:len(v) for k,v in data.items()},'issues':issues,'coverage':coverage,'limits':['Published grids are not proof of actual grid occupancy or pit-lane starts.','Q1/Q2 times are separate; do not rank the whole grid by minimum Q1/Q2 time.','Historical circuit records are not current-session fastest laps.','Unparsed timing documents are withheld; source URLs and reasons are retained.','No historical coverage beyond 2025 is claimed.']}
 dump('22_timing_2025_audit.json',audit)
 (ROOT/'22_import_timing_2025.sql').write_text(make_sql(data),encoding='utf-8-sig')
 print('Built 22_import_timing_2025.sql:',audit['counts'],flush=True);print('Review issues:',len(issues),flush=True)
 return 0
if __name__=='__main__':raise SystemExit(main())

"""Offline SQL Server seed generation. Python standard library only.
Run without arguments to rebuild the supplied snapshot. The history fetcher
also calls build_results() with its downloaded, audited session index.
"""
from pathlib import Path
import json, hashlib, re, collections, datetime
ROOT=Path(__file__).resolve().parent
def load(name): return json.loads((ROOT/name).read_text(encoding='utf-8'))
def dump(name,data): (ROOT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(x): return hashlib.sha256(json.dumps(x,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
def lit(x):
    if x is None:return 'NULL'
    if isinstance(x,bool):return str(int(x))
    if isinstance(x,(int,float)):return str(x)
    return "N'"+str(x).replace("'","''")+"'"
def table(name,columns,rows):
    s=[f"CREATE TABLE #{name} ("+', '.join('['+n+'] '+t for n,t in columns)+');\n']
    for i in range(0,len(rows),300):
        s.append(f"INSERT INTO #{name} ("+', '.join('['+n+']' for n,t in columns)+') VALUES\n'+',\n'.join('('+','.join(lit(x) for x in r)+')' for r in rows[i:i+300])+';\n')
    return ''.join(s)
def script(body,temps):
    start='USE MotoGP;\nGO\nSET NOCOUNT ON;\nSET XACT_ABORT ON;\n'
    # Each script can be rerun in the same editor connection.
    start+=''.join(f"IF OBJECT_ID('tempdb..#{t}') IS NOT NULL DROP TABLE #{t};\n" for t in temps)
    return start+'BEGIN TRY\nBEGIN TRANSACTION;\n'+body+'\nCOMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\n IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;\n THROW;\nEND CATCH;\nGO\n'
def write(name,text): (ROOT/name).write_text(text,encoding='utf-8-sig')

def build_calendar(cat):
    es=cat['events'];ecs=cat['event_classes']
    body=table('events',[('uuid','uniqueidentifier'),('year','smallint'),('name','nvarchar(250)'),('short','nvarchar(20)'),('circuit','nvarchar(150)'),('country','char(3)'),('start','date'),('finish','date'),('status','varchar(25)'),('raw_status','nvarchar(50)'),('raw_country','nvarchar(20)'),('url','nvarchar(1000)'),('venue_url','nvarchar(1000)')],
      [[e[k] for k in ['uuid','year','name','short','circuit','country','start','finish','status','raw_status','raw_country','url','venue_url']] for e in es])
    body+=table('ec',[('uuid','uniqueidentifier'),('year','smallint'),('class_name','nvarchar(50)'),('circuit','nvarchar(150)'),('country','char(3)'),('url','nvarchar(1000)'),('venue_url','nvarchar(1000)')],[[e[k] for k in ['uuid','year','class_name','circuit','country','url','venue_url']] for e in ecs])
    body+="""
IF EXISTS(SELECT 1 FROM #ec x LEFT JOIN dbo.classes c ON c.class_name=x.class_name
 LEFT JOIN dbo.season_classes sc ON sc.season_year=x.year AND sc.class_id=c.class_id
 WHERE sc.class_id IS NULL) THROW 50010,'Missing season/class. Run script 13.',1;
IF EXISTS(SELECT 1 FROM #ec x LEFT JOIN dbo.countries co ON co.country_code=x.country
 LEFT JOIN dbo.circuits ci ON ci.country_id=co.country_id AND ci.circuit_name=x.circuit
 WHERE ci.circuit_id IS NULL) THROW 50011,'Missing circuit. Run the earlier circuit seed.',1;
INSERT INTO dbo.events(source_event_uuid,season_year,event_name,short_name,circuit_id,date_start,date_end,event_status,source_status,source_country_code,source_url,venue_evidence_url)
SELECT x.uuid,x.year,x.name,x.short,ci.circuit_id,x.start,x.finish,x.status,x.raw_status,x.raw_country,x.url,x.venue_url
FROM #events x LEFT JOIN dbo.countries co ON co.country_code=x.country
LEFT JOIN dbo.circuits ci ON ci.country_id=co.country_id AND ci.circuit_name=x.circuit
WHERE NOT EXISTS(SELECT 1 FROM dbo.events e WHERE e.source_event_uuid=x.uuid);
INSERT INTO dbo.event_classes(event_id,season_year,class_id,circuit_id,source_url,venue_evidence_url)
SELECT e.event_id,x.year,c.class_id,ci.circuit_id,x.url,x.venue_url
FROM #ec x JOIN dbo.events e ON e.source_event_uuid=x.uuid
JOIN dbo.classes c ON c.class_name=x.class_name
JOIN dbo.countries co ON co.country_code=x.country
JOIN dbo.circuits ci ON ci.country_id=co.country_id AND ci.circuit_name=x.circuit
WHERE NOT EXISTS(SELECT 1 FROM dbo.event_classes ec WHERE ec.event_id=e.event_id AND ec.class_id=c.class_id);
SELECT COUNT(*) AS events_in_this_seed FROM #events;
SELECT COUNT(*) AS event_classes_in_this_seed FROM #ec;
"""
    write('15_import_calendar.sql',script(body,['events','ec']))

def normalise(index,cache):
    races=[];sessions=[];sets=[];entries={};results=[];issues=[]
    for ec in index:
        groups=collections.defaultdict(list)
        for r in ec['races']:
            s=r['session'];cl=ec['class_name'];kind='SPRINT' if s['type']=='SPR' else ('RACE' if cl=='MotoE' else 'GP')
            ordinal=(s.get('number') or 1) if cl=='MotoE' else 1
            groups[(kind,ordinal)].append(r)
        for (kind,num),rs in groups.items():
            e=rs[0]['event'];year=ec['year'];cl=ec['class_name'];rk=f"{e['id']}_{cl}_{kind}_{num}"
            selected=None;note='Single source race session; archive completeness not established.';evidence=None
            cancelled=(year==2018 and e['short_name']=='GBR')
            if cancelled:
                status='CANCELLED';note='All 2018 British GP races cancelled despite archive FINISHED flags.'
                evidence='https://www.motogp.com/en/news/2018/08/28/gopro-british-gp-cancellation-a-message-for-fans/147970'
            elif year==2026 and e['short_name']=='THA' and cl=='Moto2':
                selected=next((r['session']['id'] for r in rs if r['session'].get('number')==2),None)
                status='HELD' if selected else 'REVIEW';note='Revised RAC2 is the scoring result; earlier race part is retained but excluded from statistics.'
                evidence='https://resources.motogp.com/files/results/2026/THA/Moto2/RAC2/Classification.pdf'
            elif len(rs)==1:
                raw=json.loads((cache/rs[0]['classification_file']).read_text())
                if raw.get('classification'):
                    selected=rs[0]['session']['id'];status='HELD'
                else:status='REVIEW';note='Empty classification is not proof of cancellation or a complete result.'
            else:
                status='REVIEW';note='Multiple race parts require review; none contributes to statistics until final classification is verified.'
            if status=='REVIEW':issues.append({'race_key':rk,'issue':note})
            dates=[r['session'].get('date','')[:10] for r in rs if r['session'].get('date')]
            races.append([rk,e['id'],cl,kind,num,max(dates) if dates else None,status,note,evidence])
            ordered=sorted(rs,key=lambda r:r['session']['id']==selected) # selected entry metadata wins
            for r in ordered:
                s=r['session'];sid=s['id'];raw=json.loads((cache/r['classification_file']).read_text());rr=raw.get('classification',[])
                pdf=raw.get('file') or (s.get('session_files',{}).get('classification') or {}).get('url') or None
                sessions.append([sid,rk,s['type'],s.get('number'),s.get('date'),s.get('status'),sid==selected,r['classification_url'],pdf])
                valid_points=any(isinstance(x.get('points'),(float,int)) and x['points']>0 for x in rr)
                ps='SOURCE_REPORTED' if valid_points else 'UNRESOLVED'
                if year==2026 and e['short_name']=='THA' and cl=='Moto2' and s.get('number')==2:
                    ps='VERIFIED_PDF'
                sk=sha({'session':sid,'classification':rr})
                sets.append([sk,rk,sid,r.get('retrieved_at','2026-10-12'),r['classification_url'],ps,'Source rows only; entry-list, DNQ and historical completeness not established.'])
                if rr and not valid_points: issues.append({'race_key':rk,'session':sid,'issue':'All source points zero/absent; official_points_awarded left NULL.'})
                seen=set()
                for row in rr:
                    rider=row.get('rider') or {};legacy=rider.get('legacy_id');uuid=rider.get('riders_api_uuid') or rider.get('riders_id')
                    sourcekey=f'MGP_{legacy}' if legacy is not None else ('UUID_'+uuid if uuid else 'ROW_'+row['id'])
                    if sourcekey in seen:raise ValueError('Duplicate rider in source classification '+sid+' '+sourcekey)
                    seen.add(sourcekey)
                    team=row.get('team') or {};con=row.get('constructor') or {}
                    entries[(rk,sourcekey)]=[rk,sourcekey,legacy,uuid,rider.get('full_name') or 'Unknown source rider',rider.get('number') or None,team.get('name'),con.get('legacy_id'),con.get('name'),(rider.get('country') or {}).get('iso'),r['classification_url']]
                    src=row.get('status');position=row.get('position');position=position if isinstance(position,int) and position>0 else None
                    mapping={'INSTND':'CLASSIFIED','OUTSTND':'NC','OUTOFLAPS':'NC','OUTOFTIME':'NC','PERMANENTOUTSTND':'NC','NOTSTARTED':'DNS','WILLNOTSTART':'DNS','NOTONRESTARTGRID':'NO_RESTART','RETIRED':'DNF','NOTFINISHFIRST':'DNF','DISQUALIFIED':'DSQ','EXCLUDED':'EXCLUDED'}
                    statuscode=mapping.get(src,'UNKNOWN')
                    if src=='FINISHEDTHRUPITS':statuscode='CLASSIFIED' if position else 'NC'
                    if statuscode=='CLASSIFIED' and position is None:statuscode='UNKNOWN'
                    if statuscode!='CLASSIFIED':position=None
                    started=0 if statuscode=='DNS' else (1 if statuscode in ('CLASSIFIED','DNF') else None)
                    laps=row.get('total_laps');laps=laps if isinstance(laps,int) and laps>=0 else None
                    if laps is not None and laps>0:started=1
                    # Archive zero lap/time fields are often placeholders. Preserve raw time.
                    if year<2000 and laps==0:laps=None
                    elapsed=None;rawtime=row.get('time') or None
                    if rawtime and year>=2000:
                        parts=rawtime.replace("'",':').split(':')
                        try:
                            if 1<len(parts)<=3:elapsed=round(sum(float(v)*60**i for i,v in enumerate(reversed(parts))),3)
                        except ValueError:pass
                    pts=row.get('points');pts=pts if isinstance(pts,(int,float)) else None
                    official=pts if valid_points and pts is not None and pts>=0 else None
                    if statuscode=='UNKNOWN':issues.append({'race_key':rk,'session':sid,'rider':sourcekey,'issue':'Unmapped status '+str(src)})
                    results.append([sk,rk,sourcekey,position,statuscode,src,started,laps,elapsed,rawtime,json.dumps(row.get('gap'),ensure_ascii=False) if row.get('gap') else None,pts,official])
    return {'races':races,'sessions':sessions,'sets':sets,'entries':list(entries.values()),'results':results,'issues':issues}

def build_results(index,cache,filename='16_import_pilot_results.sql'):
    d=normalise(index,cache)
    body=table('r',[('key','varchar(100)'),('event_uuid','uniqueidentifier'),('class_name','nvarchar(50)'),('kind','varchar(10)'),('num','smallint'),('date','date'),('status','varchar(20)'),('note','nvarchar(500)'),('evidence','nvarchar(1000)')],d['races'])
    body+=table('s',[('uuid','uniqueidentifier'),('race_key','varchar(100)'),('type','nvarchar(20)'),('num','smallint'),('date','nvarchar(50)'),('status','nvarchar(50)'),('selected','bit'),('url','nvarchar(1000)'),('pdf','nvarchar(1000)')],d['sessions'])
    body+=table('rs',[('key','char(64)'),('race_key','varchar(100)'),('uuid','uniqueidentifier'),('retrieved','date'),('url','nvarchar(1000)'),('points_state','varchar(30)'),('note','nvarchar(500)')],d['sets'])
    body+=table('en',[('race_key','varchar(100)'),('rider_key','varchar(60)'),('legacy_id','int'),('uuid','uniqueidentifier'),('name','nvarchar(200)'),('number','smallint'),('team','nvarchar(250)'),('constructor_legacy_id','int'),('constructor_name','nvarchar(150)'),('country','nvarchar(20)'),('url','nvarchar(1000)')],d['entries'])
    body+=table('res',[('set_key','char(64)'),('race_key','varchar(100)'),('rider_key','varchar(60)'),('pos','smallint'),('status','varchar(20)'),('raw_status','nvarchar(50)'),('started','bit'),('laps','smallint'),('elapsed','decimal(14,3)'),('time','nvarchar(100)'),('gap','nvarchar(100)'),('raw_points','decimal(10,3)'),('points','decimal(10,3)')],d['results'])
    body+="""
IF EXISTS(SELECT 1 FROM #r x LEFT JOIN dbo.events e ON e.source_event_uuid=x.event_uuid
 LEFT JOIN dbo.classes c ON c.class_name=x.class_name
 LEFT JOIN dbo.event_classes ec ON ec.event_id=e.event_id AND ec.class_id=c.class_id
 WHERE ec.event_class_id IS NULL) THROW 50012,'Missing event/class; run script 15 first.',1;
INSERT INTO dbo.races(race_key,event_class_id,race_type,race_number,race_date,race_status,selection_note,selection_evidence_url)
SELECT x.[key],ec.event_class_id,x.kind,x.num,x.date,x.status,x.note,x.evidence
FROM #r x JOIN dbo.events e ON e.source_event_uuid=x.event_uuid
JOIN dbo.classes c ON c.class_name=x.class_name
JOIN dbo.event_classes ec ON ec.event_id=e.event_id AND ec.class_id=c.class_id
WHERE NOT EXISTS(SELECT 1 FROM dbo.races r WHERE r.race_key=x.[key]);
-- Never silently overwrite a previously reviewed selection on rerun.
IF EXISTS(SELECT 1 FROM #r x JOIN dbo.races r ON r.race_key=x.[key]
 WHERE r.race_status<>x.status) THROW 50013,'Existing race status differs; review instead of overwriting.',1;
IF EXISTS(SELECT 1 FROM #s x JOIN motogp_source.race_sessions s ON s.source_session_uuid=x.uuid
 WHERE s.selected_for_statistics<>x.selected) THROW 50014,'Existing session selection differs; review required.',1;
INSERT INTO motogp_source.race_sessions(source_session_uuid,race_id,source_type,source_number,source_date,source_status,selected_for_statistics,source_url,pdf_url)
SELECT x.uuid,r.race_id,x.type,x.num,x.date,x.status,x.selected,x.url,x.pdf
FROM #s x JOIN dbo.races r ON r.race_key=x.race_key
WHERE NOT EXISTS(SELECT 1 FROM motogp_source.race_sessions s WHERE s.source_session_uuid=x.uuid);
INSERT INTO dbo.race_entries(race_id,source_rider_key,rider_id,source_rider_legacy_id,source_rider_uuid,source_rider_name,rider_number,constructor_id,source_team_name,source_constructor_name,source_country_code,source_url)
SELECT r.race_id,x.rider_key,sr.rider_id,x.legacy_id,x.uuid,x.name,x.number,co.constructor_id,x.team,x.constructor_name,x.country,x.url
FROM #en x JOIN dbo.races r ON r.race_key=x.race_key
LEFT JOIN motogp_source.riders sr ON sr.motogp_legacy_id=x.legacy_id
 AND (x.uuid IS NULL OR sr.source_rider_uuid=x.uuid)
LEFT JOIN motogp_source.constructor_labels co ON co.constructor_key='MGP_'+CONVERT(varchar(20),x.constructor_legacy_id)
WHERE NOT EXISTS(SELECT 1 FROM dbo.race_entries en WHERE en.race_id=r.race_id AND en.source_rider_key=x.rider_key);
-- Keep source team name. Team-season linking is deliberately unresolved here:
-- a season roster does not prove the entrant at a particular race.
IF EXISTS(SELECT 1 FROM dbo.race_result_sets old JOIN #rs x ON x.uuid=old.source_session_uuid
 WHERE old.is_current=1 AND old.result_set_key<>x.[key])
 THROW 50015,'A source classification changed. Review its revisions before changing the current result.',1;
UPDATE old SET is_current=0 FROM dbo.race_result_sets old JOIN #rs x ON x.uuid=old.source_session_uuid
WHERE old.result_set_key<>x.[key] AND old.is_current=1;
INSERT INTO dbo.race_result_sets(result_set_key,race_id,source_session_uuid,retrieved_at,is_current,source_url,points_state,completeness_note)
SELECT x.[key],r.race_id,x.uuid,x.retrieved,1,x.url,x.points_state,x.note
FROM #rs x JOIN dbo.races r ON r.race_key=x.race_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.race_result_sets rs WHERE rs.result_set_key=x.[key]);
UPDATE rs SET is_current=1 FROM dbo.race_result_sets rs JOIN #rs x ON x.[key]=rs.result_set_key;
INSERT INTO dbo.race_results(result_set_key,race_entry_id,race_id,classified_position,result_status_code,source_status,started_session,laps_completed,elapsed_seconds,source_time,source_gap,source_points,official_points_awarded)
SELECT x.set_key,en.race_entry_id,r.race_id,x.pos,x.status,x.raw_status,x.started,x.laps,x.elapsed,x.time,x.gap,x.raw_points,x.points
FROM #res x JOIN dbo.races r ON r.race_key=x.race_key
JOIN dbo.race_entries en ON en.race_id=r.race_id AND en.source_rider_key=x.rider_key
WHERE NOT EXISTS(SELECT 1 FROM dbo.race_results rr WHERE rr.result_set_key=x.set_key AND rr.race_entry_id=en.race_entry_id);
SELECT COUNT(*) AS logical_races_in_seed FROM #r;
SELECT COUNT(*) AS source_result_rows_in_seed FROM #res;
SELECT COUNT(*) AS rows_with_unresolved_points FROM #res WHERE points IS NULL;
"""
    write(filename,script(body,['r','s','rs','en','res']))
    dump(filename.replace('.sql','_audit.json'),{'counts':{k:len(v) for k,v in d.items()},'issues':d['issues']})
    return d

def build_standings(data):
    body=table('ch',[('key','varchar(80)'),('year','smallint'),('class_name','nvarchar(50)'),('snapshot','char(64)'),('url','nvarchar(1000)'),('retrieved','date')],data['championships'])
    body+=table('st',[('ch_key','varchar(80)'),('key','varchar(100)'),('name','nvarchar(250)'),('legacy_id','int'),('pos','smallint'),('points','decimal(10,3)')],data['standings'])
    body+="""
INSERT INTO dbo.championships(championship_key,season_year,class_id,championship_type)
SELECT x.[key],x.year,c.class_id,'RIDER' FROM #ch x JOIN dbo.classes c ON c.class_name=x.class_name
WHERE NOT EXISTS(SELECT 1 FROM dbo.championships ch WHERE ch.championship_key=x.[key]);
INSERT INTO dbo.championship_entries(championship_id,source_competitor_key,source_competitor_name,rider_id)
SELECT ch.championship_id,x.[key],x.name,sr.rider_id FROM #st x
JOIN dbo.championships ch ON ch.championship_key=x.ch_key
LEFT JOIN motogp_source.riders sr ON sr.motogp_legacy_id=x.legacy_id
WHERE NOT EXISTS(SELECT 1 FROM dbo.championship_entries ce WHERE ce.championship_id=ch.championship_id AND ce.source_competitor_key=x.[key]);
IF EXISTS(SELECT 1 FROM dbo.championship_standing_snapshots s
 JOIN dbo.championships ch ON ch.championship_id=s.championship_id
 JOIN #ch x ON x.[key]=ch.championship_key WHERE s.is_current=1 AND s.snapshot_key<>x.snapshot)
 THROW 50016,'A standings snapshot differs. Review before changing the current snapshot.',1;
UPDATE s SET is_current=0 FROM dbo.championship_standing_snapshots s
JOIN dbo.championships ch ON ch.championship_id=s.championship_id
JOIN #ch x ON x.[key]=ch.championship_key WHERE s.snapshot_key<>x.snapshot AND s.is_current=1;
INSERT INTO dbo.championship_standing_snapshots(snapshot_key,championship_id,retrieved_at,is_current,source_url,coverage_note)
SELECT x.snapshot,ch.championship_id,x.retrieved,1,x.url,
 N'Archive snapshot; not certified final standings. 2026 ongoing; endpoint may return incomplete historical data. No through-race coverage inferred.'
FROM #ch x JOIN dbo.championships ch ON ch.championship_key=x.[key]
WHERE NOT EXISTS(SELECT 1 FROM dbo.championship_standing_snapshots s WHERE s.snapshot_key=x.snapshot);
UPDATE s SET is_current=1 FROM dbo.championship_standing_snapshots s JOIN #ch x ON x.snapshot=s.snapshot_key;
INSERT INTO dbo.championship_standings(snapshot_key,championship_id,championship_entry_id,official_position,official_points)
SELECT x.snapshot,ch.championship_id,ce.championship_entry_id,st.pos,st.points
FROM #st st JOIN #ch x ON x.[key]=st.ch_key
JOIN dbo.championships ch ON ch.championship_key=st.ch_key
JOIN dbo.championship_entries ce ON ce.championship_id=ch.championship_id AND ce.source_competitor_key=st.[key]
WHERE NOT EXISTS(SELECT 1 FROM dbo.championship_standings s WHERE s.snapshot_key=x.snapshot AND s.championship_entry_id=ce.championship_entry_id);
SELECT COUNT(*) AS standings_rows_in_seed FROM #st;
"""
    write('17_import_rider_standings.sql',script(body,['ch','st']))
def main():
    build_calendar(load('calendar.json'))
    d=build_results(load('pilot_index.json'),ROOT/'source_classifications')
    build_standings(load('standings.json'))
    print('Built calendar, pilot results and standings SQL.',{k:len(v) for k,v in d.items()})
if __name__=='__main__': main()

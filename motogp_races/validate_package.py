"""Offline integrity and regression checks. Does not execute T-SQL on SQL Server."""
import json, re, collections, hashlib
import build_imports as b

def sql_rows(sql):
    """Independently decode generated temp-table VALUES statements."""
    found={}
    for m in re.finditer(r'INSERT INTO #(\w+) \([^\n]+\) VALUES\n',sql):
        name=m.group(1);i=m.end();rows=[]
        while True:
            while sql[i].isspace():i+=1
            assert sql[i]=='(';i+=1;row=[]
            while True:
                while sql[i].isspace():i+=1
                if sql.startswith("N'",i) or sql[i]=="'":
                    i+=2 if sql.startswith("N'",i) else 1;v=''
                    while True:
                        if sql[i]=="'":
                            if sql[i+1]=="'":v+="'";i+=2;continue
                            i+=1;break
                        v+=sql[i];i+=1
                else:
                    j=i
                    while sql[i] not in ',)':i+=1
                    token=sql[j:i].strip()
                    v=None if token=='NULL' else float(token) if '.' in token else int(token)
                row.append(v)
                if sql[i]==')':i+=1;break
                assert sql[i]==',';i+=1
            rows.append(row)
            while sql[i].isspace():i+=1
            if sql[i]==';':break
            assert sql[i]==',';i+=1
        found.setdefault(name,[]).extend(rows)
    return found

def main():
    cat=b.load('calendar.json');idx=b.load('pilot_index.json');d=b.normalise(idx,b.ROOT/'source_classifications');st=b.load('standings.json')
    assert len(cat['events'])==1079 and len(cat['event_classes'])==3563
    events={e['uuid']:e for e in cat['events']};assert len(events)==1079
    ecs={(e['uuid'],e['class_name']):e for e in cat['event_classes']};assert len(ecs)==3563
    for ec in ecs.values():assert ec['year']==events[ec['uuid']]['year']
    # The TT's class-specific circuit override must survive import generation.
    for ec in ecs.values():
        ev=events[ec['uuid']]
        if ev['short']=='TT' and ec['year']==1955 and ec['class_name']=='250cc':assert ec['circuit']=='Clypse Course'
    # Repeated visits are distinct events, not overwritten season/circuit pairs.
    jerez=[e for e in events.values() if e['year']==2020 and e['circuit']=='Circuito de Jerez - Ángel Nieto']
    assert len(jerez)==2
    races={r[0]:r for r in d['races']};assert len(races)==26
    assert len(d['sessions'])==27 and len(d['results'])==502
    assert all((r[1],r[2]) in ecs for r in races.values())
    sessions={s[0]:s for s in d['sessions']};sets={s[0]:s for s in d['sets']}
    entries={(e[0],e[1]):e for e in d['entries']};assert len(entries)==475
    assert len({(r[0],r[2]) for r in d['results']})==502
    for rr in d['results']:
        assert (rr[1],rr[2]) in entries and rr[0] in sets
        assert sets[rr[0]][1]==rr[1]
        assert (rr[4]=='CLASSIFIED')==(rr[3] is not None)
        assert rr[12] is None or rr[12]>=0
    counts=collections.Counter(s[1] for s in sessions.values() if s[6]);assert all(n==1 for n in counts.values())
    current=[rr for rr in d['results'] if sessions[sets[rr[0]][2]][6]]
    assert len(current)==475
    def query(year,short,cl,kind='GP'):
        keys={k for k,r in races.items() if events[r[1]]['year']==year and events[r[1]]['short']==short and r[2]==cl and r[3]==kind}
        return [rr for rr in current if rr[1] in keys]
    assert not query(2018,'GBR','MotoGP')
    q=query(2026,'THA','Moto2');assert len(q)==27 and next(r for r in q if r[3]==1)[12]==12.5
    assert next(r for r in query(2025,'THA','MotoGP') if r[3]==1)[12]==25
    assert next(r for r in query(2025,'THA','MotoGP','SPRINT') if r[3]==1)[12]==12
    assert any(entries[(r[1],r[2])][4]=='Marc Marquez' and r[4]=='DSQ' for r in query(2013,'AUS','MotoGP'))
    assert all(r[12] is None for r in query(1999,'MAL','500cc'))
    assert len(query(2025,'FRA','MotoE','RACE'))==33
    assert len(st['standings'])==8701 and len({(r[0],r[1]) for r in st['standings']})==8701
    assert next(r for r in st['standings'] if r[0]=='1967_500cc_RIDER' and r[2]=='Giacomo Agostini')[5]==46
    # Compare the actual SQL literals to reviewed data, including Unicode/apostrophes.
    actual=sql_rows((b.ROOT/'16_import_pilot_results.sql').read_text(encoding='utf-8-sig'))
    for name,key in [('r','races'),('s','sessions'),('rs','sets'),('en','entries'),('res','results')]:assert actual[name]==d[key],name
    cal=sql_rows((b.ROOT/'15_import_calendar.sql').read_text(encoding='utf-8-sig'))
    assert len(cal['events'])==1079 and len(cal['ec'])==3563
    standings=sql_rows((b.ROOT/'17_import_rider_standings.sql').read_text(encoding='utf-8-sig'))
    assert standings['ch']==st['championships'] and standings['st']==st['standings']
    # Check declared temp-field lengths to prevent truncation in SQL Server.
    for filename in ['15_import_calendar.sql','16_import_pilot_results.sql','17_import_rider_standings.sql']:
        sql=(b.ROOT/filename).read_text(encoding='utf-8-sig');rows=sql_rows(sql)
        for m in re.finditer(r'CREATE TABLE #(\w+) \(([^\n]+)\);',sql):
            fields=re.findall(r'\[([^\]]+)\] ([a-z]+)(?:\((\d+)(?:,\d+)?\))?',m.group(2))
            for row in rows.get(m.group(1),[]):
                assert len(row)==len(fields)
                for value,(name,typ,n) in zip(row,fields):
                    if value is not None and typ in ('nvarchar','varchar','char'):assert len(str(value))<=int(n),(name,value)
    result={'status':'PASS','calendar_events':1079,'event_classes':3563,'logical_pilot_races':26,'source_sessions':27,'raw_result_rows':502,'current_scoring_result_rows':475,'rider_standings_rows':8701,'unknown_points_source_rows':sum(r[12] is None for r in d['results']),'sql_server_executed':False,'checks':['calendar keys and repeated visits','TT class-specific circuits','restart selection and cancelled-race exclusion','Sprint versus GP points','2026 half-points','2013 disqualification','unknown historical points','MotoE doubleheader','1967 published standings','SQL literal round-trip and field widths']}
    b.dump('validation.json',result);print(json.dumps(result,indent=2))
if __name__=='__main__':main()

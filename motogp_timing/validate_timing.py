"""Offline data and parser regression checks; this does not execute SQL Server scripts."""
from pathlib import Path
import json,collections,hashlib
from build_timing import validate,load,ROOT
from parse_timing import seconds

def main():
 d=load(ROOT/'timing_2025_normalised.json');validate(d)
 assert seconds("1'30.637")==90.637
 assert seconds('01:28.782')==88.782
 assert seconds('00:00.000') is None
 try:seconds('1:99.999')
 except ValueError:pass
 else:raise AssertionError('Invalid time accepted')
 source=load(ROOT/'source_manifest.json');assert not source['errors'];byid={x['session']['id']:x for x in source['sessions']}
 assert len(byid)==len(source['sessions'])
 assert all(x['parse_status']=='PARSED' for x in d['documents']), 'One or more documents withheld; inspect the audit'
 sid='8a982e72-625e-440f-aad8-5bd8801944ad' # Thailand MotoGP GP, visually inspected timing sheets.
 first=next(r for r in d['fastest'] if r['sid']==sid and r['published_rank']==1)
 assert (first['source_rider_key'],first['best_lap_seconds'],first['best_lap_number'])==('MGP_7444',90.637,4)
 assert sum(r['sid']==sid for r in d['laps'])==556
 assert next(r for r in d['grids'] if r['sid']==sid and r['grid_position']==1)['source_rider_key']=='MGP_7444'
 # Every published personal best must match the named lap in the separate analysis sheet.
 laps={(r['sid'],r['source_rider_key'],r['lap_number']):r for r in d['laps']}
 for f in d['fastest']:
  r=laps[(f['sid'],f['source_rider_key'],f['best_lap_number'])]
  assert abs(r['lap_time_seconds']-f['best_lap_seconds'])<0.0005 and not r['lap_time_cancelled']
 # Expected source gap, not a fabricated time: Hungary's incomplete Bastianini lap.
 issues=load(ROOT/'22_timing_2025_audit.json')['issues']
 lapgaps=[i for i in issues if i['component']=='lap_count_difference']
 assert len(lapgaps)==1 and lapgaps[0]['event']=='HUN' and 'MGP_8295' in lapgaps[0]['reason']
 # Keep source disagreement separate from reported fastest lap.
 aus='48f6c85f-c74d-4b8b-a2a6-6aaba1feb126'
 f=next(r for r in d['fastest'] if r['sid']==aus and r['published_rank']==1)
 assert f['source_rider_key']=='MGP_8688' and f['best_lap_seconds']==87.122
 rec=next(r for r in d['records'] if r['sid']==aus and r['record_type']=='fastestLap')
 assert rec['key']=='MGP_8173' and rec['lap_time_seconds']==87.782
 # All accepted rows have one revision/session and an entry; every advertised race PDF is represented.
 revisions={r['revision']:r['sid'] for r in d['revisions']}
 for k in ['documents','qualifying','records','fastest','grids','laps','issues']:
  assert all(revisions[r['revision']]==r['sid'] for r in d[k])
 assert len({r['sid'] for r in d['grids']})==102
 assert len({r['sid'] for r in d['fastest']})==102
 assert len({r['sid'] for r in d['laps']})==102
 assert len({r['sid'] for r in d['qualifying']})==146
 report={'passed':True,'counts':{k:len(v) for k,v in d.items()},'checks':['Stable source and relational keys','SQL string widths, UUIDs, SMALLINT bounds and positive-duration constraints','248 session classifications and 306 timing PDF documents parsed','Every published personal best agrees with corresponding individual lap','Thailand known-value checks','Australia API/PDF conflict retained and reported using confirmed PDF data','Hungary unfinished-lap exception retained','All four classes and race types covered'],'limitations':['SQL scripts have not been executed against a live SQL Server.','Checks establish consistency with supplied archive sources, not independent certification of every historical fact.']}
 (ROOT/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
if __name__=='__main__':main()

"""Collect official season-associated image URLs. Does not connect to SQL Server.
Python standard library only. Usage: py fetch_rider_images.py --year 2025
"""
import argparse, collections, concurrent.futures, datetime, hashlib, json
from pathlib import Path
import re, urllib.request, urllib.parse, urllib.error

ROOT = Path(__file__).resolve().parent
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()

def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

def request(url):
    p = urllib.parse.urlsplit(url)
    if p.scheme != 'https' or not (p.hostname == 'motogp.com' or (p.hostname or '').endswith('.motogp.com')):
        raise ValueError('Unexpected source host')
    url = urllib.parse.urlunsplit((p.scheme, p.netloc, urllib.parse.quote(p.path, safe='/%:@'), p.query, ''))
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'MotoGP-personal-research/1.0'}), timeout=30)

def inspect_image(url, refresh=False):
    key = hashlib.sha256(url.encode()).hexdigest()
    meta = ROOT/'cache'/(key+'.json')
    if meta.exists() and not refresh:
        return json.loads(meta.read_text(encoding='utf-8'))
    result = {'url': url, 'checked_at': NOW}
    try:
        if re.search(r'placeholder|default|no[-_]?(photo|image)|silhouette', url, re.I):
            result['status'] = 'PLACEHOLDER'
        else:
            with request(url) as response:
                data = response.read(10_000_001)
                mime = response.headers.get('Content-Type', '').split(';')[0]
                valid = data.startswith(b'\x89PNG\r\n\x1a\n') or data.startswith(b'\xff\xd8\xff') or data.startswith((b'GIF87a', b'GIF89a'))
                result.update(status='VERIFIED' if valid and 1024 < len(data) <= 10_000_000 else 'NOT_USABLE_IMAGE', mime=mime, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
                if result['status'] == 'VERIFIED':
                    binary = ROOT/'cache'/(key+'.image')
                    binary.parent.mkdir(parents=True, exist_ok=True)
                    binary.write_bytes(data)
    except Exception as ex:
        result.update(status='FETCH_FAILED', error=str(ex))
    save(meta, result)
    return result

def lit(value):
    if value is None: return 'NULL'
    if isinstance(value, int): return str(value)
    return "N'" + str(value).replace("'", "''") + "'"

COLS = ['source_rider_uuid','season_year','class_name','source_display_name','source_team_name','rider_number','candidate_image_url','image_url','image_status','season_evidence','source_url','retrieved_at','checked_at','image_sha256']

def build_sql(year, rows):
    sql = '''USE MotoGP;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 50250, 'Finish the existing transaction before importing photos.', 1;
IF OBJECT_ID(N'dbo.rider_season_images', N'U') IS NULL THROW 50251, 'Run script 25 first.', 1;
BEGIN TRY
BEGIN TRANSACTION;
CREATE TABLE #photos (
 source_rider_uuid UNIQUEIDENTIFIER NOT NULL, season_year SMALLINT NOT NULL,
 class_name NVARCHAR(20) NOT NULL, source_display_name NVARCHAR(150) NOT NULL,
 source_team_name NVARCHAR(200) NULL, rider_number INT NULL,
 candidate_image_url NVARCHAR(2048) NULL, image_url NVARCHAR(2048) NULL,
 image_status VARCHAR(40) NOT NULL, season_evidence VARCHAR(40) NOT NULL,
 source_url NVARCHAR(2048) NULL, retrieved_at VARCHAR(40) NOT NULL,
 checked_at VARCHAR(40) NULL, image_sha256 CHAR(64) NULL,
 PRIMARY KEY(source_rider_uuid,season_year,class_name));
'''
    for start in range(0, len(rows), 100):
        sql += 'INSERT INTO #photos (' + ','.join(COLS) + ') VALUES\n'
        sql += ',\n'.join('('+','.join(lit(row[c]) for c in COLS)+')' for row in rows[start:start+100])+';\n'
    sql += '''IF EXISTS(SELECT 1 FROM #photos p LEFT JOIN motogp_source.riders r ON r.source_rider_uuid=p.source_rider_uuid WHERE r.source_rider_uuid IS NULL)
 THROW 50252, 'Photo source has rider IDs absent from script 08. Reconcile the new identities first.', 1;
'''
    keys = 't.source_rider_uuid=p.source_rider_uuid AND t.season_year=p.season_year AND t.class_name=p.class_name'
    sql += 'UPDATE t SET '+','.join('t.'+c+'=p.'+c for c in COLS[3:])+f' FROM dbo.rider_season_images t JOIN #photos p ON {keys};\n'
    sql += 'INSERT INTO dbo.rider_season_images ('+','.join(COLS)+') SELECT '+','.join('p.'+c for c in COLS)+f' FROM #photos p WHERE NOT EXISTS(SELECT 1 FROM dbo.rider_season_images t WHERE {keys});\n'
    sql += f'''COMMIT TRANSACTION;
SELECT season_year,class_name,image_status,COUNT(*) AS rider_rows
FROM dbo.rider_season_images WHERE season_year={year}
GROUP BY season_year,class_name,image_status ORDER BY class_name,image_status;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
'''
    (ROOT/f'26_import_rider_images_{year}.sql').write_text(sql, encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--year', type=int, default=2025)
    parser.add_argument('--workers', type=int, choices=range(1,5), default=4)
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    sources = [s for s in json.loads((ROOT/'season_sources.json').read_text()) if s['season']==args.year]
    if not sources: raise SystemExit('Year absent from bundled source catalogue (1949–2026).')
    identities = {r['source_rider_uuid']:r for r in json.loads((ROOT/'rider_index.json').read_text())}
    expected = {(r['source_rider_uuid'],r['class_name']) for r in json.loads((ROOT/'expected_season_riders.json').read_text()) if r['season']==args.year}
    rows = {}; problems = []
    for source in sources:
        cache = ROOT/'cache'/f"roster_{args.year}_{source['class_name']}.json"
        if cache.exists() and not args.refresh:
            roster = json.loads(cache.read_text(encoding='utf-8'))
        else:
            with request(source['source_url']) as response: roster = json.load(response)
            if not isinstance(roster,list): raise ValueError('Unexpected roster response')
            save(cache, roster)
        retrieved_at = datetime.datetime.fromtimestamp(cache.stat().st_mtime, datetime.timezone.utc).isoformat()
        for rider in roster:
            uid = rider['id']; cl = source['class_name']; key=(uid,cl)
            if uid not in identities:
                problems.append({'unknown_rider':uid,'class':cl}); continue
            if rider.get('legacy_id') != identities[uid]['motogp_legacy_id']:
                problems.append({'identity_conflict':uid,'class':cl}); continue
            step = rider.get('current_career_step') or {}
            matches = step.get('season')==args.year and (step.get('category') or {}).get('name','').replace('™','')==cl
            pics = step.get('pictures') or {}
            url = ((pics.get('profile') or {}).get('main') or pics.get('portrait')) if matches else None
            season_evidence = 'YEAR_IN_IMAGE_PATH' if url and re.search(r'/'+str(args.year)+r'/',url) else 'ROSTER_ASSOCIATION_ONLY' if url else 'NONE'
            row = dict(source_rider_uuid=uid,season_year=args.year,class_name=cl,source_display_name=identities[uid]['display_name'],source_team_name=step.get('sponsored_team') if matches else None,rider_number=step.get('number') if matches else None,candidate_image_url=url,image_url=None,image_status='PENDING' if url else 'MISSING',season_evidence=season_evidence,source_url=source['source_url'],retrieved_at=NOW,checked_at=None,image_sha256=None)
            row['retrieved_at'] = retrieved_at
            if key in rows:
                rows[key].update(candidate_image_url=None,image_status='AMBIGUOUS_ROSTER',season_evidence='NONE')
                problems.append({'duplicate_rider_class':list(key)})
            else: rows[key]=row
        print(f"Roster: {args.year} {source['class_name']}: {len(roster)} riders",flush=True)
    for uid,cl in expected-set(rows):
        rows[(uid,cl)] = dict(source_rider_uuid=uid,season_year=args.year,class_name=cl,source_display_name=identities[uid]['display_name'],source_team_name=None,rider_number=None,candidate_image_url=None,image_url=None,image_status='NOT_IN_ROSTER',season_evidence='NONE',source_url=None,retrieved_at=NOW,checked_at=None,image_sha256=None)
    urls = sorted({r['candidate_image_url'] for r in rows.values() if r['candidate_image_url']})
    checks={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures={pool.submit(inspect_image,url,args.refresh):url for url in urls}
        for n,f in enumerate(concurrent.futures.as_completed(futures),1):
            checks[futures[f]]=f.result()
            if n%20==0 or n==len(urls): print(f'Images checked: {n}/{len(urls)}',flush=True)
    hashes=collections.defaultdict(set)
    for r in rows.values():
        check=checks.get(r['candidate_image_url'],{})
        if check.get('sha256'): hashes[check['sha256']].add(r['source_rider_uuid'])
    for r in rows.values():
        check=checks.get(r['candidate_image_url'])
        if not check: continue
        r.update(image_status=check['status'],checked_at=check['checked_at'],image_sha256=check.get('sha256'))
        if len(hashes.get(check.get('sha256'),set()))>1: r['image_status']='SHARED_IMAGE_REVIEW'
        if r['image_status']=='VERIFIED':
            if r['season_evidence']=='YEAR_IN_IMAGE_PATH': r['image_url']=r['candidate_image_url']
            else: r['image_status']='UNDATED_IMAGE_REVIEW'
    rows=sorted(rows.values(), key=lambda r:(r['class_name'],r['source_display_name']))
    assert len({(r['source_rider_uuid'],r['season_year'],r['class_name']) for r in rows})==len(rows)
    for r in rows:
        for col,limit in [('source_display_name',150),('source_team_name',200),('class_name',20),('candidate_image_url',2048),('source_url',2048)]:
            assert len(r[col] or '')<=limit,(col,r)
    audit={'year':args.year,'built_at':NOW,'rider_season_class_rows':len(rows),'displayable_photos':sum(bool(r['image_url']) for r in rows),'status_counts':dict(collections.Counter(r['image_status'] for r in rows)),'by_class':{cl:dict(collections.Counter(r['image_status'] for r in rows if r['class_name']==cl)) for cl in sorted({r['class_name'] for r in rows})},'source_problems':problems,'exceptions':[r for r in rows if not r['image_url']],'limitations':['Year in URL and season roster association are source evidence, not a visual certification of every team livery.','Images may change or disappear from their external host.','Older undated images are withheld from automatic season-specific display.','Single season/class portraits cannot represent all mid-season team changes.','No public reuse licence is granted by this dataset.','SQL Server and Power BI execution require local verification.']}
    save(ROOT/f'rider_images_{args.year}.json',rows)
    save(ROOT/f'image_audit_{args.year}.json',audit)
    if problems: raise SystemExit('Source identity/duplicate problems recorded: review audit before generating SQL.')
    build_sql(args.year,rows)
    print(json.dumps({k:v for k,v in audit.items() if k not in ('exceptions','limitations')},indent=2))

if __name__=='__main__': main()

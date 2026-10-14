"""Strict parsers for official 2025 timing PDFs; uncertain documents are withheld."""
import re, decimal, collections
from pathlib import Path
import fitz
D=decimal.Decimal
TIME=r"\d{1,3}[':]\d{2}\.\d{3}"
def seconds(value):
 if value is None or value=='':return None
 s=str(value).strip().replace("'",':')
 if not re.fullmatch(r'\d{1,3}:\d{2}\.\d{3}',s):raise ValueError('Unrecognised time: '+s)
 m,sec=s.split(':')
 if D(sec)>=60:raise ValueError('Seconds out of range: '+s)
 v=D(m)*60+D(sec)
 return float(v) if v>0 else None

def text_rows(page,clip=None):
 words=page.get_text('words',clip=clip)
 groups=[]
 for w in sorted(words,key=lambda w:((w[1]+w[3])/2,w[0])):
  y=(w[1]+w[3])/2
  if groups and abs(groups[-1][0]-y)<2.2:groups[-1][1].append(w)
  else:groups.append([y,[w]])
 return [(y,sorted(ws,key=lambda w:w[0])) for y,ws in groups]
def fast_laps(path,roster):
 doc=fitz.open(path);out=[];candidate=0
 for page in doc:
  for y,ws in text_rows(page):
   line=' '.join(w[4] for w in ws)
   m=re.match(r'^\s*(\d+)\s+(\d+)\s+(.+?)\s+('+TIME+r')\s+(\d+)\s+(\d+)(?:\s|$)',line)
   if not m:continue
   candidate+=1;rank,number=int(m[1]),int(m[2])
   if number not in roster:raise ValueError('Fast-lap rider number not mapped: '+str(number))
   out.append({'source_rider_key':roster[number]['key'],'rider_number':number,'published_rank':rank,'best_lap_seconds':seconds(m[4]),'best_lap_number':int(m[5]),'total_laps':int(m[6]),'source_text':line,'page':page.number+1})
 if not out:raise ValueError('No fastest-lap rows parsed')
 if len({r['source_rider_key'] for r in out})!=len(out):raise ValueError('Duplicate fastest-lap rider')
 if sorted(r['published_rank'] for r in out)!=list(range(1,len(out)+1)):raise ValueError('Fastest-lap ranks are incomplete')
 if any(r['best_lap_number']<1 or r['best_lap_number']>r['total_laps'] for r in out):raise ValueError('Fastest-lap number out of range')
 # Every apparent table rank must be recovered, including nonstandard time formats.
 expected=[]
 for p in doc:
  for y,ws in text_rows(p):
   if len(ws)>2 and ws[0][0]<45 and ws[0][4].isdigit() and ws[1][4].isdigit():expected.append(int(ws[0][4]))
 if len(expected)!=len(out):raise ValueError('Some fastest-lap table rows were not parsed')
 return out

def grid(path,roster):
 doc=fitz.open(path);text='\n'.join(p.get_text() for p in doc)
 status='OFFICIAL' if 'OFFICIAL STARTING GRID' in text else ('PROVISIONAL' if 'PROVISIONAL STARTING GRID' in text else ('PUBLISHED' if 'TISSOT SPRINT - STARTING GRID' in text else 'UNKNOWN'))
 if status=='UNKNOWN':raise ValueError('Unrecognised grid title')
 out=[]
 for page in doc:
  for block in page.get_text('dict')['blocks']:
   for line in block.get('lines',[]):
    for span in line['spans']:
     v=span['text'].strip();x0,y0,x1,y1=span['bbox']
     if not (v.isdigit() and span['size']>=12 and x0>100 and 130<y0<760):continue
     pos=int(v);center=(x0+x1)/2
     clip=fitz.Rect(max(95,center-87),y1-1,min(page.rect.width,center+87),min(y1+41,780))
     lines=[' '.join(w[4] for w in ws) for _,ws in text_rows(page,clip)]
     name=next((re.match(r'^(\d{1,3})\s+([A-Za-zÀ-ž].*)$',t) for t in lines if re.match(r'^(\d{1,3})\s+([A-Za-zÀ-ž].*)$',t)),None)
     if not name:raise ValueError('Cannot parse grid slot '+str(pos))
     num=int(name[1])
     if num not in roster:raise ValueError('Grid rider not mapped: '+str(num))
     times=[re.fullmatch(TIME,t) for t in lines]
     tm=next((m[0] for m in times if m),None)
     out.append({'source_rider_key':roster[num]['key'],'rider_number':num,'grid_position':pos,'qualifying_time_seconds':seconds(tm),'source_text':' | '.join(lines),'page':page.number+1})
 if not out:raise ValueError('No grid slots parsed')
 if len({r['grid_position'] for r in out})!=len(out) or len({r['source_rider_key'] for r in out})!=len(out):raise ValueError('Duplicate grid position/rider')
 # Published grid positions need not be contiguous after withdrawals.
 return status,out

def lap_times(path,roster,fastest,notes=None):
 doc=fitz.open(path);out=[];current=None;unparsed=[]
 for page in doc:
  # Read left column, then right column. Rider blocks can continue across columns/pages.
  for a,b in [(25,297),(297,570)]:
   clip=fitz.Rect(a,170 if page.number==0 else 56,b,732)
   words=page.get_text('words',clip=clip)
   heads=[]
   for w in words:
    rel=w[0]-(0 if a==25 else 270)
    if w[4].isdigit() and w[3]-w[1]>15 and 58<rel<85:
     num=int(w[4])
     if num not in roster:raise ValueError('Lap rider not mapped: '+str(num))
     heads.append(((w[1]+w[3])/2,num))
   events=[(y,'head',num) for y,num in heads]
   for y,ws in text_rows(page,clip):
    if not ws:continue
    rel=ws[0][0]-(0 if a==25 else 270)
    if 29<rel<49 and ws[0][4].isdigit() and ws[0][3]-ws[0][1]<13:
     events.append((y,'lap',ws))
    elif any(w[4]=='unfinished' for w in ws):events.append((y,'partial',ws))
   for y,kind,value in sorted(events,key=lambda e:(e[0],e[1])):
    if kind=='head':current=value;continue
    ws=value;line=' '.join(w[4] for w in ws)
    if current is None:raise ValueError('Lap before rider header')
    if 'unfinished' in line:
     if notes is not None:notes.append({'rider':roster[current]['key'],'page':page.number+1,'source_text':line})
     continue
    # Split by fixed printed columns; source symbols stay with their own time.
    offset=0 if a==25 else 270
    bounds=[(29,53),(53,106),(106,148),(148,186),(186,224),(224,264),(264,295)]
    cells=[' '.join(w[4] for w in ws if lo<=w[0]-offset<hi) for lo,hi in bounds]
    m=re.search(TIME,cells[1])
    if not m:
     unparsed.append({'rider_number':current,'text':line});continue
    sectors=[];flags=[]
    for cell in cells[2:6]:
     q=re.search(TIME,cell) or re.search(r'\d+\.\d{3}',cell);sectors.append((seconds(q[0]) if ("'" in q[0] or ':' in q[0]) else float(q[0])) if q else None);flags.append('*' in cell)
    sp=re.search(r'\d+\.\d+',cells[6])
    out.append({'source_rider_key':roster[current]['key'],'rider_number':current,'lap_number':int(cells[0]),'lap_time_seconds':seconds(m[0]),'lap_time_cancelled':'*' in cells[1],'pit_lane_crossing':'P' in cells[1],'sector1_seconds':sectors[0],'sector2_seconds':sectors[1],'sector3_seconds':sectors[2],'sector4_seconds':sectors[3],'sector1_cancelled':flags[0],'sector2_cancelled':flags[1],'sector3_cancelled':flags[2],'sector4_cancelled':flags[3],'speed_kmh':float(sp[0]) if sp else None,'page':page.number+1,'source_text':line})
 if unparsed:raise ValueError('Unparsed lap rows: '+str(unparsed[:3]))
 if not out:raise ValueError('No laps parsed')
 if len({(r['source_rider_key'],r['lap_number']) for r in out})!=len(out):raise ValueError('Duplicate rider/lap')
 grouped=collections.defaultdict(list)
 for r in out:grouped[r['source_rider_key']].append(r)
 for f in fastest:
  rows=grouped.get(f['source_rider_key'],[])
  nums=sorted(r['lap_number'] for r in rows)
  if nums!=list(range(1,f['total_laps']+1)):raise ValueError('Lap coverage differs from FastLapRider for '+f['source_rider_key'])
  best=[r for r in rows if r['lap_number']==f['best_lap_number']]
  if not best or abs(best[0]['lap_time_seconds']-f['best_lap_seconds'])>0.0005 or best[0]['lap_time_cancelled']:raise ValueError('Published best lap does not match analysis for '+f['source_rider_key'])
 return out

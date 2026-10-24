#!/usr/bin/env python3
"""Bounded stdlib HTTP test. Run only against your assessment deployment."""
import argparse,concurrent.futures,json,math,os,time,urllib.request,urllib.error
from datetime import datetime,timezone
p=argparse.ArgumentParser()
p.add_argument('--url',required=True);p.add_argument('--duration',type=int,default=180)
p.add_argument('--concurrency',type=int,default=20);p.add_argument('--output',required=True)
a=p.parse_args()
if not (1<=a.duration<=600 and 1<=a.concurrency<=100):p.error('duration 1..600, concurrency 1..100')
if not a.url.startswith(('http://','https://')):p.error('Use an http(s) URL')
headers={}
if os.environ.get('LOAD_TEST_TOKEN'):headers['X-Load-Test-Token']=os.environ['LOAD_TEST_TOKEN']
started=datetime.now(timezone.utc).isoformat();begin=time.monotonic();end=begin+a.duration
# Each worker aggregates a bounded sample and all request/error counts.
def worker():
 samples=[];codes={};success=0;count=0
 while time.monotonic()<end:
  t=time.monotonic()
  try:
   with urllib.request.urlopen(urllib.request.Request(a.url,headers=headers),timeout=10) as r:r.read();code=str(r.status)
  except urllib.error.HTTPError as e:code=str(e.code);e.close()
  except Exception:code='connection_error'
  ms=(time.monotonic()-t)*1000;count+=1;codes[code]=codes.get(code,0)+1
  if code=='200':success+=1
  if len(samples)<100000:samples.append(ms)
 return samples,codes,success,count
with concurrent.futures.ThreadPoolExecutor(max_workers=a.concurrency) as pool:results=list(pool.map(lambda _:worker(),range(a.concurrency)))
elapsed=time.monotonic()-begin;lat=sorted(x for r in results for x in r[0]);codes={}
for r in results:
 for k,v in r[1].items():codes[k]=codes.get(k,0)+v
count=sum(r[3] for r in results);success=sum(r[2] for r in results)
def pct(q):return round(lat[max(0,math.ceil(len(lat)*q)-1)],2) if lat else None
out={'started_utc':started,'url':a.url,'requested_duration_seconds':a.duration,'elapsed_seconds':round(elapsed,2),'concurrency':a.concurrency,'requests':count,'successful_requests':success,'failed_requests':count-success,'requests_per_second':round(count/elapsed,2),'successful_requests_per_second':round(success/elapsed,2),'p50_ms':pct(.5),'p95_ms':pct(.95),'p99_ms':pct(.99),'latency_sample_count':len(lat),'status_counts':codes,'measurement_note':'Client round trip, new HTTP connection per request. Percentiles include errors. Not a production SLO measurement.'}
with open(a.output,'w') as f:json.dump(out,f,indent=2)
print(json.dumps(out,indent=2))

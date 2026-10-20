import re, glob, os, sys
files={}
for f in glob.glob('**/*.md', recursive=True):
    m=re.match(r'(?:notes_)?(\d\d)-', os.path.basename(f))
    if m: files[m.group(1)]=f
heads={}
for n,f in files.items():
    heads[n]={m.group(1): m.group(2).strip()
              for m in re.finditer(r'^###\s+(\d+\.\d+)\s+(.*)$', open(f).read(), re.M)}
target=sys.argv[1]
seen=set()
for ln,line in enumerate(open(target).read().split('\n'),1):
    for tgt,sec in re.findall(r'[Nn]ote\s+(\d\d)\s+§(\d+\.\d+)', line):
        key=(tgt,sec)
        if key in seen: continue
        seen.add(key)
        title=heads.get(tgt,{}).get(sec)
        status="OK " if title else "!! "
        print(f"  {status} note {tgt} §{sec}  ->  {title or 'SECTION DOES NOT EXIST'}")

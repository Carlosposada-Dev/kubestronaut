import re, glob, os
files={}
for f in glob.glob('**/*.md', recursive=True):
    m=re.match(r'(?:notes_)?(\d\d)-', os.path.basename(f))
    if m: files[m.group(1)]=f
heads={n:set(re.findall(r'^###\s+(\d+\.\d+)',open(f).read(),re.M)) for n,f in files.items()}
bad=[]
for n,f in sorted(files.items()):
    for ln,line in enumerate(open(f).read().split('\n'),1):
        for tgt,sec in re.findall(r'[Nn]ote\s+(\d\d)\s+§(\d+\.\d+)',line):
            if tgt not in heads: bad.append((f,ln,tgt,sec,"target file not in this dir"))
            elif sec not in heads[tgt]:
                mx=sorted(heads[tgt],key=lambda x:[int(p) for p in x.split('.')])[-1]
                bad.append((f,ln,tgt,sec,f"note {tgt} only goes to §{mx}"))
print(f"BROKEN: {len(bad)}" if bad else "✅ All cross-references resolve.")
for f,ln,t,s,w in bad: print(f"  {f}:{ln} -> note {t} §{s}  ({w})")

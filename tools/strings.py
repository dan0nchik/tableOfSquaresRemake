"""Collects every localizable key the compiler found (from .stringsdata) into tools/source.json."""
import json, glob, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = {}
for f in glob.glob(f'{root}/build/dd/Build/Intermediates.noindex/**/*.stringsdata', recursive=True):
    d = json.load(open(f))
    target = 'widget' if '/SquareOfDay.build/' in f else 'app'
    for table, items in d.get('tables', {}).items():
        for it in items:
            k = it['key']
            out.setdefault(k, {'targets': set(), 'files': set()})
            out[k]['targets'].add(target); out[k]['files'].add(os.path.basename(d['source']))
res = {k: {'targets': sorted(v['targets']), 'files': sorted(v['files'])} for k, v in sorted(out.items())}
json.dump(res, open(f'{root}/tools/source.json', 'w'), ensure_ascii=False, indent=1)
print(len(res), 'keys')

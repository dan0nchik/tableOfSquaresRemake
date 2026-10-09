"""Builds the String Catalogs (app, widget, InfoPlist) from tools/source.json and tools/tr/*.json."""
import json, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = json.load(open(f'{root}/tools/source.json'))
langs = sorted(f[:-5] for f in os.listdir(f'{root}/tools/tr') if f.endswith('.json'))
tr = {l: json.load(open(f'{root}/tools/tr/{l}.json')) for l in langs}

def unit(v): return {"stringUnit": {"state": "translated", "value": v}}

def catalog(keys):
    strings = {}
    for k in sorted(keys):
        locs = {l: unit(tr[l][k]) for l in langs if k in tr[l]}
        strings[k] = {"localizations": locs} if locs else {}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}

def write(path, data):
    with open(path, 'w') as f: json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True); f.write('\n')

write(f'{root}/App/Resources/Localizable.xcstrings', catalog([k for k, v in src.items() if 'app' in v['targets']]))
write(f'{root}/Widget/Localizable.xcstrings', catalog([k for k, v in src.items() if 'widget' in v['targets']]))
name = "Table of Squares"
info = {"sourceLanguage": "en", "version": "1.0", "strings": {
    "CFBundleDisplayName": {"localizations": {"en": unit("Squares"), **{l: unit(tr[l]["Squares"]) for l in langs}}},
    "CFBundleName": {"localizations": {"en": unit(name), **{l: unit(tr[l][name]) for l in langs if name in tr[l]}}},
}}
write(f'{root}/App/Resources/InfoPlist.xcstrings', info)
write(f'{root}/Widget/InfoPlist.xcstrings', info)
print(len(langs), 'languages:', ' '.join(langs))

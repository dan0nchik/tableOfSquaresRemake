"""Validates tools/tr/<lang>.json against tools/source.json: every key, same placeholders, no emoji, no middle dot."""
import json, re, sys, os
root = os.path.dirname(os.path.abspath(__file__))
src = json.load(open(f'{root}/source.json'))
PH = re.compile(r'%(?:(\d+)\$)?(lld|@|d)')

def phs(s):
    out = []; i = 0
    for m in PH.finditer(s):
        i += 1; out.append((int(m.group(1)) if m.group(1) else i, m.group(2)))
    return sorted(out)

def emoji(s):
    return [c for c in s if ord(c) >= 0x1F000 or 0x2600 <= ord(c) <= 0x27BF or ord(c) in (0xFE0F, 0x200D)]

def check(lang):
    errs = []
    try: tr = json.load(open(f'{root}/tr/{lang}.json'))
    except Exception as e: return [f'cannot read: {e}']
    for k in src:
        if k not in tr: errs.append(f'missing: {k!r}'); continue
        v = tr[k]
        if not isinstance(v, str) or not v.strip(): errs.append(f'empty: {k!r}'); continue
        if phs(k) != phs(v): errs.append(f'placeholders differ: {k!r} -> {v!r}')
        if emoji(v): errs.append(f'emoji: {v!r}')
        if '·' in v: errs.append(f'middle dot: {v!r}')
    for k in tr:
        if k not in src: errs.append(f'extra key: {k!r}')
    return errs

if __name__ == '__main__':
    langs = sys.argv[1:] or [f[:-5] for f in sorted(os.listdir(f'{root}/tr')) if f.endswith('.json')]
    bad = 0
    for l in langs:
        e = check(l)
        print(f'{l}: {"OK" if not e else str(len(e)) + " problems"}')
        for x in e[:30]: print('   ', x)
        bad += bool(e)
    sys.exit(1 if bad else 0)

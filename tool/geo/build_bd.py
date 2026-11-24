# Bangladesh detail layer for the globe from geoBoundaries gbOpen BGD (BBS / OCHA, CC BY 3.0 IGO):
# division, district and upazila borders plus a label point for each district and upazila.
import json, sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from build_common import dp

src, out = sys.argv[1], sys.argv[2]

def rings(geom):
    if geom['type'] == 'Polygon':
        return geom['coordinates']
    return [r for poly in geom['coordinates'] for r in poly]

def area_centroid(ring):
    a = cx = cy = 0.0
    for i in range(len(ring) - 1):
        x0, y0 = ring[i][:2]; x1, y1 = ring[i + 1][:2]
        f = x0 * y1 - x1 * y0
        a += f; cx += (x0 + x1) * f; cy += (y0 + y1) * f
    if abs(a) < 1e-12:
        return None, 0
    return (cx / (3 * a), cy / (3 * a)), abs(a) / 2

def layer(name, tol, digits):
    d = json.load(open(f'{src}/bgd_{name}.geojson'))
    lines, labels = [], []
    for f in d['features']:
        rs = rings(f['geometry'])
        best = None
        for r in rs:
            c, a = area_centroid(r)
            if c and (best is None or a > best[1]):
                best = (c, a)
            s = dp([p[:2] for p in r], tol)
            if len(s) < 3:
                continue
            flat = []
            for x, y in s:
                flat += [round(x, digits), round(y, digits)]
            lines.append(flat)
        if best:
            labels.append({'n': f['properties']['shapeName'], 'x': round(best[0][0], 3), 'y': round(best[0][1], 3), 'a': round(best[1], 4)})
    labels.sort(key=lambda l: -l['a'])
    return lines, labels

div, divl = layer('ADM1', 0.006, 3)
dis, disl = layer('ADM2', 0.006, 3)
upa, upal = layer('ADM3', 0.01, 3)
json.dump({'div': div, 'divLabels': divl, 'dist': dis, 'distLabels': disl, 'upa': upa, 'upaLabels': upal},
          open(f'{out}/geo_bd.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(div), len(dis), len(upa), sum(len(x) for x in upa) // 2, len(disl), len(upal))

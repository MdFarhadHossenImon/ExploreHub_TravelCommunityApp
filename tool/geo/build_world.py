# Builds the globe's zoom layers from Natural Earth 10m (public domain):
#   assets/geo_admin1.json  state / division borders (simplified lines) + their label points
#   assets/geo_cities.json  cities and towns with rank and population
import json, sys

src, out = sys.argv[1], sys.argv[2]

sys.path.insert(0, __import__('os').path.dirname(__file__))
from build_common import dp

lines = json.load(open(f'{src}/ne_10m_admin_1_states_provinces_lines.geojson'))
L = []
for f in lines['features']:
    g = f['geometry']
    if not g:
        continue
    parts = [g['coordinates']] if g['type'] == 'LineString' else g['coordinates']
    if (f['properties'].get('ADM0_A3') or '') == 'BGD':
        continue
    for part in parts:
        s = dp(part, 0.04)
        if len(s) < 2 or sum(abs(s[i][0]-s[i-1][0])+abs(s[i][1]-s[i-1][1]) for i in range(1,len(s))) < 0.15:
            continue
        flat = []
        for x, y in s:
            flat += [round(x, 2), round(y, 2)]
        L.append(flat)

adm = json.load(open(f'{src}/ne_10m_admin_1_states_provinces.geojson'))
labels = []
for f in adm['features']:
    p = f['properties']
    if p.get('latitude') is None or not p.get('name') or p.get('adm0_a3') == 'BGD':
        continue
    labels.append({'n': p['name'], 'b': (p.get('name_bn') or '').replace(' বিভাগ', '').replace(' জেলা', '').replace(' প্রদেশ', ''), 'x': round(p['longitude'], 2), 'y': round(p['latitude'], 2),
                   'k': int(p.get('labelrank') or 9), 'c': p.get('adm0_a3')})
json.dump({'lines': L, 'labels': labels}, open(f'{out}/geo_admin1.json', 'w'), ensure_ascii=False, separators=(',', ':'))

pp = json.load(open(f'{src}/ne_10m_populated_places_simple.geojson'))
C = []
for f in pp['features']:
    p = f['properties']
    cap = 2 if 'Admin-0 capital' in (p.get('featurecla') or '') else (1 if 'Admin-1 capital' in (p.get('featurecla') or '') else 0)
    C.append({'n': p['name'], 'x': round(p['longitude'], 3), 'y': round(p['latitude'], 3), 'k': int(p.get('scalerank') or 10),
              'p': int(p.get('pop_max') or 0), 'c': cap})
C.sort(key=lambda c: (c['k'], -c['c'], -c['p']))
json.dump(C, open(f'{out}/geo_cities.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(L), sum(len(x) for x in L) // 2, len(labels), len(C))

# Sharper country shapes for close zoom (Natural Earth 1:50m).
hi = json.load(open(f'{src}/ne_50m_admin_0_countries.geojson'))
R = []
for f in hi['features']:
    g = f['geometry']
    if not g:
        continue
    polys = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
    for poly in polys:
        s = dp(poly[0], 0.02)
        if len(s) < 4:
            continue
        flat = []
        for x, y in s:
            flat += [round(x, 2), round(y, 2)]
        R.append(flat)
json.dump(R, open(f'{out}/geo_land50.json', 'w'), separators=(',', ':'))
print('land50', len(R), sum(len(r) for r in R) // 2)

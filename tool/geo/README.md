# Globe map detail

Builds the zoom-in layers for the Explore globe (`assets/geo_*.json`).

- World: [Natural Earth](https://www.naturalearthdata.com/) 1:10m admin-1 lines and labels, populated places, 1:50m countries (public domain).
- Bangladesh: [geoBoundaries](https://www.geoboundaries.org/) gbOpen BGD ADM1/ADM2/ADM3, from BBS and OCHA ROAP (CC BY 3.0 IGO). Administrative boundaries courtesy of geoBoundaries.org.

Put the downloaded GeoJSON files in one folder, then from the repo root:

    python3 tool/geo/build_world.py <download folder> assets
    python3 tool/geo/build_bd.py <download folder> assets

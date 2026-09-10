from __future__ import annotations

import json
import urllib.request


def fetch_terrain_altitude_m(latitude: float, longitude: float, timeout: int = 8) -> float:
    url = (
        "https://api.opentopodata.org/v1/srtm30m"
        f"?locations={latitude:.7f},{longitude:.7f}"
    )
    request = urllib.request.Request(url, headers={"User-Agent": "BETA-UAS-Omnibe/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))

    if str(data.get("status", "")).lower() != "ok":
        raise RuntimeError(f"Terrain service returned: {data}")
    results = data.get("results") or []
    if not results or results[0].get("elevation") is None:
        raise RuntimeError("No terrain elevation was returned for this point.")
    return float(results[0]["elevation"])

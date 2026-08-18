from __future__ import annotations

import json

from PyQt5.QtCore import QObject, pyqtSignal, pyqtSlot
from PyQt5.QtWebChannel import QWebChannel
from PyQt5.QtWebEngineWidgets import QWebEngineView


class MapBridge(QObject):
    location_selected = pyqtSignal(float, float)

    @pyqtSlot(float, float)
    def selectLocation(self, latitude: float, longitude: float) -> None:
        self.location_selected.emit(latitude, longitude)


class MapWidget(QWebEngineView):
    location_selected = pyqtSignal(float, float)

    def __init__(self, latitude: float, longitude: float, parent=None):
        super().__init__(parent)
        self.bridge = MapBridge()
        self.bridge.location_selected.connect(self.location_selected)
        self.channel = QWebChannel(self.page())
        self.channel.registerObject("bridge", self.bridge)
        self.page().setWebChannel(self.channel)
        self.setHtml(self._html(latitude, longitude))

    def set_location(self, latitude: float, longitude: float) -> None:
        self.page().runJavaScript(f"setLocation({latitude:.7f}, {longitude:.7f});")

    @staticmethod
    def _html(latitude: float, longitude: float) -> str:
        lat = json.dumps(latitude)
        lon = json.dumps(longitude)
        return f"""<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
html,body,#map{{height:100%;margin:0}}body{{background:#dbe4e8}}
.leaflet-control-attribution{{font-size:10px}}
.leaflet-control-layers{{border:0!important;border-radius:4px!important;box-shadow:0 1px 5px rgba(18,44,50,.28)!important}}
.leaflet-control-layers-expanded{{color:#183238;font:12px "Noto Sans","DejaVu Sans",sans-serif;padding:9px 12px!important}}
</style>
</head><body><div id="map"></div>
<script src="qrc:///qtwebchannel/qwebchannel.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const initial=[{lat},{lon}];
const map=L.map('map',{{zoomControl:true}}).setView(initial,13);
const street=L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png',{{
  maxZoom:19,attribution:'&copy; OpenStreetMap contributors'
}});
const satellite=L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{{z}}/{{y}}/{{x}}',{{
  maxZoom:19,attribution:'Tiles &copy; Esri, Maxar, Earthstar Geographics, and the GIS User Community'
}});
const labels=L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{{z}}/{{y}}/{{x}}',{{
  maxZoom:19,attribution:'Labels &copy; Esri'
}});
const hybrid=L.layerGroup([satellite,labels]).addTo(map);
L.control.layers({{'Satellite Hybrid':hybrid,'Satellite':satellite,'Street Map':street}},null,{{
  position:'topright',collapsed:true
}}).addTo(map);
const marker=L.marker(initial,{{draggable:true}}).addTo(map);
let bridge=null;
new QWebChannel(qt.webChannelTransport, channel => bridge=channel.objects.bridge);
function notify(p){{if(bridge)bridge.selectLocation(p.lat,p.lng)}}
map.on('click',e=>{{marker.setLatLng(e.latlng);notify(e.latlng)}});
marker.on('dragend',e=>notify(e.target.getLatLng()));
function setLocation(a,b){{const p=[a,b];marker.setLatLng(p);map.panTo(p)}}
</script></body></html>"""

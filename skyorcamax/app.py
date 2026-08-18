from __future__ import annotations

import signal
import sys
from pathlib import Path

import yaml
from PyQt5.QtCore import QObject, QProcess, QThread, QTimer, Qt, pyqtSignal, pyqtSlot
from PyQt5.QtGui import QCloseEvent
from PyQt5.QtWidgets import (
    QAbstractSpinBox, QApplication, QDoubleSpinBox, QFormLayout, QFrame,
    QHBoxLayout, QLabel, QMainWindow, QMessageBox, QPlainTextEdit, QPushButton,
    QSizePolicy, QSplitter, QVBoxLayout, QWidget,
)

from .map_widget import MapWidget
from .terrain import fetch_terrain_altitude_m


ROOT = Path(__file__).resolve().parent.parent


class TerrainWorker(QObject):
    finished = pyqtSignal(float, float, float)
    failed = pyqtSignal(str, float, float)

    def __init__(self, latitude: float, longitude: float):
        super().__init__()
        self.latitude = latitude
        self.longitude = longitude

    @pyqtSlot()
    def run(self) -> None:
        try:
            elevation = fetch_terrain_altitude_m(self.latitude, self.longitude)
            self.finished.emit(elevation, self.latitude, self.longitude)
        except Exception as exc:
            self.failed.emit(str(exc), self.latitude, self.longitude)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = yaml.safe_load((ROOT / "config.yaml").read_text())
        start = self.config["start_location"]
        self.process = QProcess(self)
        self.process.setProcessChannelMode(QProcess.MergedChannels)
        self.process.readyReadStandardOutput.connect(self.read_output)
        self.process.started.connect(lambda: self.set_status("RUNNING", "running"))
        self.process.finished.connect(self.process_finished)
        self.terrain_thread: QThread | None = None
        self.terrain_worker: TerrainWorker | None = None
        self.terrain_pending = False
        self.terrain_timer = QTimer(self)
        self.terrain_timer.setSingleShot(True)
        self.terrain_timer.setInterval(650)
        self.terrain_timer.timeout.connect(self.start_terrain_lookup)

        self.setWindowTitle(self.config["app"]["name"])
        self.resize(1120, 720)
        self.setMinimumSize(760, 520)
        self.build_ui(start)
        self.schedule_terrain_lookup()

    def build_ui(self, start: dict) -> None:
        root = QWidget()
        outer = QVBoxLayout(root)
        outer.setContentsMargins(18, 18, 18, 14)
        outer.setSpacing(10)

        header = QFrame()
        header.setObjectName("header")
        row = QHBoxLayout(header)
        row.setContentsMargins(18, 11, 10, 11)
        row.setSpacing(8)
        title = QLabel("SkyOrcaMax Simulator")
        title.setObjectName("title")
        subtitle = QLabel("QUADPLANE SITL")
        subtitle.setObjectName("subtitle")
        self.status = QLabel("STOPPED")
        self.status.setObjectName("status")
        self.status.setProperty("state", "stopped")
        self.status.setAlignment(Qt.AlignCenter)
        self.start_button = QPushButton("Start")
        self.start_button.setObjectName("startButton")
        self.stop_button = QPushButton("Stop")
        self.stop_button.setObjectName("stopButton")
        self.stop_button.setEnabled(False)
        self.start_button.clicked.connect(self.start_sitl)
        self.stop_button.clicked.connect(self.stop_sitl)
        row.addWidget(title)
        row.addWidget(subtitle)
        row.addStretch()
        row.addWidget(self.status)
        row.addWidget(self.start_button)
        row.addWidget(self.stop_button)
        outer.addWidget(header)

        self.map = MapWidget(start["latitude"], start["longitude"])
        self.map.setObjectName("mapView")
        self.map.setMinimumSize(340, 300)
        self.map.location_selected.connect(self.map_selected)

        controls = QFrame()
        controls.setObjectName("panel")
        controls.setMinimumWidth(280)
        controls.setMaximumWidth(340)
        controls_layout = QVBoxLayout(controls)
        controls_layout.setContentsMargins(20, 20, 20, 18)
        controls_layout.setSpacing(16)
        panel_title = QLabel("Start Location")
        panel_title.setObjectName("panelTitle")
        panel_caption = QLabel("Set the QuadPlane home position")
        panel_caption.setObjectName("panelCaption")
        controls_layout.addWidget(panel_title)
        controls_layout.addWidget(panel_caption)

        form_widget = QWidget()
        form_widget.setObjectName("formSurface")
        form = QFormLayout(form_widget)
        form.setContentsMargins(0, 6, 0, 0)
        form.setHorizontalSpacing(12)
        form.setVerticalSpacing(13)
        form.setFieldGrowthPolicy(QFormLayout.AllNonFixedFieldsGrow)
        self.latitude = self.spin(-90, 90, start["latitude"], 7)
        self.longitude = self.spin(-180, 180, start["longitude"], 7)
        self.altitude = self.spin(-500, 10000, start["altitude_m"], 1)
        self.heading = self.spin(0, 359.9, start["heading_deg"], 1)
        self.latitude.valueChanged.connect(self.inputs_changed)
        self.longitude.valueChanged.connect(self.inputs_changed)
        form.addRow("Latitude", self.latitude)
        form.addRow("Longitude", self.longitude)
        form.addRow("Altitude MSL (m)", self.altitude)
        form.addRow("Heading (deg)", self.heading)
        controls_layout.addWidget(form_widget)
        controls_layout.addStretch(1)

        horizontal = QSplitter(Qt.Horizontal)
        horizontal.addWidget(self.map)
        horizontal.addWidget(controls)
        horizontal.setHandleWidth(8)
        horizontal.setCollapsible(0, False)
        horizontal.setCollapsible(1, False)
        horizontal.setSizes([780, 300])

        self.logs = QPlainTextEdit()
        self.logs.setObjectName("logs")
        self.logs.setPlaceholderText("SITL output will appear here")
        self.logs.setReadOnly(True)
        self.logs.setMaximumBlockCount(2000)
        log_panel = QFrame()
        log_panel.setObjectName("logPanel")
        log_layout = QVBoxLayout(log_panel)
        log_layout.setContentsMargins(0, 0, 0, 0)
        log_layout.setSpacing(0)
        log_header = QLabel("SIMULATOR LOG")
        log_header.setObjectName("logHeader")
        log_layout.addWidget(log_header)
        log_layout.addWidget(self.logs)
        vertical = QSplitter(Qt.Vertical)
        vertical.addWidget(horizontal)
        vertical.addWidget(log_panel)
        vertical.setHandleWidth(8)
        vertical.setCollapsible(0, False)
        vertical.setSizes([550, 130])
        outer.addWidget(vertical)
        self.setCentralWidget(root)
        self.setStyleSheet(STYLE)

    @staticmethod
    def spin(low: float, high: float, value: float, decimals: int) -> QDoubleSpinBox:
        widget = QDoubleSpinBox()
        widget.setRange(low, high)
        widget.setDecimals(decimals)
        widget.setValue(value)
        widget.setButtonSymbols(QAbstractSpinBox.NoButtons)
        widget.setMinimumHeight(38)
        widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        return widget

    def map_selected(self, latitude: float, longitude: float) -> None:
        self.latitude.blockSignals(True)
        self.longitude.blockSignals(True)
        self.latitude.setValue(latitude)
        self.longitude.setValue(longitude)
        self.latitude.blockSignals(False)
        self.longitude.blockSignals(False)
        self.schedule_terrain_lookup()

    def inputs_changed(self) -> None:
        self.map.set_location(self.latitude.value(), self.longitude.value())
        self.schedule_terrain_lookup()

    def schedule_terrain_lookup(self) -> None:
        self.terrain_timer.start()

    def start_terrain_lookup(self) -> None:
        if self.terrain_thread and self.terrain_thread.isRunning():
            self.terrain_pending = True
            return

        latitude = self.latitude.value()
        longitude = self.longitude.value()
        self.terrain_pending = False
        self.logs.appendPlainText(
            f"[TERRAIN] Fetching elevation at {latitude:.7f}, {longitude:.7f}..."
        )
        self.terrain_thread = QThread(self)
        self.terrain_worker = TerrainWorker(latitude, longitude)
        self.terrain_worker.moveToThread(self.terrain_thread)
        self.terrain_thread.started.connect(self.terrain_worker.run)
        self.terrain_worker.finished.connect(self.terrain_lookup_finished)
        self.terrain_worker.failed.connect(self.terrain_lookup_failed)
        self.terrain_worker.finished.connect(self.terrain_thread.quit)
        self.terrain_worker.failed.connect(self.terrain_thread.quit)
        self.terrain_worker.finished.connect(self.terrain_worker.deleteLater)
        self.terrain_worker.failed.connect(self.terrain_worker.deleteLater)
        self.terrain_thread.finished.connect(self.terrain_thread_finished)
        self.terrain_thread.start()

    def terrain_lookup_finished(
        self, elevation_m: float, latitude: float, longitude: float
    ) -> None:
        current_matches = (
            abs(self.latitude.value() - latitude) < 0.0000001
            and abs(self.longitude.value() - longitude) < 0.0000001
        )
        if current_matches:
            self.altitude.setValue(elevation_m)
            self.logs.appendPlainText(f"[TERRAIN] Altitude updated: {elevation_m:.1f} m MSL")
        else:
            self.terrain_pending = True

    def terrain_lookup_failed(self, error: str, _latitude: float, _longitude: float) -> None:
        self.logs.appendPlainText(
            f"[TERRAIN] Lookup failed; keeping altitude {self.altitude.value():.1f} m: {error}"
        )

    def terrain_thread_finished(self) -> None:
        if self.terrain_thread:
            self.terrain_thread.deleteLater()
        self.terrain_thread = None
        self.terrain_worker = None
        if self.terrain_pending:
            self.terrain_pending = False
            self.terrain_timer.start(50)

    def set_status(self, text: str, state: str) -> None:
        self.status.setText(text)
        self.status.setProperty("state", state)
        self.status.style().unpolish(self.status)
        self.status.style().polish(self.status)
        is_stopped = state == "stopped"
        self.start_button.setEnabled(is_stopped)
        self.stop_button.setEnabled(not is_stopped)

    def start_sitl(self) -> None:
        if self.process.state() != QProcess.NotRunning:
            return
        sitl = ROOT / "ardupilot" / "build" / "sitl" / "bin" / "arduplane"
        if not sitl.exists():
            QMessageBox.critical(self, "SITL belum tersedia", "Jalankan ./setup.sh terlebih dahulu.")
            return
        location = f"{self.latitude.value():.7f},{self.longitude.value():.7f},{self.altitude.value():.1f},{self.heading.value():.1f}"
        defaults = ROOT / "ardupilot" / "Tools" / "autotest" / "default_params" / "quadplane.parm"
        # ArduPilot 4.6.3 resolves external model JSON from the SITL cwd.
        model = "../models/skyorcamax-12s.json"
        args = [
            "-S", "-w", "--model", f"quadplane:{model}", "--home", location,
            "--defaults", f"{defaults},{ROOT / 'skyorcamax.param'}",
            "--serial0", "udpclient:127.0.0.1:14550",
        ]
        self.logs.appendPlainText(f"[APP] Starting at {location}")
        self.logs.appendPlainText("[APP] QGroundControl output: udp://127.0.0.1:14550")
        self.process.setWorkingDirectory(str(ROOT / "ardupilot"))
        self.set_status("STARTING", "starting")
        self.process.start(str(sitl), args)

    def stop_sitl(self) -> None:
        if self.process.state() == QProcess.NotRunning:
            return
        self.set_status("STOPPING", "starting")
        self.process.terminate()
        if not self.process.waitForFinished(3000):
            self.process.kill()
            self.process.waitForFinished(2000)

    def read_output(self) -> None:
        text = bytes(self.process.readAllStandardOutput()).decode(errors="replace")
        self.logs.appendPlainText(text.rstrip())

    def process_finished(self, code: int) -> None:
        self.logs.appendPlainText(f"[APP] SITL stopped (exit {code})")
        self.set_status("STOPPED", "stopped")

    def closeEvent(self, event: QCloseEvent) -> None:
        self.stop_sitl()
        self.terrain_timer.stop()
        if self.terrain_thread and self.terrain_thread.isRunning():
            self.terrain_thread.quit()
            self.terrain_thread.wait(9000)
        event.accept()


STYLE = """
QMainWindow, QWidget { background: #edf1f2; color: #18272b; font-family: "Noto Sans", "DejaVu Sans"; font-size: 13px; }
#header { background: #153f47; border: 1px solid #153f47; border-radius: 5px; }
#header QLabel { background: transparent; }
#title { color: #ffffff; font-size: 20px; font-weight: 700; }
#subtitle { color: #9fc1c7; font-size: 10px; font-weight: 700; padding: 3px 7px; border: 1px solid #467079; border-radius: 3px; }
#status { min-width: 74px; min-height: 34px; padding: 0 10px; border-radius: 3px; font-size: 11px; font-weight: 700; }
#status[state="stopped"] { color: #7a3737; background: #f5dede; }
#status[state="starting"] { color: #775719; background: #f7e7bd; }
#status[state="running"] { color: #176044; background: #d6eee4; }
#panel { background: #ffffff; border: 1px solid #c8d2d5; border-radius: 5px; }
#formSurface { background: transparent; }
#formSurface QLabel { background: transparent; }
#panelTitle { background: transparent; color: #152b30; font-size: 17px; font-weight: 700; }
#panelCaption { background: transparent; color: #6a7e83; font-size: 12px; }
#mapView { border: 1px solid #c8d2d5; border-radius: 5px; background: #d8e1e3; }
#logPanel { background: #172528; border: 1px solid #263b40; border-radius: 5px; }
#logHeader { color: #93a9ae; background: #172528; padding: 8px 11px; font-size: 10px; font-weight: 700; border-bottom: 1px solid #2b4146; }
#logs { color: #d8e5e7; background: #101b1e; border: 0; border-bottom-left-radius: 4px; border-bottom-right-radius: 4px; padding: 8px; font-family: "DejaVu Sans Mono"; font-size: 12px; selection-background-color: #315c65; }
QPushButton { min-width: 82px; min-height: 34px; padding: 0 12px; border: 1px solid #acc0c4; border-radius: 4px; background: #e7edef; color: #193238; font-weight: 700; }
QPushButton:hover { background: #f4f7f8; border-color: #cfdbdd; }
QPushButton:pressed { background: #d5e0e2; }
QPushButton:disabled { color: #72878c; background: #cdd9dc; border-color: #cdd9dc; }
#startButton { color: #173238; background: #e4b83f; border-color: #e4b83f; }
#startButton:hover { background: #efc755; border-color: #efc755; }
#stopButton:enabled { color: #ffffff; background: #a74444; border-color: #a74444; }
#stopButton:enabled:hover { background: #b75353; border-color: #b75353; }
QDoubleSpinBox { color: #17282c; background: #f8fafb; border: 1px solid #b7c5c8; border-radius: 4px; padding: 0 10px; selection-background-color: #2f6975; }
QDoubleSpinBox:hover { border-color: #78959b; }
QDoubleSpinBox:focus { background: #ffffff; border: 2px solid #2f6975; padding: 0 9px; }
QSplitter::handle { background: #edf1f2; }
QToolTip { color: #ffffff; background: #20383d; border: 1px solid #47636a; padding: 5px; }
"""


def main() -> int:
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = QApplication(sys.argv)
    app.setApplicationName("SkyOrcaMax Simulator")
    window = MainWindow()
    window.show()
    return app.exec_()

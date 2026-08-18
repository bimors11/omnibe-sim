#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PROJECT_ROOT}/.venv/bin/python"
SITL="${PROJECT_ROOT}/ardupilot/build/sitl/bin/arduplane"
TAG="Plane-4.6.3"

[ -x "${PYTHON}" ] || { echo "Belum terpasang. Jalankan ./setup.sh" >&2; exit 1; }
[ -x "${SITL}" ] || { echo "ArduPlane SITL belum dibangun. Jalankan ./setup.sh" >&2; exit 1; }
[ "$(git -C "${PROJECT_ROOT}/ardupilot" describe --tags --exact-match 2>/dev/null || true)" = "${TAG}" ] || {
  echo "Checkout ArduPilot lokal bukan ${TAG}. Jalankan ./setup.sh." >&2
  exit 1
}
[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || { echo "Desktop X11/Wayland tidak terdeteksi." >&2; exit 1; }

exec "${PYTHON}" "${PROJECT_ROOT}/launcher.py"

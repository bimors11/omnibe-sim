#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARDUPILOT_ROOT="${PROJECT_ROOT}/ardupilot"
VENV="${PROJECT_ROOT}/.venv"
ARDUPILOT_TAG="Plane-4.6.3"

if [ "${EUID}" -eq 0 ]; then
  APT=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  echo "setup.sh membutuhkan hak akses apt (root atau sudo)." >&2
  exit 1
fi

echo "[1/5] Memasang dependency sistem..."
"${APT[@]}" update
"${APT[@]}" install -y \
  git build-essential ccache g++ gawk make rsync xterm pkg-config \
  libtool libtool-bin libxml2-dev libxslt1-dev libffi-dev libssl-dev \
  python3 python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
  python3-pyqt5 python3-pyqt5.qtwebengine python3-pyqt5.qtwebchannel

echo "[2/5] Membuat virtual environment lokal..."
python3 -m venv --system-site-packages "${VENV}"
"${VENV}/bin/python" -m pip install --upgrade pip wheel setuptools
"${VENV}/bin/python" -m pip install -r "${PROJECT_ROOT}/requirements.txt"

echo "[3/5] Menyiapkan ArduPilot ${ARDUPILOT_TAG} di dalam project..."
if [ ! -d "${ARDUPILOT_ROOT}/.git" ]; then
  git clone --branch "${ARDUPILOT_TAG}" --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/ArduPilot/ardupilot.git "${ARDUPILOT_ROOT}"
else
  current_tag="$(git -C "${ARDUPILOT_ROOT}" describe --tags --exact-match 2>/dev/null || true)"
  if [ "${current_tag}" != "${ARDUPILOT_TAG}" ]; then
    echo "ArduPilot lokal bukan ${ARDUPILOT_TAG}: ${current_tag:-tanpa tag}." >&2
    echo "Hapus ${ARDUPILOT_ROOT} secara manual lalu jalankan setup.sh lagi." >&2
    exit 1
  fi
  git -C "${ARDUPILOT_ROOT}" submodule update --init --recursive --depth 1
fi

echo "[4/5] Memeriksa toolchain build lokal..."
for command in git g++ make ccache pkg-config; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Tool build tidak ditemukan: ${command}" >&2
    exit 1
  }
done

echo "[5/5] Membangun ArduPlane SITL..."
export PATH="${VENV}/bin:${HOME}/.local/bin:${PATH}"
(
  cd "${ARDUPILOT_ROOT}"
  ./waf configure --board sitl
  ./waf plane
)

echo
echo "SkyOrcaMax Simulator siap. Jalankan: ${PROJECT_ROOT}/launch.sh"

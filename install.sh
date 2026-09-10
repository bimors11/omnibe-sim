#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="${PROJECT_ROOT}/.venv"
SITL="${PROJECT_ROOT}/ardupilot/build/sitl/bin/arduplane"
BUILD_ROOT="${PROJECT_ROOT}/build-appimage"
APPDIR="${BUILD_ROOT}/BETA-UAS-Omnibe.AppDir"
OUTPUT_DIR="${PROJECT_ROOT}/dist"
APPIMAGE_NAME="BETA-UAS-Omnibe-1.0.0-x86_64.AppImage"
APPIMAGE="${OUTPUT_DIR}/${APPIMAGE_NAME}"

case "$(uname -m)" in
  x86_64|amd64) APPIMAGE_ARCH="x86_64" ;;
  aarch64|arm64) APPIMAGE_ARCH="aarch64"; APPIMAGE_NAME="BETA-UAS-Omnibe-1.0.0-aarch64.AppImage"; APPIMAGE="${OUTPUT_DIR}/${APPIMAGE_NAME}" ;;
  *) echo "Arsitektur belum didukung oleh builder AppImage: $(uname -m)" >&2; exit 1 ;;
esac

if [ ! -x "${SITL}" ] || [ ! -x "${VENV}/bin/python" ]; then
  echo "Runtime belum lengkap; menjalankan setup.sh terlebih dahulu."
  "${PROJECT_ROOT}/setup.sh"
fi

echo "[1/5] Memasang PyInstaller ke virtual environment..."
"${VENV}/bin/python" -m pip install "pyinstaller==6.21.0"

echo "[2/5] Membundel GUI dan ArduPlane SITL..."
rm_build_path="${BUILD_ROOT}/pyinstaller"
if [ -d "${rm_build_path}" ]; then
  find "${rm_build_path}" -depth -delete
fi
mkdir -p "${rm_build_path}/dist" "${rm_build_path}/work" "${rm_build_path}/spec"
"${VENV}/bin/pyinstaller" \
  --noconfirm \
  --clean \
  --windowed \
  --onedir \
  --name beta-uas-omnibe \
  --distpath "${rm_build_path}/dist" \
  --workpath "${rm_build_path}/work" \
  --specpath "${rm_build_path}/spec" \
  --add-data "${PROJECT_ROOT}/config.yaml:." \
  --add-data "${PROJECT_ROOT}/omnibe.param:." \
  --add-data "${PROJECT_ROOT}/models:models" \
  --add-data "${PROJECT_ROOT}/ardupilot/Tools/autotest/default_params/quadplane.parm:ardupilot/Tools/autotest/default_params" \
  --add-binary "${SITL}:ardupilot/build/sitl/bin" \
  "${PROJECT_ROOT}/launcher.py"

echo "[3/5] Menyusun AppDir..."
if [ -d "${APPDIR}" ]; then
  find "${APPDIR}" -depth -delete
fi
mkdir -p "${APPDIR}/usr/lib/beta-uas-omnibe" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/scalable/apps"
cp -a "${rm_build_path}/dist/beta-uas-omnibe/." "${APPDIR}/usr/lib/beta-uas-omnibe/"
cp "${PROJECT_ROOT}/packaging/AppRun" "${APPDIR}/AppRun"
cp "${PROJECT_ROOT}/packaging/beta-uas-omnibe.desktop" "${APPDIR}/beta-uas-omnibe.desktop"
cp "${PROJECT_ROOT}/packaging/beta-uas-omnibe.desktop" "${APPDIR}/usr/share/applications/beta-uas-omnibe.desktop"
cp "${PROJECT_ROOT}/packaging/beta-uas-omnibe.svg" "${APPDIR}/beta-uas-omnibe.svg"
cp "${PROJECT_ROOT}/packaging/beta-uas-omnibe.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/beta-uas-omnibe.svg"
chmod +x "${APPDIR}/AppRun" "${APPDIR}/usr/lib/beta-uas-omnibe/beta-uas-omnibe"

echo "[4/5] Membuat AppImage..."
mkdir -p "${OUTPUT_DIR}" "${BUILD_ROOT}/tools"
APPIMAGETOOL="${BUILD_ROOT}/tools/appimagetool-${APPIMAGE_ARCH}.AppImage"
if [ ! -x "${APPIMAGETOOL}" ]; then
  curl -fL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage" -o "${APPIMAGETOOL}"
  chmod +x "${APPIMAGETOOL}"
fi
ARCH="${APPIMAGE_ARCH}" "${APPIMAGETOOL}" --appimage-extract-and-run "${APPDIR}" "${APPIMAGE}"
chmod +x "${APPIMAGE}"

echo "[5/5] Memasang AppImage dan shortcut Desktop..."
INSTALL_DIR="${HOME}/.local/bin"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
mkdir -p "${INSTALL_DIR}" "${ICON_DIR}"
INSTALLED_APPIMAGE="${INSTALL_DIR}/BETA-UAS-Omnibe.AppImage"
cp "${APPIMAGE}" "${INSTALLED_APPIMAGE}"
cp "${PROJECT_ROOT}/packaging/beta-uas-omnibe.svg" "${ICON_DIR}/beta-uas-omnibe.svg"
chmod +x "${INSTALLED_APPIMAGE}"

if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP)"
else
  DESKTOP_DIR="${HOME}/Desktop"
fi
mkdir -p "${DESKTOP_DIR}"
SHORTCUT="${DESKTOP_DIR}/BETA-UAS Omnibe.desktop"
sed \
  -e "s|^Exec=.*|Exec=${INSTALLED_APPIMAGE}|" \
  -e "s|^Icon=.*|Icon=${ICON_DIR}/beta-uas-omnibe.svg|" \
  "${PROJECT_ROOT}/packaging/beta-uas-omnibe.desktop" > "${SHORTCUT}"
chmod +x "${SHORTCUT}"
if command -v gio >/dev/null 2>&1; then
  gio set "${SHORTCUT}" metadata::trusted true >/dev/null 2>&1 || true
fi

echo
echo "AppImage dibuat: ${APPIMAGE}"
echo "AppImage terpasang: ${INSTALLED_APPIMAGE}"
echo "Shortcut Desktop: ${SHORTCUT}"

# SkyOrcaMax Simulator

Launcher desktop sederhana untuk ArduPlane QuadPlane SITL versi 4.6.3. Simulator
menggunakan model `quadplane` bawaan ArduPilot tanpa FlightGear, JSBSim eksternal,
Docker, atau checkout ArduPilot global.

## Instalasi

Ubuntu 22.04/24.04:

```bash
cd ~/xperiment/skyorcamax-simulator
chmod +x setup.sh launch.sh
./setup.sh
```

`setup.sh` membuat `.venv`, meng-clone tag `Plane-4.6.3` ke folder `ardupilot/`
di project ini, menginisialisasi submodule, dan membangun binary ArduPlane SITL.
Dependency dibatasi pada kebutuhan build SITL dan launcher; skrip prerequisite
ArduPilot lama tidak dijalankan agar tetap kompatibel dengan Linux Mint.

## Menjalankan

```bash
./launch.sh
```

## Membuat dan Memasang AppImage

Setelah `setup.sh` selesai, jalankan:

```bash
./install.sh
```

Builder membuat AppImage portable di `dist/`, memasangnya sebagai
`~/.local/bin/SkyOrcaMax-Simulator.AppImage`, dan membuat shortcut aplikasi
langsung di Desktop. Data runtime SITL dari AppImage disimpan di
`~/.local/share/skyorcamax-simulator/runtime`.

Klik atau drag marker untuk memilih lokasi. Latitude/longitude juga dapat diketik
langsung. Altitude MSL diperbarui otomatis dari data terrain SRTM30m setiap titik
berubah dan tetap dapat diedit manual jika layanan elevasi tidak tersedia. Atur
heading lalu tekan **Start**. QGroundControl menerima telemetry pada UDP `14550`.

## Build Windows Native (tanpa WSL)

Panduan lengkap tersedia di [README_WINDOWS.md](README_WINDOWS.md).

Jalankan dari **Windows PowerShell**. Python 3.11 atau lebih baru akan digunakan
jika sudah tersedia; Python dan dependency build dipasang otomatis bila perlu:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build-windows.ps1
```

Pengguna juga dapat langsung klik dua kali `install-windows.cmd` tanpa mengetik
perintah PowerShell.

Skrip mengambil tag ArduPilot `Plane-4.6.3`, membangun SITL Windows, lalu membuat
`dist-windows\SkyOrcaMax-Simulator-Windows-x64.zip` dan shortcut di Desktop.
Aplikasi hasil build tidak membutuhkan WSL atau instalasi Cygwin karena DLL yang
diperlukan SITL sudah ikut di dalam paket. Toolchain Cygwin hanya disimpan lokal
di `build-windows` selama proses kompilasi dan dapat dihapus sesudah build.

Build juga dapat dijalankan dari tab **Actions > Build Windows** di GitHub. Artifact
ZIP hasilnya tersedia pada halaman workflow run.

Setiap Start memakai reset parameter (`-w`), memuat parameter dasar `quadplane`
resmi dari checkout 4.6.3, lalu menerapkan `skyorcamax.param` sebagai override.

## Default Pesawat

| Pengaturan | Nilai |
| --- | ---: |
| Firmware | ArduPlane 4.6.3 |
| Model SITL | QuadPlane bawaan |
| Layout VTOL | Quad X |
| MAVLink type | VTOL Quadrotor (20) |
| Cruise airspeed | 21 m/s |
| TECS max climb | 3 m/s |
| TECS max descent | 2 m/s |
| Pitch limits | +20 / -15 deg |
| Roll limit | 30 deg |
| Loiter radius | 180 m |
| RTL autoland | 1 |
| Battery | 12S, 44.4 V nominal, 27 Ah |
| Nominal cruise power | sekitar 450 W |
| Nominal VTOL power | sekitar 1200 W |

Arus dan daya aktual tetap dihitung dinamis oleh physics model QuadPlane bawaan
ArduPilot berdasarkan throttle dan beban motor.

Kalibrasi listrik 12S berada di `models/skyorcamax-12s.json`. File ini memakai
mekanisme model JSON native SITL untuk menyamakan tegangan referensi physics motor
dengan baterai 12S. `Q_OPTIONS=1` menjaga sayap dalam `LEVEL_ROLL_LIMIT` selama
forward transition agar pesawat tidak mulai membelok sebelum transisi selesai.

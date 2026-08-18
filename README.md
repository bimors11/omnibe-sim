# SkyOrcaMax Simulator

Launcher desktop sederhana untuk ArduPlane QuadPlane SITL. Versi Linux membangun
firmware 4.6.3, sedangkan paket Windows memakai runtime 4.5.7 siap pakai. Simulator
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

## Windows Native (tanpa WSL)

Panduan lengkap tersedia di [README_WINDOWS.md](README_WINDOWS.md).

Pengguna cukup mengunduh `SkyOrcaMax Simulator.exe` dari halaman **Releases**.
ArduPlane SITL 4.5.7 dan parameter QuadPlane sudah dibundel, sehingga pengguna
tidak perlu Python, Cygwin, WSL, Docker, clone repository, atau build source.

Instruksi berikut hanya untuk developer yang ingin membangun ulang EXE.

Jalankan dari **Windows PowerShell**. Python 3.11 atau lebih baru akan digunakan
jika sudah tersedia; Python dan dependency build dipasang otomatis bila perlu:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build-windows.ps1
```

Pengguna juga dapat langsung klik dua kali `install-windows.cmd` tanpa mengetik
perintah PowerShell.

Skrip memakai ArduPlane SITL Windows 4.5.7 yang sudah disertakan, lalu membuat
`dist-windows\SkyOrcaMax Simulator.exe` dan shortcut di Desktop. Build normal
tidak membutuhkan WSL, Docker, atau Cygwin karena binary dan DLL SITL sudah ada.

Build juga dapat dijalankan dari tab **Actions > Build Windows** di GitHub. EXE
hasilnya tersedia sebagai artifact; build dari tag `v*` otomatis memasangnya pada
GitHub Release.

Setiap Start memakai reset parameter (`-w`), memuat parameter dasar `quadplane`
sesuai runtime, lalu menerapkan `skyorcamax.param` terbaru sebagai override.

## Default Pesawat

| Pengaturan | Nilai |
| --- | ---: |
| Firmware | ArduPlane 4.6.3 (Linux) / 4.5.7 (Windows) |
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

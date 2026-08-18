# SkyOrcaMax Simulator untuk Windows

Panduan ini membuat aplikasi Windows 64-bit tanpa WSL dan tanpa Docker. Proses
build memakai toolchain ArduPilot Windows yang disimpan secara lokal di folder
project. Komputer yang hanya menjalankan hasil build tidak perlu memasang Python,
WSL, atau Cygwin.

## Persyaratan Build

- Windows 10 atau Windows 11 64-bit
- Koneksi internet
- Ruang kosong minimal 10 GB
- Git for Windows: <https://git-scm.com/download/win>
- Python 3 64-bit: <https://www.python.org/downloads/windows/>

Saat memasang Python, aktifkan pilihan **Add Python to PATH** dan pastikan Python
Launcher (`py`) ikut terpasang.

## Clone Branch Windows

Buka PowerShell, lalu jalankan:

```powershell
cd $HOME\Desktop
git clone --branch windows-ver --single-branch https://github.com/bimors11/omnibe-sim.git SkyOrcaMax-Simulator
cd SkyOrcaMax-Simulator
```

Pastikan branch yang aktif sudah benar:

```powershell
git branch --show-current
```

Output yang diharapkan adalah `windows-ver`.

## Membuat Aplikasi

Jalankan builder dari PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build-windows.ps1
```

Pada build pertama, skrip akan:

1. Mengunduh toolchain Windows ke `build-windows`.
2. Mengunduh ArduPilot tag `Plane-4.6.3`.
3. Membangun ArduPlane QuadPlane SITL untuk Windows.
4. Membuat environment Python khusus build.
5. Mengemas GUI, SITL, parameter, model, dan DLL runtime.
6. Membuat shortcut **SkyOrcaMax Simulator** di Desktop.

Proses pertama dapat berlangsung cukup lama. Jangan tutup PowerShell selama build
masih berjalan.

## Menjalankan Simulator

Gunakan shortcut di Desktop atau jalankan langsung:

```powershell
& ".\dist-windows\SkyOrcaMax Simulator\SkyOrcaMax Simulator.exe"
```

Pilih koordinat pada peta, periksa altitude dan heading, lalu tekan **Start**.
QGroundControl menerima telemetry melalui UDP `127.0.0.1:14550`.

## Paket untuk Komputer Lain

Builder menghasilkan file:

```text
dist-windows\SkyOrcaMax-Simulator-Windows-x64.zip
```

Ekstrak seluruh isi ZIP sebelum menjalankan aplikasi. Jangan menjalankan file EXE
langsung dari dalam tampilan ZIP karena file SITL dan DLL harus berada bersama
aplikasi.

## Build Ulang

Untuk mengemas ulang GUI tanpa membangun SITL lagi:

```powershell
.\build-windows.ps1 -SkipSITLBuild
```

Untuk build tanpa membuat shortcut Desktop:

```powershell
.\build-windows.ps1 -NoDesktopShortcut
```

## Troubleshooting

### Perintah `py` tidak ditemukan

Pasang ulang Python dari python.org dan aktifkan Python Launcher serta **Add Python
to PATH**.

### PowerShell memblokir skrip

Jalankan berikut ini pada jendela PowerShell yang sama:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Pengaturan tersebut hanya berlaku untuk sesi PowerShell yang sedang dibuka.

### Peta atau altitude tidak muncul

Peta, citra satelit Esri, dan pencarian elevasi membutuhkan koneksi internet.
Altitude masih dapat dimasukkan secara manual ketika layanan elevasi tidak dapat
diakses.

### Windows Defender menampilkan peringatan

Aplikasi hasil build lokal belum ditandatangani dengan sertifikat code-signing.
Pastikan file berasal dari build atau repository ini, lalu gunakan **More info >
Run anyway** apabila Windows SmartScreen memblokirnya.

### QGroundControl tidak menerima telemetry

Pastikan QGroundControl berjalan dan firewall Windows mengizinkan SkyOrcaMax
Simulator menggunakan jaringan lokal/UDP. Port keluaran default adalah `14550`.

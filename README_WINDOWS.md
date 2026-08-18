# SkyOrcaMax Simulator untuk Windows

SkyOrcaMax Simulator tersedia sebagai satu file EXE Windows 64-bit, tanpa WSL,
Docker, Python, atau instalasi Cygwin.

## Instalasi untuk Pengguna

1. Buka halaman **Releases** repository GitHub.
2. Download `SkyOrcaMax Simulator.exe` dari release terbaru.
3. Letakkan file di folder yang diinginkan dan klik dua kali untuk menjalankannya.

ArduPlane QuadPlane SITL 4.5.7, DLL runtime, model baterai, dan parameter terbaru
sudah berada di dalam EXE. Pengguna tidak perlu clone repository atau menjalankan
proses build.

Bagian berikut hanya diperlukan oleh developer yang ingin membuat ulang EXE.

## Persyaratan Build

- Windows 10 atau Windows 11 64-bit
- Koneksi internet
- Ruang kosong minimal 10 GB
- Git for Windows: <https://git-scm.com/download/win>

Python 3.11 atau lebih baru, toolchain SITL, dependency Python, dan seluruh
komponen build lainnya akan diperiksa secara otomatis. Python kompatibel yang
sudah terpasang tidak akan dipasang ulang. Git hanya dibutuhkan ketika project
diambil menggunakan perintah `git clone`; source juga dapat diunduh sebagai ZIP
dari GitHub.

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

Cara termudah adalah klik dua kali `install-windows.cmd`. Skrip tersebut memasang
semua dependency, membangun aplikasi, dan membuat shortcut Desktop secara
otomatis.

Sebagai alternatif, jalankan builder dari PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build-windows.ps1
```

Builder akan:

1. Menggunakan binary ArduPlane QuadPlane SITL 4.5.7 yang sudah tersedia.
2. Membuat environment Python khusus build.
3. Mengemas GUI, SITL, parameter terbaru, model, dan DLL runtime.
4. Membuat shortcut **SkyOrcaMax Simulator** di Desktop.

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

Builder menghasilkan satu file portable:

```text
dist-windows\SkyOrcaMax Simulator.exe
```

File tersebut dapat langsung dipindahkan dan dijalankan pada komputer Windows
64-bit lain.

## Build Ulang

Build normal tidak memerlukan Cygwin. Developer yang secara khusus ingin
mengompilasi ulang firmware 4.5.7 dapat menjalankan:

```powershell
.\build-windows.ps1 -BuildSITLFromSource
```

Untuk build tanpa membuat shortcut Desktop:

```powershell
.\build-windows.ps1 -NoDesktopShortcut
```

## Troubleshooting

### Python tidak dapat dipasang otomatis

Builder mencoba `winget` terlebih dahulu, kemudian memakai installer resmi Python
3.11 sebagai fallback. Jika keduanya diblokir oleh kebijakan Windows, pasang Python
3.11 64-bit dari python.org, buka PowerShell baru, lalu jalankan builder kembali.

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

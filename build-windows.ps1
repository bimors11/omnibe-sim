[CmdletBinding()]
param(
    [switch]$SkipSITLBuild,
    [switch]$NoDesktopShortcut
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "build-windows"
$CygwinRoot = Join-Path $BuildRoot "cygwin64"
$ArduPilotRoot = Join-Path $BuildRoot "ardupilot"
$SITLStage = Join-Path $BuildRoot "sitl"
$Venv = Join-Path $BuildRoot ".venv"
$Tag = "Plane-4.6.3"

function Invoke-Cygwin([string]$Command) {
    $bash = Join-Path $CygwinRoot "bin\bash.exe"
    & $bash --login -c $Command
    if ($LASTEXITCODE -ne 0) { throw "Perintah build Cygwin gagal ($LASTEXITCODE)." }
}

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

if (-not $SkipSITLBuild) {
    Write-Host "[1/5] Menyiapkan toolchain ArduPilot Windows lokal..."
    $setup = Join-Path $BuildRoot "setup-x86_64.exe"
    if (-not (Test-Path $setup)) {
        Invoke-WebRequest "https://cygwin.com/setup-x86_64.exe" -OutFile $setup
    }
    $packages = @(
        "ccache", "gcc-g++", "git", "libexpat-devel", "libtool", "libxml2-devel",
        "libxslt-devel", "make", "python3", "python3-devel", "python3-pip", "rsync"
    ) -join ","
    & $setup -q -n -R $CygwinRoot -l (Join-Path $BuildRoot "packages") `
        -s "https://mirrors.kernel.org/sourceware/cygwin/" -P $packages
    if ($LASTEXITCODE -ne 0) { throw "Instalasi toolchain Cygwin gagal." }

    $cygBuild = (& (Join-Path $CygwinRoot "bin\cygpath.exe") -u $BuildRoot).Trim()
    Write-Host "[2/5] Mengambil ArduPilot $Tag..."
    if (-not (Test-Path (Join-Path $ArduPilotRoot ".git"))) {
        Invoke-Cygwin "git clone --branch '$Tag' --depth 1 --recurse-submodules --shallow-submodules https://github.com/ArduPilot/ardupilot.git '$cygBuild/ardupilot'"
    } else {
        Invoke-Cygwin "cd '$cygBuild/ardupilot' && git submodule update --init --recursive --depth 1"
    }

    Write-Host "[3/5] Membangun ArduPlane SITL Windows..."
    Invoke-Cygwin "python3 -m pip install --user empy==3.3.4 future lxml packaging pexpect psutil pymavlink pyserial"
    Invoke-Cygwin "cd '$cygBuild/ardupilot' && python3 ./waf configure --board sitl && python3 ./waf plane -j4"

    New-Item -ItemType Directory -Force -Path $SITLStage | Out-Null
    Copy-Item (Join-Path $ArduPilotRoot "build\sitl\bin\arduplane.exe") `
        (Join-Path $SITLStage "ArduPlane.elf.exe") -Force
    $cygcheck = Join-Path $CygwinRoot "bin\cygcheck.exe"
    $dependencies = & $cygcheck (Join-Path $SITLStage "ArduPlane.elf.exe")
    $dllNames = $dependencies | ForEach-Object {
        if ($_ -match "(cyg[^\\/\s]+\.dll)") { $Matches[1] }
    } | Sort-Object -Unique
    foreach ($dll in $dllNames) {
        Copy-Item (Join-Path $CygwinRoot "bin\$dll") $SITLStage -Force
    }
} elseif (-not (Test-Path (Join-Path $SITLStage "ArduPlane.elf.exe"))) {
    throw "Binary SITL belum ada. Hapus -SkipSITLBuild untuk membangunnya."
}

Write-Host "[4/5] Membuat aplikasi Windows native..."
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python 3 Windows tidak ditemukan. Pasang dari python.org lalu jalankan ulang."
}
if (-not (Test-Path (Join-Path $Venv "Scripts\python.exe"))) {
    py -3 -m venv $Venv
}
$Python = Join-Path $Venv "Scripts\python.exe"
& $Python -m pip install --upgrade pip
& $Python -m pip install -r (Join-Path $ProjectRoot "requirements-windows.txt")

$Dist = Join-Path $ProjectRoot "dist-windows"
$Work = Join-Path $BuildRoot "pyinstaller"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Dist, $Work
$data = @(
    "$(Join-Path $ProjectRoot 'config.yaml');.",
    "$(Join-Path $ProjectRoot 'skyorcamax.param');.",
    "$(Join-Path $ProjectRoot 'models');models",
    "$(Join-Path $ArduPilotRoot 'Tools\autotest\default_params\quadplane.parm');defaults",
    "$SITLStage;sitl"
)
$arguments = @(
    "-m", "PyInstaller", "--noconfirm", "--clean", "--windowed", "--onedir",
    "--name", "SkyOrcaMax Simulator", "--distpath", $Dist, "--workpath", $Work,
    "--specpath", $BuildRoot
)
foreach ($item in $data) { $arguments += @("--add-data", $item) }
$arguments += (Join-Path $ProjectRoot "launcher.py")
& $Python @arguments
if ($LASTEXITCODE -ne 0) { throw "PyInstaller gagal membuat aplikasi." }

Write-Host "[5/5] Membuat paket dan shortcut..."
$AppDir = Join-Path $Dist "SkyOrcaMax Simulator"
$Zip = Join-Path $Dist "SkyOrcaMax-Simulator-Windows-x64.zip"
Compress-Archive -Path "$AppDir\*" -DestinationPath $Zip -Force
if (-not $NoDesktopShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $desktop "SkyOrcaMax Simulator.lnk"))
    $shortcut.TargetPath = Join-Path $AppDir "SkyOrcaMax Simulator.exe"
    $shortcut.WorkingDirectory = $AppDir
    $shortcut.Save()
}

Write-Host ""
Write-Host "Build selesai: $Zip"
Write-Host "Aplikasi: $(Join-Path $AppDir 'SkyOrcaMax Simulator.exe')"

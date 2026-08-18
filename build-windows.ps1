[CmdletBinding()]
param(
    [switch]$BuildSITLFromSource,
    [switch]$NoDesktopShortcut
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "build-windows"
$CygwinRoot = Join-Path $BuildRoot "cygwin64"
$ArduPilotRoot = Join-Path $BuildRoot "ardupilot"
$SITLStage = Join-Path $BuildRoot "sitl"
$Venv = Join-Path $BuildRoot ".venv"
$Tag = "Plane-4.5.7"

function Invoke-Cygwin([string]$Command) {
    $bash = Join-Path $CygwinRoot "bin\bash.exe"
    & $bash --login -c $Command
    if ($LASTEXITCODE -ne 0) { throw "Perintah build Cygwin gagal ($LASTEXITCODE)." }
}

function Find-CompatiblePython {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        & $launcher.Source -3 -c "import sys; assert sys.version_info >= (3, 11) and sys.maxsize > 2**32" 2>$null
        if ($LASTEXITCODE -eq 0) { return @($launcher.Source, "-3") }
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        & $python.Source -c "import sys; assert sys.version_info >= (3, 11) and sys.maxsize > 2**32" 2>$null
        if ($LASTEXITCODE -eq 0) { return @($python.Source) }
    }

    $locations = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe"),
        (Join-Path $env:ProgramFiles "Python311\python.exe")
    )
    foreach ($candidate in $locations) {
        if (Test-Path $candidate) { return @($candidate) }
    }
    return $null
}

function Install-Python311 {
    Write-Host "Python 3.11 64-bit belum ada; memasang otomatis..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & $winget.Source install --id Python.Python.3.11 --exact --scope user `
            --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) { return }
        Write-Warning "Instalasi melalui winget gagal; mencoba installer resmi Python."
    }

    $installer = Join-Path $BuildRoot "python-3.11.9-amd64.exe"
    if (-not (Test-Path $installer)) {
        Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" `
            -OutFile $installer
    }
    & $installer /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 `
        Include_pip=1 Include_test=0
    if ($LASTEXITCODE -ne 0) { throw "Instalasi Python 3.11 gagal." }
}

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

if ($BuildSITLFromSource) {
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
    New-Item -ItemType Directory -Force -Path (Join-Path $SITLStage "defaults") | Out-Null
    Copy-Item (Join-Path $ArduPilotRoot "build\sitl\bin\arduplane.exe") `
        (Join-Path $SITLStage "ArduPlane.elf.exe") -Force
    Copy-Item (Join-Path $ArduPilotRoot "Tools\autotest\default_params\quadplane.parm") `
        (Join-Path $SITLStage "defaults\quadplane.parm") -Force
    $cygcheck = Join-Path $CygwinRoot "bin\cygcheck.exe"
    $dependencies = & $cygcheck (Join-Path $SITLStage "ArduPlane.elf.exe")
    $dllNames = $dependencies | ForEach-Object {
        if ($_ -match "(cyg[^\\/\s]+\.dll)") { $Matches[1] }
    } | Sort-Object -Unique
    foreach ($dll in $dllNames) {
        Copy-Item (Join-Path $CygwinRoot "bin\$dll") $SITLStage -Force
    }
} else {
    Write-Host "[1/5] Menggunakan ArduPlane SITL 4.5.7 bawaan..."
    $PrebuiltSITL = Join-Path $ProjectRoot "prebuilt\windows\sitl"
    if (-not (Test-Path (Join-Path $PrebuiltSITL "ArduPlane.elf.exe"))) {
        throw "Runtime SITL bawaan tidak ditemukan. Clone repository secara lengkap."
    }
    New-Item -ItemType Directory -Force -Path $SITLStage | Out-Null
    Copy-Item "$PrebuiltSITL\*" $SITLStage -Recurse -Force
    Write-Host "[2/5] Build firmware dilewati; pengguna tidak memerlukan Cygwin."
    Write-Host "[3/5] Parameter SkyOrcaMax terbaru akan dibundel."
}

Write-Host "[4/5] Membuat aplikasi Windows native..."
$BootstrapPython = Find-CompatiblePython
if (-not $BootstrapPython) {
    Install-Python311
    $BootstrapPython = Find-CompatiblePython
}
if (-not $BootstrapPython) {
    throw "Python sudah dipasang tetapi belum dapat ditemukan. Buka PowerShell baru lalu jalankan skrip lagi."
}
if (-not (Test-Path (Join-Path $Venv "Scripts\python.exe"))) {
    if ($BootstrapPython.Count -eq 2) {
        & $BootstrapPython[0] $BootstrapPython[1] -m venv $Venv
    } else {
        & $BootstrapPython[0] -m venv $Venv
    }
    if ($LASTEXITCODE -ne 0) { throw "Gagal membuat environment Python build." }
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
    "$(Join-Path $SITLStage 'defaults\quadplane.parm');defaults",
    "$SITLStage;sitl"
)
$arguments = @(
    "-m", "PyInstaller", "--noconfirm", "--clean", "--windowed", "--onefile",
    "--name", "SkyOrcaMax Simulator", "--distpath", $Dist, "--workpath", $Work,
    "--specpath", $BuildRoot
)
foreach ($item in $data) { $arguments += @("--add-data", $item) }
$arguments += (Join-Path $ProjectRoot "launcher.py")
& $Python @arguments
if ($LASTEXITCODE -ne 0) { throw "PyInstaller gagal membuat aplikasi." }

Write-Host "[5/5] Membuat paket dan shortcut..."
$AppExe = Join-Path $Dist "SkyOrcaMax Simulator.exe"
if (-not (Test-Path $AppExe)) { throw "File aplikasi hasil build tidak ditemukan." }
if (-not $NoDesktopShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $desktop "SkyOrcaMax Simulator.lnk"))
    $shortcut.TargetPath = $AppExe
    $shortcut.WorkingDirectory = $Dist
    $shortcut.Save()
}

Write-Host ""
Write-Host "Aplikasi siap pakai: $AppExe"

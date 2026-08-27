param(
    [string]$Output = "build\MoleDown.pdx"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$defaultSdkPath = "C:\Users\wcdea\OneDrive\School\AUC Medical School\Documents\PlaydateSDK"
$pdc = "pdc"

if ($env:PLAYDATE_SDK_PATH) {
    $sdkPdc = Join-Path $env:PLAYDATE_SDK_PATH "bin\pdc.exe"
    if (Test-Path $sdkPdc) {
        $pdc = $sdkPdc
    }
} elseif (Test-Path (Join-Path $defaultSdkPath "bin\pdc.exe")) {
    $env:PLAYDATE_SDK_PATH = $defaultSdkPath
    $pdc = Join-Path $defaultSdkPath "bin\pdc.exe"
}

if (-not (Get-Command $pdc -ErrorAction SilentlyContinue)) {
    Write-Error "Playdate compiler not found. Install the Playdate SDK, then set PLAYDATE_SDK_PATH to the SDK folder or add its bin folder to PATH."
}

$outputPath = Join-Path $projectRoot $Output
$outputDir = Split-Path $outputPath -Parent
$sourcePath = Join-Path $projectRoot "source"

if (-not (Test-Path (Join-Path $sourcePath "main.lua"))) {
    Write-Error "Playdate source not found. Expected main.lua at $sourcePath."
}

if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$compilerOutput = & $pdc $sourcePath $outputPath 2>&1
$compilerOutput | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0 -or ($compilerOutput -match "^error:")) {
    exit 1
}

Write-Host "Built $outputPath"

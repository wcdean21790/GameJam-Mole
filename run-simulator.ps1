param(
    [string]$Output = "build\MoleDown.pdx"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$defaultSdkPath = "C:\Users\wcdea\OneDrive\School\AUC Medical School\Documents\PlaydateSDK"
$outputPath = Join-Path $projectRoot $Output

& (Join-Path $projectRoot "build-playdate.ps1") -Output $Output

$simulator = $null
if ($env:PLAYDATE_SDK_PATH) {
    $sdkSimulator = Join-Path $env:PLAYDATE_SDK_PATH "bin\PlaydateSimulator.exe"
    if (Test-Path $sdkSimulator) {
        $simulator = $sdkSimulator
    }
} elseif (Test-Path (Join-Path $defaultSdkPath "bin\PlaydateSimulator.exe")) {
    $env:PLAYDATE_SDK_PATH = $defaultSdkPath
    $simulator = Join-Path $defaultSdkPath "bin\PlaydateSimulator.exe"
}

if ($simulator) {
    Start-Process -FilePath $simulator -ArgumentList "`"$outputPath`"" -WorkingDirectory (Split-Path $simulator -Parent)
} else {
    Start-Process -FilePath $outputPath
}

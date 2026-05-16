# hbr_studio launch script
# Fixes the recurring cpp_client_wrapper ephemeral files issue on Windows.

$projectRoot = $PSScriptRoot

# 1. Kill any lingering hbr_studio process (releases lock on build dir)
Stop-Process -Name "hbr_studio" -Force -ErrorAction SilentlyContinue

# 2. Ensure cpp_client_wrapper .cc/.h files are present in ephemeral dir
$flutterRoot   = (Get-Command flutter).Source | Split-Path | Split-Path
$sdkWrapper    = "$flutterRoot\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper"
$ephemeralWrapper = "$projectRoot\windows\flutter\ephemeral\cpp_client_wrapper"

New-Item -ItemType Directory -Force -Path $ephemeralWrapper | Out-Null
Copy-Item "$sdkWrapper\*.cc" "$ephemeralWrapper\" -Force
Copy-Item "$sdkWrapper\*.h"  "$ephemeralWrapper\" -Force

# 3. Run the app
flutter run -d windows

[CmdletBinding()]
param(
    [string]$EnvFile = '.env',
    [string]$KeystorePath = ''
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Stop-Build([string]$Message) {
    throw $Message
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Stop-Build 'Missing .env file in the project directory.'
}

# Load KEY=VALUE lines from the local .env file without printing values.
foreach ($line in (Get-Content -LiteralPath $EnvFile)) {
    $text = $line.Trim()
    if ($text -eq '' -or $text.StartsWith('#')) { continue }
    $separator = $text.IndexOf('=')
    if ($separator -le 0) { continue }
    $name = $text.Substring(0, $separator).Trim()
    $value = $text.Substring($separator + 1).Trim()
    if ($value.Length -ge 2) {
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    Set-Item -Path ("Env:" + $name) -Value $value
}

# Map the names used in key.properties to the names expected by Gradle.
if (-not $env:ANDROID_KEYSTORE_PASSWORD -and $env:storePassword) {
    $env:ANDROID_KEYSTORE_PASSWORD = $env:storePassword
}
if (-not $env:ANDROID_KEY_ALIAS -and $env:keyAlias) {
    $env:ANDROID_KEY_ALIAS = $env:keyAlias
}
if (-not $env:ANDROID_KEY_PASSWORD -and $env:keyPassword) {
    $env:ANDROID_KEY_PASSWORD = $env:keyPassword
}
if (-not $KeystorePath -and $env:storeFile) {
    $KeystorePath = $env:storeFile
}
if (-not $KeystorePath) {
    $KeystorePath = 'android/upload-keystore.jks'
}

if (-not (Test-Path -LiteralPath $KeystorePath)) {
    Stop-Build ("Keystore not found: " + $KeystorePath)
}
$env:ANDROID_KEYSTORE_PATH = (Resolve-Path -LiteralPath $KeystorePath).Path

foreach ($name in @('ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        Stop-Build ("Missing signing variable: " + $name)
    }
}
foreach ($name in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'MAPBOX_PUBLIC_TOKEN')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        Stop-Build ("Missing application variable in .env: " + $name)
    }
}

Write-Host 'Cleaning Flutter build...'
& flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building signed release APK...'
$defines = @(
    '--dart-define=SUPABASE_URL=' + $env:SUPABASE_URL,
    '--dart-define=SUPABASE_ANON_KEY=' + $env:SUPABASE_ANON_KEY,
    '--dart-define=MAPBOX_PUBLIC_TOKEN=' + $env:MAPBOX_PUBLIC_TOKEN
)
if ($env:FIREBASE_ANDROID_API_KEY) {
    $defines += '--dart-define=FIREBASE_ANDROID_API_KEY=' + $env:FIREBASE_ANDROID_API_KEY
}
& flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apk)) {
    Stop-Build ("APK was not created: " + $apk)
}
Write-Host ('APK built successfully: ' + $apk)

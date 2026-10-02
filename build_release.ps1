[CmdletBinding()]
param(
    [string]$EnvFile = ".env",
    [string]$KeystorePath = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    Fail "ملف .env غير موجود. أنشئه في مجلد المشروع ثم أعد التشغيل."
}

# Load local values without printing any secrets.
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line -match '^([^=]+)=(.*)$') {
        $name = $Matches[1].Trim()
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

# The Android Gradle file intentionally consumes these names.
if (-not $env:ANDROID_KEYSTORE_PATH -and $env:storeFile) {
    $KeystorePath = $env:storeFile
}
if (-not $env:ANDROID_KEYSTORE_PASSWORD -and $env:storePassword) {
    $env:ANDROID_KEYSTORE_PASSWORD = $env:storePassword
}
if (-not $env:ANDROID_KEY_ALIAS -and $env:keyAlias) {
    $env:ANDROID_KEY_ALIAS = $env:keyAlias
}
if (-not $env:ANDROID_KEY_PASSWORD -and $env:keyPassword) {
    $env:ANDROID_KEY_PASSWORD = $env:keyPassword
}

if (-not $env:ANDROID_KEYSTORE_PATH) {
    if (-not $KeystorePath) { $KeystorePath = "android/upload-keystore.jks" }
    if (-not (Test-Path $KeystorePath)) {
        Fail "ملف keystore غير موجود: $KeystorePath. ضع upload-keystore.jks في المسار الصحيح."
    }
    $env:ANDROID_KEYSTORE_PATH = (Resolve-Path $KeystorePath).Path
} else {
    if (-not (Test-Path $env:ANDROID_KEYSTORE_PATH)) {
        Fail "ANDROID_KEYSTORE_PATH يشير إلى ملف غير موجود."
    }
    $env:ANDROID_KEYSTORE_PATH = (Resolve-Path $env:ANDROID_KEYSTORE_PATH).Path
}

foreach ($name in @('ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        Fail "متغير التوقيع ناقص: $name"
    }
}

foreach ($name in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'MAPBOX_PUBLIC_TOKEN')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        Fail "متغير التطبيق ناقص في .env: $name"
    }
}

Write-Host "Cleaning Flutter build..."
flutter clean
flutter pub get

Write-Host "Building signed release APK..."
flutter build apk --release `
    --dart-define="SUPABASE_URL=$env:SUPABASE_URL" `
    --dart-define="SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY" `
    --dart-define="MAPBOX_PUBLIC_TOKEN=$env:MAPBOX_PUBLIC_TOKEN" `
    --dart-define="FIREBASE_ANDROID_API_KEY=$env:FIREBASE_ANDROID_API_KEY"

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) {
    Fail "انتهى البناء بدون العثور على APK: $apk"
}

Write-Host "APK built successfully: $apk"

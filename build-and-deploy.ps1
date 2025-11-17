# Script para hacer build y deploy automático corrigiendo el problema de las comillas

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build y Deploy Automático" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paso 1: Build
Write-Host "[1/3] Ejecutando flutter build web --release..." -ForegroundColor Yellow
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error en el build" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Build completado" -ForegroundColor Green
Write-Host ""

# Paso 2: Corrección del index.html
Write-Host "[2/3] Corrigiendo index.html..." -ForegroundColor Yellow
$indexPath = "build\web\index.html"

if (Test-Path $indexPath) {
    $content = Get-Content -Path $indexPath -Raw
    $content = $content -replace 'serviceWorkerVersion = ""([^"]+)"";', 'serviceWorkerVersion = "$1";'
    Set-Content -Path $indexPath -Value $content -NoNewline
    Write-Host "✓ Archivo corregido" -ForegroundColor Green
} else {
    Write-Host "✗ No se encontró el archivo index.html" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Paso 3: Deploy
Write-Host "[3/3] Desplegando a Firebase..." -ForegroundColor Yellow
firebase deploy

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error en el deploy" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✓ Deploy completado exitosamente!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tu aplicación está disponible en:" -ForegroundColor Cyan
Write-Host "https://sopa-y-carbon-app.web.app" -ForegroundColor White

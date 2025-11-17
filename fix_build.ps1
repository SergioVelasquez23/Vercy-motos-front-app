# Script para corregir el problema de comillas duplicadas en el archivo index.html después del build

$indexPath = "build\web\index.html"

if (Test-Path $indexPath) {
    Write-Host "Corrigiendo archivo index.html..."
    
    # Leer el contenido del archivo
    $content = Get-Content -Path $indexPath -Raw
    
    # Reemplazar las comillas dobles duplicadas (acepta cualquier número entre las comillas)
    $content = $content -replace 'serviceWorkerVersion = ""([^"]+)"";', 'serviceWorkerVersion = "$1";'
    
    # Guardar el archivo corregido
    Set-Content -Path $indexPath -Value $content -NoNewline
    
    Write-Host "✓ Archivo corregido exitosamente"
    Write-Host ""
    Write-Host "Ahora puedes ejecutar: firebase deploy"
} else {
    Write-Host "✗ No se encontró el archivo index.html. Ejecuta 'flutter build web' primero."
}

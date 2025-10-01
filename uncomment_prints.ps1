# Script para descomentar todos los prints en archivos Dart
# Uso: .\uncomment_prints.ps1

Write-Host "🔧 Descomentando todos los prints en archivos Dart..." -ForegroundColor Yellow

$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"
$totalFiles = $dartFiles.Count
$filesModified = 0
$printsUncommented = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Descomentar prints
    $content = $content -replace '(\s+)// print\(', '$1print('
    $content = $content -replace '^(\s*)// print\(', '$1print('
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $filesModified++
        
        # Contar cuántos prints se descomentaron en este archivo
        $printMatches = ($content | Select-String -Pattern 'print\(' -AllMatches).Matches.Count
        $printsUncommented += $printMatches
        
        Write-Host "✅ $($file.Name): prints descomentados" -ForegroundColor Green
    }
}

Write-Host "`n📊 Resumen:" -ForegroundColor Cyan
Write-Host "   • Archivos procesados: $totalFiles" -ForegroundColor White
Write-Host "   • Archivos modificados: $filesModified" -ForegroundColor White
Write-Host "   • Total prints activos: $printsUncommented" -ForegroundColor White
Write-Host "`n🔧 ¡Listo! Los prints están activos para debug." -ForegroundColor Green
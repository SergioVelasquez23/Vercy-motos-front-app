# Script para comentar todos los prints en archivos Dart
# Uso: .\comment_prints.ps1

Write-Host "🔧 Comentando todos los prints en archivos Dart..." -ForegroundColor Yellow

$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"
$totalFiles = $dartFiles.Count
$filesModified = 0
$printsCommented = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Comentar prints que empiecen con print(
    $content = $content -replace '(\s+)print\(', '$1// print('
    
    # Comentar prints que empiecen al inicio de línea
    $content = $content -replace '^(\s*)print\(', '$1// print('
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $filesModified++
        
        # Contar cuántos prints se comentaron en este archivo
        $printMatches = ($content | Select-String -Pattern '// print\(' -AllMatches).Matches.Count
        $printsCommented += $printMatches
        
        Write-Host "✅ $($file.Name): $printMatches prints comentados" -ForegroundColor Green
    }
}

Write-Host "`n📊 Resumen:" -ForegroundColor Cyan
Write-Host "   • Archivos procesados: $totalFiles" -ForegroundColor White
Write-Host "   • Archivos modificados: $filesModified" -ForegroundColor White
Write-Host "   • Total prints comentados: $printsCommented" -ForegroundColor White
Write-Host "`n🚀 ¡Listo! Tu app ahora será más rápida en producción." -ForegroundColor Green
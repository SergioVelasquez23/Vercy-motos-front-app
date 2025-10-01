# Script para comentar todos los prints en archivos Dart
param(
    [string]$Path = "lib"
)

Write-Output "Comentando todos los prints en archivos Dart..."

$dartFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.dart"
$totalFiles = $dartFiles.Count
$filesModified = 0
$printsCommented = 0

foreach ($file in $dartFiles) {
    $lines = Get-Content $file.FullName
    $modified = $false
    $newLines = @()
    
    foreach ($line in $lines) {
        if ($line -match '^\s*print\(') {
            # Comentar líneas que empiecen con print(
            $newLines += $line -replace '(\s*)print\(', '$1// print('
            $modified = $true
            $printsCommented++
        } elseif ($line -match '\s+print\(') {
            # Comentar prints que tengan espacios antes
            $newLines += $line -replace '(\s+)print\(', '$1// print('
            $modified = $true
            $printsCommented++
        } else {
            $newLines += $line
        }
    }
    
    if ($modified) {
        $newLines | Out-File -FilePath $file.FullName -Encoding UTF8
        $filesModified++
        Write-Output "Modificado: $($file.Name)"
    }
}

Write-Output ""
Write-Output "Resumen:"
Write-Output "- Archivos procesados: $totalFiles"
Write-Output "- Archivos modificados: $filesModified"
Write-Output "- Total prints comentados: $printsCommented"
Write-Output ""
Write-Output "Listo! Tu app ahora sera mas rapida en produccion."
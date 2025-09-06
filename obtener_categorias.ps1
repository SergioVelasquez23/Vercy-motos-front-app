# Script para obtener IDs de categorías y generar JSON actualizado
# Ejecuta este script para obtener automáticamente los IDs reales

Write-Host "🔍 Obteniendo categorías del servidor..." -ForegroundColor Yellow

try {
    # Realizar request para obtener categorías
    $response = Invoke-RestMethod -Uri "http://192.168.1.44:8081/api/categorias" -Method GET -ContentType "application/json"
    
    Write-Host "✅ Categorías obtenidas exitosamente!" -ForegroundColor Green
    Write-Host ""
    
    # Mostrar todas las categorías con sus IDs
    Write-Host "📋 CATEGORÍAS DISPONIBLES:" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    $categorias = @{}
    
    foreach ($categoria in $response) {
        $nombre = $categoria.nombre
        $id = $categoria._id
        $categorias[$nombre] = $id
        
        Write-Host "📂 $nombre" -ForegroundColor White
        Write-Host "   ID: $id" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Buscar específicamente "Bebidas Calientes"
    $bebidasCalientesId = $null
    foreach ($categoria in $response) {
        if ($categoria.nombre -match "Bebidas.*Calientes|bebidas.*calientes") {
            $bebidasCalientesId = $categoria._id
            Write-Host "🔥 ID de Bebidas Calientes encontrado: $bebidasCalientesId" -ForegroundColor Green
            break
        }
    }
    
    if ($bebidasCalientesId) {
        # Leer el JSON original
        $jsonPath = "D:\prueba sopa y carbon\serch-restapp\JSON_Bebidas_Calientes.json"
        if (Test-Path $jsonPath) {
            $jsonContent = Get-Content $jsonPath -Raw
            
            # Reemplazar el placeholder con el ID real
            $jsonUpdated = $jsonContent -replace "ID_BEBIDAS_CALIENTES", $bebidasCalientesId
            
            # Guardar JSON actualizado
            $jsonUpdatedPath = "D:\prueba sopa y carbon\serch-restapp\JSON_Bebidas_Calientes_LISTO.json"
            $jsonUpdated | Out-File -FilePath $jsonUpdatedPath -Encoding UTF8
            
            Write-Host "🚀 JSON ACTUALIZADO GENERADO!" -ForegroundColor Green
            Write-Host "Archivo: JSON_Bebidas_Calientes_LISTO.json" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "📋 PRÓXIMOS PASOS:" -ForegroundColor Cyan
            Write-Host "1. Abre Postman" -ForegroundColor White
            Write-Host "2. Usa 'Carga Masiva de Productos'" -ForegroundColor White
            Write-Host "3. Copia el contenido de JSON_Bebidas_Calientes_LISTO.json" -ForegroundColor White
            Write-Host "4. ¡Send y listo! 🎉" -ForegroundColor White
        }
    } else {
        Write-Host "⚠️  No se encontró categoría 'Bebidas Calientes'" -ForegroundColor Red
        Write-Host "Verifica el nombre exacto en la lista anterior" -ForegroundColor Yellow
    }
    
    # Guardar todos los IDs para referencia futura
    $categoriasJson = $categorias | ConvertTo-Json -Depth 2
    $categoriasPath = "D:\prueba sopa y carbon\serch-restapp\CATEGORIAS_IDS.json"
    $categoriasJson | Out-File -FilePath $categoriasPath -Encoding UTF8
    
    Write-Host ""
    Write-Host "💾 Todos los IDs guardados en: CATEGORIAS_IDS.json" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error al conectar con el servidor:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Verifica que:" -ForegroundColor Yellow
    Write-Host "- El servidor esté ejecutándose en http://192.168.1.44:8081" -ForegroundColor White
    Write-Host "- Tengas acceso a la red" -ForegroundColor White
    Write-Host "- El endpoint /api/categorias esté disponible" -ForegroundColor White
}

Write-Host ""
Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

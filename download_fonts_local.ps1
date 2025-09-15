
# Script para descargar las fuentes de Roboto y Material Icons
# Este script crea los directorios necesarios y descarga las fuentes en los formatos TTF y WOFF2

# Crear directorios si no existen
if (-not (Test-Path -Path "assets/fonts/Roboto")) {
    New-Item -Path "assets/fonts/Roboto" -ItemType Directory -Force
}

if (-not (Test-Path -Path "web/fonts")) {
    New-Item -Path "web/fonts" -ItemType Directory -Force
}

if (-not (Test-Path -Path "web/assets/fonts")) {
    New-Item -Path "web/assets/fonts" -ItemType Directory -Force
}

# URLs de las fuentes
$robotoRegularUrl = "https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxK.woff2"
$robotoMediumUrl = "https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmEU9fBBc4.woff2"
$robotoBoldUrl = "https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlfBBc4.woff2"
$robotoLightUrl = "https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmSU5fBBc4.woff2"
$materialIconsUrl = "https://fonts.gstatic.com/s/materialicons/v140/flUhRq6tzZclQEJ-Vdg-IuiaDsNcIhQ8tQ.woff2"
$robotoRegularTtfUrl = "https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf"

# Descargar fuentes en formato WOFF2
Write-Host "Descargando fuentes en formato WOFF2..."

Invoke-WebRequest -Uri $robotoRegularUrl -OutFile "web/fonts/Roboto-Regular.woff2"
Invoke-WebRequest -Uri $robotoMediumUrl -OutFile "web/fonts/Roboto-Medium.woff2"
Invoke-WebRequest -Uri $robotoBoldUrl -OutFile "web/fonts/Roboto-Bold.woff2"
Invoke-WebRequest -Uri $robotoLightUrl -OutFile "web/fonts/Roboto-Light.woff2"
Invoke-WebRequest -Uri $materialIconsUrl -OutFile "web/assets/fonts/MaterialIcons-Regular.woff2"

# Copiar las fuentes WOFF2 también a la carpeta assets/fonts
Copy-Item "web/fonts/Roboto-Regular.woff2" -Destination "assets/fonts/Roboto-Regular.woff2"
Copy-Item "web/fonts/Roboto-Medium.woff2" -Destination "assets/fonts/Roboto-Medium.woff2"
Copy-Item "web/fonts/Roboto-Bold.woff2" -Destination "assets/fonts/Roboto-Bold.woff2"
Copy-Item "web/fonts/Roboto-Light.woff2" -Destination "assets/fonts/Roboto-Light.woff2"
Copy-Item "web/assets/fonts/MaterialIcons-Regular.woff2" -Destination "assets/fonts/MaterialIcons-Regular.woff2"

# Descargar fuentes en formato TTF
Write-Host "Descargando fuentes en formato TTF..."

Invoke-WebRequest -Uri $robotoRegularTtfUrl -OutFile "assets/fonts/Roboto/Roboto-Regular.ttf"
Copy-Item "assets/fonts/Roboto/Roboto-Regular.ttf" -Destination "web/assets/fonts/Roboto-Regular.ttf"

Write-Host "Todas las fuentes han sido descargadas correctamente!"
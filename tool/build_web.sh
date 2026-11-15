#!/usr/bin/env bash
# Compila el front web con los datos de UN negocio.
#
# Toda la marca y los datos propios del negocio (nombre, URL del backend, contacto, avisos) viven en un
# archivo `negocio.env` (copia `negocio.env.example`). El código no trae ningún dato de un negocio concreto.
#
# Uso:
#   bash tool/build_web.sh                                   # producción del negocio
#   bash tool/build_web.sh --dart-define=BACKEND_URL=https://staging.ejemplo.co   # staging (el último define gana)
#   NEGOCIO_ENV=otro.env bash tool/build_web.sh              # otro archivo de configuración
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${NEGOCIO_ENV:-negocio.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Falta $ENV_FILE: copia negocio.env.example y rellénalo." >&2
  exit 1
fi

defines=()
app_name=""
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|\#*) continue ;; esac
  defines+=("--dart-define=$line")
  case "$line" in APP_NAME=*) app_name="${line#APP_NAME=}" ;; esac
done < "$ENV_FILE"

if [ -z "$app_name" ]; then
  echo "APP_NAME es obligatorio en $ENV_FILE." >&2
  exit 1
fi

flutter build web "${defines[@]}" "$@"

# index.html y manifest.json traen el texto de plantilla «Mi Negocio»: se cambia en la carpeta compilada,
# no en los archivos del repositorio.
app_name_mayus="$(printf '%s' "$app_name" | tr '[:lower:]' '[:upper:]')"
sed -i "s/Mi Negocio/${app_name//\//\\/}/g; s/MI NEGOCIO/${app_name_mayus//\//\\/}/g" build/web/index.html build/web/manifest.json
echo "Listo: build/web compilado para «$app_name»."

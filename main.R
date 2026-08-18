# ============================================================
# main.R
# Punto de entrada del proyecto UrbanSense.
# Ejecuta todos los scripts en orden.
# ============================================================

# Establece el directorio de trabajo como la carpeta del script
args     <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("--file=", args, value = TRUE)
if (length(file_arg) > 0) {
  setwd(dirname(normalizePath(sub("--file=", "", file_arg))))
}

cat("==================================\n")
cat("  Análisis de contaminación\n")
cat("       acústica urbana\n")
cat("==================================\n\n")

cat("[1/6] Generando datos...\n")
source("scripts/01_generar_datos.R")

cat("\n[2/6] Importando y limpiando...\n")
source("scripts/02_importar_limpiar.R")

cat("\n[3/6] Analizando datos...\n")
source("scripts/03_analisis.R")

cat("\n[4/6] Ejecutando PCA...\n")
source("scripts/04_pca.R")

cat("\n[5/6] Series de tiempo y ARIMA...\n")
source("scripts/05_series_tiempo.R")

cat("\n[6/6] Analizando texto (datos no estructurados)...\n")
source("scripts/06_no_estructurados.R")

cat("\n==================================\n")
cat("  Proyecto finalizado correctamente.\n")
cat("==================================\n")

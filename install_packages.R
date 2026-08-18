# ============================================================
# install_packages.R
# Verifica e instala solo los paquetes que no están presentes.
# ============================================================

paquetes <- c(
  "tidyverse", "readxl", "writexl", "jsonlite", "xml2",
  "DBI", "RSQLite", "ggplot2", "leaflet", "htmlwidgets",
  "tidytext", "factoextra", "forecast", "lubridate"
) 

faltantes <- paquetes[!(paquetes %in% installed.packages()[, "Package"])]

if (length(faltantes) > 0) {
  cat("Instalando paquetes faltantes:", paste(faltantes, collapse = ", "), "\n")
  install.packages(faltantes, repos = "https://cloud.r-project.org")
} else {
  cat("Todos los paquetes ya están instalados.\n")
}

cat("Verificación completada.\n")

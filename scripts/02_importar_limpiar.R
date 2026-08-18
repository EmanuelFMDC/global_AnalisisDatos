# ============================================================
# 02_importar_limpiar.R
# Demuestra la lectura de múltiples formatos y aplica un
# proceso completo de limpieza sobre el dataset principal.
# ============================================================

library(tidyverse)
library(readxl)
library(jsonlite)
library(xml2)
library(DBI)
library(RSQLite)
library(lubridate)

# ============================================================
# IMPORTACIÓN DE DISTINTOS FORMATOS
# ============================================================

# CSV — el formato más común para datos tabulares
mediciones_raw <- read_csv("data/raw/mediciones.csv", show_col_types = FALSE)
cat("CSV cargado:", nrow(mediciones_raw), "filas,", ncol(mediciones_raw), "columnas\n")

# Excel — catálogo de zonas generado con writexl
zonas_excel <- readxl::read_excel("data/raw/zonas.xlsx")
cat("Excel cargado:", nrow(zonas_excel), "filas\n")

# JSON — lista de sensores; fromJSON lo convierte en data.frame automáticamente
sensores_json <- jsonlite::fromJSON("data/raw/sensores.json")
cat("JSON cargado:", nrow(sensores_json), "sensores\n")

# XML — árbol de nodos; se extraen los campos con xpath
xml_doc    <- xml2::read_xml("data/raw/zonas.xml")
nodos_zona <- xml_find_all(xml_doc, "//zona")
zonas_xml  <- tibble(
  nombre    = sapply(nodos_zona, function(n) xml_text(xml_find_first(n, "nombre"))),
  municipio = sapply(nodos_zona, function(n) xml_text(xml_find_first(n, "municipio"))),
  tipo      = sapply(nodos_zona, function(n) xml_text(xml_find_first(n, "tipo")))
)
cat("XML cargado:", nrow(zonas_xml), "zonas\n")

# SQLite — base de datos relacional ligera, consultada con SQL estándar
con          <- DBI::dbConnect(RSQLite::SQLite(), "data/raw/urbansense.sqlite")
sensores_sql <- DBI::dbGetQuery(con, "SELECT * FROM sensores WHERE estado = 'activo'")
DBI::dbDisconnect(con)
cat("SQLite cargado:", nrow(sensores_sql), "sensores activos\n")

# ============================================================
# DATA FRAMES Y TIBBLES
# Un data.frame es una tabla donde cada columna es un vector.
# tibble() es la versión moderna; ambas permiten operar columna a columna.
# ============================================================

cat("\nClase del objeto mediciones_raw:", class(mediciones_raw)[1], "\n")
# Cada columna es un vector; se puede acceder con $
cat("Clase de la columna decibeles:", class(mediciones_raw$decibeles), "\n")
cat("Primeros 5 valores de decibeles:", head(mediciones_raw$decibeles, 5), "\n")

# Trabajamos desde aquí con el CSV
mediciones <- mediciones_raw

# ============================================================
# JOINS — combinar tablas por columnas en común
# ============================================================

# inner_join: conserva solo filas con coincidencia en ambas tablas
# Normalizamos zona antes del join para que los casos inconsistentes también coincidan
mediciones_join <- mediciones %>%
  mutate(zona_norm = str_to_title(str_trim(as.character(zona)))) %>%
  inner_join(zonas_excel, by = c("zona_norm" = "zona"))

cat("\nFilas tras inner_join con catálogo de zonas:", nrow(mediciones_join), "\n")

# full_join demo: conserva TODAS las filas de ambas tablas, con NA donde no hay coincidencia
ejemplo_a    <- tibble(id = 1:3, valor   = c(10, 20, 30))
ejemplo_b    <- tibble(id = 2:4, etiqueta = c("B", "C", "D"))
demo_fulljoin <- full_join(ejemplo_a, ejemplo_b, by = "id")
cat("\nEjemplo full_join (filas con NA donde no hay coincidencia):\n")
print(demo_fulljoin)

# ============================================================
# CONVERSIÓN DE TIPOS
# ============================================================

mediciones <- mediciones %>%
  mutate(
    fecha     = as.Date(fecha),
    hora      = as.integer(hora),
    decibeles = as.numeric(decibeles),
    trafico   = as.numeric(trafico),
    zona      = as.character(zona),
    tipo_zona = as.character(tipo_zona)
  )

# ============================================================
# DUPLICADOS
# ============================================================

n_antes <- nrow(mediciones)
mediciones <- distinct(mediciones)
n_dup <- n_antes - nrow(mediciones)
cat("\nFilas duplicadas eliminadas:", n_dup, "\n")
cat("Filas tras distinct():", nrow(mediciones), "\n")

# ============================================================
# VALORES FALTANTES
# ============================================================

cat("\nNA por columna antes de imputar:\n")
print(colSums(is.na(mediciones)))

# Función para obtener el valor más frecuente de un vector
moda <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA)
  unique(x)[which.max(tabulate(match(x, unique(x))))]
}

# Imputar variables numéricas con la mediana (robusta ante outliers)
for (col in c("decibeles", "trafico", "temperatura", "humedad")) {
  val_mediana <- median(mediciones[[col]], na.rm = TRUE)
  mediciones[[col]][is.na(mediciones[[col]])] <- val_mediana
}

# Imputar variables categóricas con la moda
mediciones$zona[is.na(mediciones$zona)]           <- moda(mediciones$zona)
mediciones$tipo_zona[is.na(mediciones$tipo_zona)] <- moda(mediciones$tipo_zona)

cat("NA restantes:", sum(is.na(mediciones)), "\n")

# ============================================================
# CORRECCIÓN DE CATEGORÍAS INCONSISTENTES
# str_to_title convierte "CENTRO" y "centro" → "Centro"
# ============================================================

mediciones <- mediciones %>%
  mutate(zona = str_to_title(str_trim(zona)))

cat("\nValores únicos de zona tras normalización:\n")
print(sort(unique(mediciones$zona)))

# Convertir a factor después de limpiar
mediciones <- mediciones %>%
  mutate(tipo_zona = as.factor(tipo_zona))

# ============================================================
# OUTLIERS EN DECIBELES
# ============================================================

# Función IQR para detectar outliers
detectar_outliers <- function(x) {
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr)
}

# Eliminar valores físicamente imposibles (> 194 dB)
n_imposibles <- sum(mediciones$decibeles > 194, na.rm = TRUE)
cat("\nValores imposibles (>194 dB) eliminados:", n_imposibles, "\n")
mediciones <- mediciones %>% filter(decibeles <= 194)

# Marcar outliers extremos pero posibles con columna auxiliar
mediciones <- mediciones %>%
  mutate(es_outlier = detectar_outliers(decibeles))
cat("Outliers marcados (IQR):", sum(mediciones$es_outlier), "\n")

# ============================================================
# NORMALIZACIÓN
# scale() centra (media = 0) y escala (desv.std = 1) las variables.
# Útil para comparar variables con unidades distintas.
# ============================================================

mediciones_norm <- mediciones %>%
  mutate(across(c(decibeles, trafico, temperatura, humedad),
                ~ as.numeric(scale(.x))))

cat("\nEjemplo de normalización — media decibeles (debe ser ~0):",
    round(mean(mediciones_norm$decibeles), 4), "\n")

# ============================================================
# GUARDAR DATOS LIMPIOS
# ============================================================

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
write_csv(mediciones, "data/processed/mediciones_limpias.csv")
cat("\nmediciones_limpias.csv guardado:", nrow(mediciones), "filas\n")

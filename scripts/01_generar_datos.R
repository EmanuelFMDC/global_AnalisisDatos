# ============================================================
# 01_generar_datos.R
# Genera ~1500 mediciones sintéticas de ruido urbano con
# relaciones realistas entre variables, y los archivos
# auxiliares en distintos formatos (CSV, Excel, JSON, XML, SQL).
# ============================================================

library(tidyverse)
library(writexl)
library(jsonlite)
library(DBI)
library(RSQLite)
library(lubridate)

set.seed(123)

n <- 1500

# Características base de cada zona: nivel de ruido y tráfico típico
zonas_info <- tibble(
  zona       = c("Centro", "Americana", "Providencia", "Chapalita",
                 "Zona Industrial", "Tlaquepaque Centro"),
  tipo_zona  = c("Comercial", "Mixta", "Residencial", "Residencial",
                 "Industrial", "Comercial"),
  ruido_base = c(72, 65, 55, 50, 82, 70),
  traf_base  = c(72, 62, 40, 32, 55, 68),
  lat        = c(20.6737, 20.6666, 20.6612, 20.6580, 20.6450, 20.6420),
  lng        = c(-103.3440, -103.3810, -103.3890, -103.4020, -103.3200, -103.3120)
)

# Fechas: últimos 6 meses
fechas    <- seq(as.Date("2025-02-01"), as.Date("2025-07-31"), by = "day")
fecha_vec <- sample(fechas, n, replace = TRUE)
hora_vec  <- sample(0:23,   n, replace = TRUE)

# Asignar zona aleatoriamente a cada medición
zona_idx   <- sample(1:6, n, replace = TRUE)
zona_vec   <- zonas_info$zona[zona_idx]
tipo_vec   <- zonas_info$tipo_zona[zona_idx]
lat_vec    <- zonas_info$lat[zona_idx]
lng_vec    <- zonas_info$lng[zona_idx]
ruido_base <- zonas_info$ruido_base[zona_idx]
traf_base  <- zonas_info$traf_base[zona_idx]

# Horas pico generan más ruido y tráfico; la madrugada es silenciosa
factor_hora <- case_when(
  hora_vec %in% 7:9   ~ 1.30,
  hora_vec %in% 17:19 ~ 1.25,
  hora_vec %in% 0:5   ~ 0.50,
  TRUE                 ~ 1.00
)

# Los fines de semana tienen menos tráfico en zonas comerciales e industriales
es_finde     <- wday(fecha_vec) %in% c(1, 7)  # 1=domingo, 7=sábado en lubridate
factor_finde <- ifelse(es_finde, 0.85, 1.0)

# Tráfico: 0–100 correlacionado con zona, hora y día
trafico_vec <- as.integer(round(pmax(0, pmin(100,
  traf_base * factor_hora * factor_finde + rnorm(n, 0, 8)
))))

# Decibeles: correlacionados con zona, tráfico y hora
decibeles_vec <- round(pmax(30, pmin(115,
  ruido_base * factor_hora * factor_finde + 0.12 * trafico_vec + rnorm(n, 0, 4)
)), 1)

# Temperatura: más alta al mediodía, más baja de madrugada
temperatura_vec <- round(
  22 + ifelse(hora_vec %in% 12:16, 8,
       ifelse(hora_vec %in% 0:5,  -4, 2)) + rnorm(n, 0, 2),
  1
)

# Humedad relativa (%)
humedad_vec <- round(pmax(20, pmin(95, 60 + rnorm(n, 0, 12))), 1)

# Comentarios de texto libre (usados en el análisis de texto del script 06)
comentarios_pool <- c(
  "Mucho tráfico", "Zona tranquila", "Muchos camiones",
  "Ruido por construcción", "Música alta", "Tráfico intenso",
  "Sin incidencias", "Obras en la zona", "Mercado cercano",
  "Mucho ruido", "Zona ruidosa", "Poco tráfico"
)
comentario_vec <- sample(comentarios_pool, n, replace = TRUE)

# Data frame principal
mediciones <- tibble(
  id          = 1:n,
  fecha       = fecha_vec,
  hora        = hora_vec,
  zona        = zona_vec,
  tipo_zona   = tipo_vec,
  lat         = lat_vec,
  lng         = lng_vec,
  decibeles   = decibeles_vec,
  trafico     = trafico_vec,
  temperatura = temperatura_vec,
  humedad     = humedad_vec,
  comentario  = comentario_vec
)

# ============================================================
# DATOS SUCIOS — introducidos intencionalmente para demostrar
# las técnicas de limpieza en el script 02.
# ============================================================

# Error 1: categorías inconsistentes en la columna zona
idx_inc <- sample(1:n, 30)
mediciones$zona[idx_inc[1:10]]  <- "centro"          # todo minúsculas
mediciones$zona[idx_inc[11:20]] <- "CENTRO"           # todo mayúsculas
mediciones$zona[idx_inc[21:30]] <- "zona industrial"  # minúsculas compuesto

# Error 2: valor físicamente imposible (>194 dB no existe en la naturaleza)
idx_imp <- sample(1:n, 3)
mediciones$decibeles[idx_imp] <- 350

# Error 3: outliers extremos pero posibles (se marcarán, no se borrarán)
idx_out <- sample(setdiff(1:n, idx_imp), 5)
mediciones$decibeles[idx_out] <- c(115, 118, 120, 119, 116)

# Error 4: valores NA distribuidos en distintas columnas (~20 total)
for (col in c("decibeles", "trafico", "temperatura", "humedad")) {
  mediciones[[col]][sample(1:n, 4)] <- NA
}
mediciones$zona[sample(1:n, 3)]      <- NA
mediciones$tipo_zona[sample(1:n, 3)] <- NA

# Error 5: filas duplicadas (simulan doble carga desde el sensor)
idx_dup    <- sample(1:n, 10)
mediciones <- bind_rows(mediciones, mediciones[idx_dup, ])

# ============================================================
# GUARDAR ARCHIVOS EN DISTINTOS FORMATOS
# ============================================================

dir.create("data/raw",       recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

# CSV — dataset principal
write_csv(mediciones, "data/raw/mediciones.csv")
cat("  -> mediciones.csv generado:", nrow(mediciones), "filas\n")

# Excel — catálogo de zonas
zonas_cat <- tibble(
  zona      = c("Centro", "Americana", "Providencia",
                "Chapalita", "Zona Industrial", "Tlaquepaque Centro"),
  municipio = c("Guadalajara", "Guadalajara", "Guadalajara",
                "Guadalajara", "Guadalajara", "Tlaquepaque"),
  tipo_zona = c("Comercial", "Mixta", "Residencial",
                "Residencial", "Industrial", "Comercial")
)
writexl::write_xlsx(zonas_cat, "data/raw/zonas.xlsx")
cat("  -> zonas.xlsx generado\n")

# JSON — lista de sensores
sensores_list <- list(
  list(sensor_id = "S001", nombre = "Sensor Centro Norte",  zona = "Centro",             estado = "activo"),
  list(sensor_id = "S002", nombre = "Sensor Americana",     zona = "Americana",          estado = "activo"),
  list(sensor_id = "S003", nombre = "Sensor Providencia",   zona = "Providencia",        estado = "inactivo"),
  list(sensor_id = "S004", nombre = "Sensor Industrial A",  zona = "Zona Industrial",    estado = "activo"),
  list(sensor_id = "S005", nombre = "Sensor Tlaquepaque",   zona = "Tlaquepaque Centro", estado = "activo"),
  list(sensor_id = "S006", nombre = "Sensor Chapalita",     zona = "Chapalita",          estado = "mantenimiento")
)
jsonlite::write_json(sensores_list, "data/raw/sensores.json", pretty = TRUE)
cat("  -> sensores.json generado\n")

# XML — construido como texto para evitar dependencias adicionales
xml_lines <- c('<?xml version="1.0" encoding="UTF-8"?>', "<zonas>")
for (i in seq_len(nrow(zonas_cat))) {
  xml_lines <- c(xml_lines,
    "  <zona>",
    paste0("    <nombre>",    zonas_cat$zona[i],      "</nombre>"),
    paste0("    <municipio>", zonas_cat$municipio[i], "</municipio>"),
    paste0("    <tipo>",      zonas_cat$tipo_zona[i], "</tipo>"),
    "  </zona>"
  )
}
xml_lines <- c(xml_lines, "</zonas>")
writeLines(xml_lines, "data/raw/zonas.xml", useBytes = FALSE)
cat("  -> zonas.xml generado\n")

# SQLite — tabla de sensores en base de datos relacional
con <- DBI::dbConnect(RSQLite::SQLite(), "data/raw/urbansense.sqlite")
sensores_df <- data.frame(
  sensor_id = c("S001", "S002", "S003", "S004", "S005", "S006"),
  nombre    = c("Sensor Centro Norte", "Sensor Americana", "Sensor Providencia",
                "Sensor Industrial A", "Sensor Tlaquepaque", "Sensor Chapalita"),
  zona      = c("Centro", "Americana", "Providencia",
                "Zona Industrial", "Tlaquepaque Centro", "Chapalita"),
  estado    = c("activo", "activo", "inactivo", "activo", "activo", "mantenimiento"),
  stringsAsFactors = FALSE
)
DBI::dbWriteTable(con, "sensores", sensores_df, overwrite = TRUE)
DBI::dbDisconnect(con)
cat("  -> urbansense.sqlite generado\n")

# ============================================================
# 03_analisis.R
# Análisis exploratorio: estadísticas, visualizaciones y mapa.
# ============================================================

library(tidyverse)
library(lubridate)
library(leaflet)
library(htmlwidgets)

dir.create("outputs/graficas", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/mapa",     recursive = TRUE, showWarnings = FALSE)

# Cargar el dataset limpio generado por el script 02
mediciones <- read_csv("data/processed/mediciones_limpias.csv", show_col_types = FALSE) %>%
  mutate(
    fecha     = as.Date(fecha),
    tipo_zona = as.factor(tipo_zona)
  )

cat("Dataset cargado:", nrow(mediciones), "filas\n")

# ============================================================
# OPERACIONES DPLYR
# ============================================================

# filter() — filas que cumplen una condición
alta_contaminacion <- mediciones %>% filter(decibeles > 80)
cat("Mediciones > 80 dB:", nrow(alta_contaminacion), "\n")

# select() — elegir solo las columnas necesarias
vista_reducida <- mediciones %>% select(zona, tipo_zona, decibeles, trafico)

# Agrupamos las mediciones por zona para obtener el nivel promedio de ruido de cada sector
ruido_por_zona <- mediciones %>%
  group_by(zona) %>%
  summarise(
    decibeles_prom = round(mean(decibeles, na.rm = TRUE), 2),
    trafico_prom   = round(mean(trafico,   na.rm = TRUE), 2),
    n_mediciones   = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(decibeles_prom))   # arrange() ordena de mayor a menor ruido

cat("\nRuido promedio por zona:\n")
print(ruido_por_zona)

# bind_rows() — unir dos subconjuntos en un solo data frame
mañana      <- mediciones %>% filter(hora %in% 6:11)
tarde       <- mediciones %>% filter(hora %in% 12:17)
dia_laboral <- bind_rows(mañana, tarde)
cat("\nMediciones en horario laboral (6–17h):", nrow(dia_laboral), "\n")

# ============================================================
# ESTADÍSTICAS DESCRIPTIVAS DE DECIBELES
# ============================================================

cat("\n--- Estadísticas de decibeles ---\n")
cat("Media:              ", round(mean(mediciones$decibeles,            na.rm = TRUE), 2), "\n")
cat("Mediana:            ", round(median(mediciones$decibeles,          na.rm = TRUE), 2), "\n")
cat("Desviación estándar:", round(sd(mediciones$decibeles,              na.rm = TRUE), 2), "\n")
cat("Mínimo:             ", round(min(mediciones$decibeles,             na.rm = TRUE), 2), "\n")
cat("Máximo:             ", round(max(mediciones$decibeles,             na.rm = TRUE), 2), "\n")
cat("Q1:                 ", round(quantile(mediciones$decibeles, 0.25,  na.rm = TRUE), 2), "\n")
cat("Q3:                 ", round(quantile(mediciones$decibeles, 0.75,  na.rm = TRUE), 2), "\n")
cat("IQR:                ", round(IQR(mediciones$decibeles,             na.rm = TRUE), 2), "\n")

cat("\nRuido promedio por tipo de zona:\n")
mediciones %>%
  group_by(tipo_zona) %>%
  summarise(decibeles_prom = round(mean(decibeles, na.rm = TRUE), 2), .groups = "drop") %>%
  arrange(desc(decibeles_prom)) %>%
  print()

# ============================================================
# VISUALIZACIONES CON GGPLOT2
# ============================================================

# 1. Histograma — distribución general de los decibeles
p1 <- ggplot(mediciones, aes(x = decibeles)) +
  geom_histogram(binwidth = 3, fill = "#2196F3", color = "white", alpha = 0.85) +
  labs(title = "Distribución de niveles de ruido",
       x = "Decibeles (dB)", y = "Frecuencia") +
  theme_minimal()
ggsave("outputs/graficas/histograma_ruido.png", p1, width = 8, height = 5, dpi = 150)

# 2. Density plot — curva de densidad suavizada
p2 <- ggplot(mediciones, aes(x = decibeles)) +
  geom_density(fill = "#4CAF50", color = "#2E7D32", alpha = 0.65) +
  labs(title = "Densidad de niveles de ruido",
       x = "Decibeles (dB)", y = "Densidad") +
  theme_minimal()
ggsave("outputs/graficas/densidad_ruido.png", p2, width = 8, height = 5, dpi = 150)

# 3. Boxplot — cajas y bigotes por tipo de zona
p3 <- ggplot(mediciones, aes(x = tipo_zona, y = decibeles, fill = tipo_zona)) +
  geom_boxplot(alpha = 0.8, outlier.color = "red", outlier.size = 1) +
  labs(title = "Distribución de ruido por tipo de zona",
       x = "Tipo de zona", y = "Decibeles (dB)") +
  theme_minimal() + theme(legend.position = "none")
ggsave("outputs/graficas/boxplot_zonas.png", p3, width = 8, height = 5, dpi = 150)

# 4. Violin plot — muestra la distribución completa como silueta
p4 <- ggplot(mediciones, aes(x = tipo_zona, y = decibeles, fill = tipo_zona)) +
  geom_violin(alpha = 0.7, trim = FALSE) +
  geom_boxplot(width = 0.08, fill = "white", outlier.size = 0.8) +
  labs(title = "Violín de ruido por tipo de zona",
       x = "Tipo de zona", y = "Decibeles (dB)") +
  theme_minimal() + theme(legend.position = "none")
ggsave("outputs/graficas/violin_zonas.png", p4, width = 8, height = 5, dpi = 150)

# 5. Barplot — ruido promedio por zona ordenado de mayor a menor
p5 <- ggplot(ruido_por_zona,
             aes(x = reorder(zona, decibeles_prom), y = decibeles_prom, fill = zona)) +
  geom_col(alpha = 0.85) +
  coord_flip() +
  labs(title = "Ruido promedio por zona",
       x = "Zona", y = "Decibeles promedio (dB)") +
  theme_minimal() + theme(legend.position = "none")
ggsave("outputs/graficas/ruido_por_zona.png", p5, width = 8, height = 5, dpi = 150)

# 6. Scatter plot — relación entre tráfico y decibeles
p6 <- ggplot(mediciones, aes(x = trafico, y = decibeles, color = tipo_zona)) +
  geom_point(alpha = 0.35, size = 1.2) +
  geom_smooth(method = "lm", se = FALSE, color = "black", linewidth = 0.9) +
  labs(title = "Relación entre tráfico y ruido",
       x = "Índice de tráfico", y = "Decibeles (dB)", color = "Tipo de zona") +
  theme_minimal()
ggsave("outputs/graficas/trafico_ruido.png", p6, width = 8, height = 5, dpi = 150)

# 7. Heatmap — ruido promedio según día de la semana y hora del día
dias_labels <- c("Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom")
mediciones_hm <- mediciones %>%
  mutate(dia_num = wday(fecha, week_start = 1)) %>%
  group_by(dia_num, hora) %>%
  summarise(ruido_prom = mean(decibeles, na.rm = TRUE), .groups = "drop") %>%
  mutate(dia_label = factor(dias_labels[dia_num], levels = dias_labels))

p7 <- ggplot(mediciones_hm, aes(x = hora, y = dia_label, fill = ruido_prom)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#fff9c4", high = "#f44336") +
  labs(title = "Ruido promedio por día de semana y hora",
       x = "Hora del día", y = "Día", fill = "dB prom") +
  theme_minimal()
ggsave("outputs/graficas/heatmap_ruido.png", p7, width = 10, height = 5, dpi = 150)

cat("Gráficas guardadas en outputs/graficas/\n")

# ============================================================
# MAPA INTERACTIVO — LEAFLET
# Se usa información agregada por zona (no las 1500 mediciones)
# para mantener el mapa sencillo y rápido.
# ============================================================

# Coordenadas y estadísticas por zona
coords_zona <- mediciones %>%
  group_by(zona) %>%
  summarise(
    lat            = first(lat),
    lng            = first(lng),
    decibeles_prom = round(mean(decibeles, na.rm = TRUE), 1),
    trafico_prom   = round(mean(trafico,   na.rm = TRUE), 1),
    .groups = "drop"
  )

# Paleta de colores según nivel de ruido
pal_ruido <- colorBin(
  palette = c("green", "orange", "red"),
  bins    = c(0, 60, 75, 200),
  domain  = coords_zona$decibeles_prom
)

mapa <- leaflet(coords_zona) %>%
  addTiles() %>%
  addCircleMarkers(
    lng         = ~lng,
    lat         = ~lat,
    color       = ~pal_ruido(decibeles_prom),
    fillColor   = ~pal_ruido(decibeles_prom),
    fillOpacity = 0.85,
    radius      = 14,
    stroke      = TRUE,
    weight      = 2,
    popup = ~paste0(
      "<b>", zona, "</b><br>",
      "Ruido promedio: <b>", decibeles_prom, " dB</b><br>",
      "Tráfico promedio: ", trafico_prom
    )
  ) %>%
  addLegend(
    position = "bottomright",
    colors   = c("green", "orange", "red"),
    labels   = c("< 60 dB", "60–75 dB", "> 75 dB"),
    title    = "Nivel de ruido"
  )

htmlwidgets::saveWidget(mapa, file = normalizePath("outputs/mapa/mapa_ruido.html",
                                                    mustWork = FALSE),
                        selfcontained = FALSE)
cat("Mapa guardado en outputs/mapa/mapa_ruido.html\n")

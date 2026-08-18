# ============================================================
# 05_series_tiempo.R
# Análisis de la serie temporal de ruido promedio diario:
# gráfica, autocorrelación, estacionalidad y predicción ARIMA.
# ============================================================

library(tidyverse)
library(lubridate)
library(forecast)

dir.create("outputs/graficas", recursive = TRUE, showWarnings = FALSE)

mediciones <- read_csv("data/processed/mediciones_limpias.csv", show_col_types = FALSE) %>%
  mutate(fecha = as.Date(fecha))

# Agrupar por fecha para obtener el ruido promedio de cada día
serie_diaria <- mediciones %>%
  group_by(fecha) %>%
  summarise(decibeles_promedio = mean(decibeles, na.rm = TRUE), .groups = "drop") %>%
  arrange(fecha)

cat("Puntos en la serie diaria:", nrow(serie_diaria), "\n")
cat("Desde:", format(min(serie_diaria$fecha)), "hasta:", format(max(serie_diaria$fecha)), "\n")

# ============================================================
# GRÁFICA TEMPORAL
# ============================================================

p_serie <- ggplot(serie_diaria, aes(x = fecha, y = decibeles_promedio)) +
  geom_line(color = "#1565C0", linewidth = 0.8) +
  geom_smooth(method = "loess", se = TRUE, color = "#E53935",
              fill = "#FFCDD2", linewidth = 0.7) +
  labs(title = "Ruido promedio diario",
       x = "Fecha", y = "Decibeles promedio (dB)") +
  theme_minimal()
ggsave("outputs/graficas/serie_ruido.png", p_serie, width = 10, height = 4, dpi = 150)

# Construir objeto ts con frecuencia semanal (7 días por ciclo)
ts_ruido <- ts(serie_diaria$decibeles_promedio, frequency = 7)

# ============================================================
# AUTOCORRELACIÓN (ACF)
# ACF mide la relación entre el valor actual y los valores
# anteriores de la serie. Picos en el lag 7 indicarían un
# patrón semanal en el ruido.
# ============================================================

png("outputs/graficas/acf_ruido.png", width = 800, height = 480, res = 120)
acf(ts_ruido, main = "Autocorrelación del ruido diario (ACF)", lag.max = 28)
dev.off()
cat("ACF guardada.\n")

# ============================================================
# DESCOMPOSICIÓN ESTACIONAL (STL)
# Separa la serie en: tendencia + estacionalidad + residuo.
# Necesita al menos 2 periodos completos (≥14 días aquí).
# ============================================================

if (length(ts_ruido) >= 14) {
  tryCatch({
    descomp <- stl(ts_ruido, s.window = "periodic", robust = TRUE)
    png("outputs/graficas/estacionalidad_ruido.png", width = 800, height = 600, res = 120)
    plot(descomp, main = "Descomposición STL — Ruido diario")
    dev.off()
    cat("Descomposición STL guardada.\n")
  }, error = function(e) {
    cat("STL no disponible:", conditionMessage(e), "\n")
  })
}

# ============================================================
# MODELO ARIMA
# auto.arima elige automáticamente los parámetros (p, d, q)
# que mejor ajustan la serie según criterio AIC.
# ============================================================

cat("\nAjustando modelo ARIMA...\n")
modelo_arima <- forecast::auto.arima(ts_ruido, stepwise = TRUE, approximation = TRUE)
cat("Modelo seleccionado:\n")
print(modelo_arima)

# Predicción para los próximos 7 días
pred <- forecast::forecast(modelo_arima, h = 7)
cat("\nPredicción (próximos 7 días):\n")
print(pred)

# Guardar gráfica de predicción con intervalos de confianza
png("outputs/graficas/prediccion_arima.png", width = 900, height = 480, res = 120)
plot(pred,
     main = "Predicción ARIMA — Ruido diario (7 días)",
     xlab = "Período",
     ylab = "Decibeles (dB)",
     col  = "#1565C0")
dev.off()

cat("Predicción ARIMA guardada.\n")

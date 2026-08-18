# ============================================================
# 04_pca.R
# Análisis de Componentes Principales (PCA).
#
# PCA reduce la dimensionalidad: en lugar de analizar 4
# variables por separado, las combina en nuevos ejes llamados
# "componentes principales" que capturan la mayor varianza
# posible. Así podemos visualizar en 2D lo que era 4D.
# ============================================================

library(tidyverse)
library(factoextra)

dir.create("outputs/graficas", recursive = TRUE, showWarnings = FALSE)

mediciones <- read_csv("data/processed/mediciones_limpias.csv", show_col_types = FALSE)

# Seleccionar las 4 variables numéricas de interés y eliminar NAs
datos_pca <- mediciones %>%
  select(decibeles, trafico, temperatura, humedad, zona, tipo_zona) %>%
  drop_na()

cat("Observaciones para PCA:", nrow(datos_pca), "\n")

# Ejecutar PCA con centrado y escalado para que todas las variables
# tengan el mismo peso independientemente de sus unidades
pca_result <- prcomp(
  datos_pca %>% select(decibeles, trafico, temperatura, humedad),
  center = TRUE,
  scale. = TRUE
)

cat("\n=== Resumen PCA ===\n")
print(summary(pca_result))

# Varianza explicada por cada componente principal
varianza_exp <- pca_result$sdev^2 / sum(pca_result$sdev^2)
cat("\nVarianza explicada por componente:\n")
for (i in seq_along(varianza_exp)) {
  cat(sprintf("  PC%d: %.1f%%\n", i, varianza_exp[i] * 100))
}

# Loadings: indican cuánto contribuye cada variable original a cada PC
cat("\nLoadings (contribución de cada variable a cada PC):\n")
print(round(pca_result$rotation, 3))

# Scree plot — visualiza la varianza explicada por cada componente
p_scree <- fviz_eig(pca_result, addlabels = TRUE, ylim = c(0, 70)) +
  labs(title = "Varianza explicada por componente (Scree plot)") +
  theme_minimal()
ggsave("outputs/graficas/pca_varianza.png", p_scree, width = 7, height = 5, dpi = 150)

# Gráfica PC1 vs PC2 — cada punto es una medición proyectada en 2 componentes
scores <- as.data.frame(pca_result$x) %>%
  mutate(
    zona      = datos_pca$zona,
    tipo_zona = datos_pca$tipo_zona
  )

p_comp <- ggplot(scores, aes(x = PC1, y = PC2, color = tipo_zona)) +
  geom_point(alpha = 0.4, size = 1.5) +
  stat_ellipse(level = 0.85, linewidth = 0.8) +
  labs(title  = "PCA — PC1 vs PC2 por tipo de zona",
       x      = paste0("PC1 (", round(varianza_exp[1] * 100, 1), "%)"),
       y      = paste0("PC2 (", round(varianza_exp[2] * 100, 1), "%)"),
       color  = "Tipo de zona") +
  theme_minimal()
ggsave("outputs/graficas/pca_componentes.png", p_comp, width = 8, height = 5, dpi = 150)

cat("Gráficas PCA guardadas.\n")

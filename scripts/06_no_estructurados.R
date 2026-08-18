# ============================================================
# 06_no_estructurados.R
# Análisis básico de texto como ejemplo de dato no estructurado.
#
# Los comentarios del sensor son texto libre: no tienen
# columnas, ni filas, ni estructura fija. Para analizarlos
# los convertimos en una tabla de palabras (tokenización).
# ============================================================

library(tidyverse)
library(tidytext)

dir.create("outputs/graficas", recursive = TRUE, showWarnings = FALSE)

mediciones <- read_csv("data/processed/mediciones_limpias.csv", show_col_types = FALSE)

cat("Total de comentarios:", nrow(mediciones), "\n")
cat("Comentarios únicos:\n")
print(sort(unique(mediciones$comentario)))

# ============================================================
# TOKENIZACIÓN
# unnest_tokens() separa cada comentario en palabras individuales
# (tokens) y las pone en minúsculas automáticamente.
# ============================================================

palabras <- mediciones %>%
  select(id, comentario) %>%
  unnest_tokens(palabra, comentario)

cat("\nTotal de tokens generados:", nrow(palabras), "\n")

# Palabras vacías en español que no aportan significado al análisis
stop_words_es <- c("de", "la", "el", "en", "y", "a", "por", "los", "las",
                   "un", "una", "con", "se", "es", "al", "del")

# Calcular la frecuencia de cada palabra, excluyendo palabras vacías
frecuencia <- palabras %>%
  filter(!palabra %in% stop_words_es) %>%
  count(palabra, sort = TRUE)

cat("\nTop 10 palabras más frecuentes:\n")
print(head(frecuencia, 10))

# Gráfica de barras horizontales con las 10 palabras más frecuentes
p_palabras <- frecuencia %>%
  slice_head(n = 10) %>%
  ggplot(aes(x = reorder(palabra, n), y = n, fill = n)) +
  geom_col(show.legend = FALSE) +
  scale_fill_gradient(low = "#81D4FA", high = "#0D47A1") +
  coord_flip() +
  labs(title = "10 palabras más frecuentes en los comentarios de sensores",
       x = "Palabra", y = "Frecuencia") +
  theme_minimal()

ggsave("outputs/graficas/palabras_frecuentes.png", p_palabras,
       width = 7, height = 5, dpi = 150)

cat("Gráfica guardada en outputs/graficas/palabras_frecuentes.png\n")

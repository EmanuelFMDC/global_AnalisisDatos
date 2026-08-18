# Análisis de contaminación acústica urbana

Proyecto universitario en R que analiza mediciones sintéticas de ruido en zonas urbanas de la Zona Metropolitana de Guadalajara.

---

## ¿Qué es?

Simula el ciclo completo de análisis de datos: generación de datos sucios, importación en múltiples formatos, limpieza, análisis estadístico, visualizaciones, mapa interactivo, PCA, series de tiempo y análisis de texto.

---

## Objetivo

Responder preguntas como:
- ¿Qué zonas son más ruidosas?
- ¿En qué horarios aumenta el ruido?
- ¿Existe relación entre tráfico y ruido?
- ¿Qué tipo de zona tiene mayor contaminación acústica?
- ¿Podemos predecir el ruido de los próximos días?

---

## Dataset

El dataset principal contiene ~1500 mediciones con las siguientes variables:

| Variable    | Descripción                                      |
|-------------|--------------------------------------------------|
| id          | Identificador único de la medición               |
| fecha       | Fecha de la medición (Date)                      |
| hora        | Hora del día 0–23                                |
| zona        | Nombre de la zona urbana                         |
| tipo_zona   | Comercial / Residencial / Industrial / Mixta     |
| lat / lng   | Coordenadas geográficas                          |
| decibeles   | Nivel de ruido en dB                             |
| trafico     | Índice de tráfico (0–100)                        |
| temperatura | Temperatura ambiente (°C)                        |
| humedad     | Humedad relativa (%)                             |
| comentario  | Texto libre del operador del sensor              |

Los datos incluyen relaciones realistas: horas pico = más ruido, zona industrial = más ruido, madrugada = menos ruido.

---

## Formatos de datos

El proyecto demuestra importación desde cinco formatos distintos:

- **CSV** (`mediciones.csv`): dataset principal, leído con `read_csv()`.
- **Excel** (`zonas.xlsx`): catálogo de zonas, leído con `read_excel()`.
- **JSON** (`sensores.json`): lista de sensores, leído con `fromJSON()`.
- **XML** (`zonas.xml`): catálogo en árbol, leído con `read_xml()` y XPath.
- **SQL** (`urbansense.sqlite`): tabla de sensores en SQLite, consultado con `dbGetQuery()`.

---

## Procesamiento

- **DataFrames / Tibbles**: cada columna es un vector; se demuestra el acceso con `$` y operaciones vectorizadas.
- **Joins**: `inner_join()` entre mediciones y catálogo de zonas; `full_join()` de demostración.
- **Agrupaciones**: `group_by()` + `summarise()` para calcular promedios por zona y tipo.
- **Agregaciones**: `bind_rows()`, `filter()`, `select()`, `arrange()`.

---

## Limpieza

| Problema                    | Solución aplicada                                              |
|-----------------------------|----------------------------------------------------------------|
| Filas duplicadas            | `distinct()` para eliminarlas                                  |
| Valores NA (~20)            | Imputación con mediana (numérico) o moda (categórico)          |
| Categorías inconsistentes   | `str_to_title()` normaliza "CENTRO", "centro" → "Centro"       |
| Valores imposibles          | Eliminados (decibeles > 194 dB no existe físicamente)          |
| Outliers extremos           | Detectados con IQR y marcados en columna `es_outlier`          |
| Normalización               | `scale()` centra y escala variables numéricas (media=0, sd=1)  |

---

## Visualizaciones

| Archivo                    | Descripción                              |
|----------------------------|------------------------------------------|
| `histograma_ruido.png`     | Distribución de decibeles                |
| `densidad_ruido.png`       | Curva de densidad suavizada              |
| `boxplot_zonas.png`        | Cajas y bigotes por tipo de zona         |
| `violin_zonas.png`         | Violines por tipo de zona                |
| `ruido_por_zona.png`       | Barras del ruido promedio por zona       |
| `trafico_ruido.png`        | Dispersión tráfico vs decibeles          |
| `heatmap_ruido.png`        | Ruido promedio por día de semana y hora  |
| `mapa_ruido.html`          | Mapa interactivo Leaflet                 |

---

## Datos no estructurados

### Texto

Los comentarios de los sensores son datos **no estructurados**: texto libre sin estructura de tabla. El script `06_no_estructurados.R` los tokeniza (separa en palabras individuales) usando `tidytext` y calcula las 10 palabras más frecuentes, generando una gráfica de barras.

### Data Lake (concepto simplificado)

```
data/raw/        ← Zona RAW: datos originales sin modificar
      ↓
   LIMPIEZA
      ↓
data/processed/  ← Datos limpios listos para análisis
      ↓
   ANÁLISIS
```

Se conservan siempre los datos originales en `raw/` y se trabaja sobre copias limpias en `processed/`.

---

## PCA — Análisis de Componentes Principales

PCA toma las 4 variables numéricas (`decibeles`, `trafico`, `temperatura`, `humedad`) y las **combina en nuevos ejes (componentes)** que resumen la mayor varianza posible. Permite:

- Ver en 2 dimensiones (PC1 vs PC2) lo que era 4D.
- Identificar qué variables están más correlacionadas.
- Reducir redundancia antes de otros análisis.

---

## Series de tiempo

### Autocorrelación (ACF)
Mide cuánto se parece el valor de hoy con el de hace 1, 2, 3... días. Picos significativos indican que el pasado predice el futuro (por ejemplo, un patrón semanal repetido).

### Estacionalidad (STL)
Descompone la serie en tres partes: **tendencia** (dirección general a largo plazo), **estacionalidad** (patrón cíclico que se repite semanalmente) y **residuo** (variación aleatoria restante).

### ARIMA
Modelo estadístico que aprende los patrones de dependencia temporal de la serie y genera predicciones para los próximos 7 días con intervalos de confianza. `auto.arima()` selecciona automáticamente los mejores parámetros.

---

## Ejecución

```r
# 1. Instalar dependencias (solo la primera vez)
Rscript install_packages.R

# 2. Ejecutar el proyecto completo
Rscript main.R
```

Los resultados se guardan en:
- `outputs/graficas/` — todas las gráficas en PNG
- `outputs/mapa/` — mapa interactivo en HTML
- `data/processed/` — dataset limpio en CSV

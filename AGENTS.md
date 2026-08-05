# AGENTS.md — DM2026B

## Resumen

Proyecto para **Data Mining 2026B** (ITBA). El objetivo es predecir bajas de clientes (`BAJA+2`) usando árboles de decisión (`rpart` en R). La Tarea Hogar 02 consiste en hacer **Grid Search** sobre los 4 hiperparámetros de `rpart` para encontrar combinaciones que maximicen la ganancia económica.

- **Dataset**: `datasets/dataset_pequeno.csv` (~160 MB, NO trackeado en git)
- **Competencia Kaggle**: "Data Mining, Inicial 2026 B"
- **Semilla primigenia**: `401987`
- **Métrica**: Ganancia = `+975000` por acierto, `-25000` por error, umbral de estímulo `prob > 1/40` (0.025). Se normaliza al 100% del dataset.

---

## Dataset

- `datasets/dataset_pequeno.csv` — un solo mes histórico (`foto_mes == 202107`) con `clase_ternaria` (BAJA+1, BAJA+2, CONTINUA), y mes futuro (`foto_mes == 202109`) sin clase para predecir.
- Los meses intermedios (202108) no están en el dataset pequeño.
- Columnas: `numero_de_cliente`, `foto_mes`, `clase_ternaria`, y ~150 features numéricas/categóricas.

---

## Estructura del proyecto

```
dm2026b/
├── datasets/                          # NO trackeado (gitignored)
│   └── dataset_pequeno.csv
├── exp/                               # Output de experimentos (gitignored)
│   ├── HT2900/                        # Resultados del grid search
│   │   ├── gridsearch_detalle.txt     # Resultado detallado (TSV: semilla,cp,maxdepth,minsplit,minbucket,ganancia_test)
│   │   ├── gridsearch_detalle_v2.txt  # Experimentos con cp=-1 y minbucket como fracción
│   │   ├── gridsearch.txt             # Resumen agrupado (TSV: cp,maxdepth,minsplit,minbucket,ganancia_mean,ganancia_sd,N,id)
│   │   ├── gridsearch_v2.txt          # Resumen v2
│   │   ├── gridsearch_cp_positivo.txt # Experimento cp >= 0 vs cp = -1
│   │   └── gridsearch_fine.txt        # Sintonía fina alrededor de maxdepth=7-9, minsplit=450-600
│   └── KA2001/                        # CSVs de submit a Kaggle (gitignored, *.csv)
└── src/
    └── arboles/
        ├── z101_PrimerModelo.R        # Script inicial: entrena un árbol simple en RStudio
        ├── z102_FinalTrain.ipynb      # Notebook: entrenamiento final + submit a Kaggle
        ├── z201_ComparandoModelos.ipynb  # Notebook: comparación de modelos
        ├── z290_TareaHogar_02.ipynb   # ⭐ Notebook PRINCIPAL para Colab (grid search completo)
        ├── z290_TareaHogar_02_ORIGINAL.ipynb  # Backup del esqueleto original (para diff)
        └── z290_gridsearch_local.R    # ⭐ Script LOCAL para iterar rápido en Mac
```

---

## Consigna (Tarea Hogar 02)

1. **Grid Search**: Recorrer combinaciones de los 4 hiperparámetros de `rpart` (`cp`, `maxdepth`, `minsplit`, `minbucket`) y registrar la ganancia de cada combinación.
2. **Análisis**: Identificar qué regiones del espacio de búsqueda son buenas/malas, si algún hiperparámetro es sistemáticamente malo, y qué combinaciones hubiera convenido saltearse.
3. **Submit**: Del ranking ordenado por `ganancia_mean`, tomar posiciones **1, 2, 5, 10, 50, 100** y generar un submit a Kaggle por cada una con `z102_FinalTrain.ipynb`.
4. **Planilla**: Cargar los 6 resultados en la planilla colaborativa (hoja `C3-GridSearch`).
5. **Zulip**: Discutir hallazgos en `#Tarea Hogar 02`, topic `Analisis Grid Search`.

---

## Flujo de trabajo

**Intención clave**: iterar barato en la Mac local y solo cuando estemos conformes con los resultados, reflejar el código al notebook para la corrida final en Colab. El script local y el notebook deben mantenerse **sincronizados en lógica**: misma grilla, mismas funciones, mismo formato de salida. Solo cambia el storage path y el runtime.

### 1. Iteración local

Experimentar con `z290_gridsearch_local.R` en la Mac:

```bash
# Debug (24 segundos, 20000 filas, grilla mínima)
GS_DEBUG=TRUE Rscript src/arboles/z290_gridsearch_local.R

# Quick (~10 min, grilla enfocada)
GS_QUICK=TRUE Rscript src/arboles/z290_gridsearch_local.R

# Completo (~1-3 horas, ~300 combinaciones)
Rscript src/arboles/z290_gridsearch_local.R
```

Los resultados se guardan en `exp/HT2900/`. Se puede analizar localmente si la grilla dio buen resultado.

### 2. Reflejar al notebook

Cuando la grilla está afinada, **copiar los cambios al notebook** `z290_TareaHogar_02.ipynb`:
- Actualizar `cp_values`, `maxdepth_values`, `minsplit_values`, `minbucket_values` en la celda de definición de grilla.
- Si se hicieron cambios en las funciones (`particionar`, `ArbolEstimarGanancia`, etc.), reflejarlos también.
- **No cambiar** los paths (el notebook usa `/content/buckets/b1/exp/` para Google Drive en Colab).

### 3. Corrida final en Colab

Abrir `z290_TareaHogar_02.ipynb` en Google Colab, ejecutar todas las celdas. Los resultados se persisten en Google Drive (`/content/buckets/b1/exp/HT2900/`).

### Generar submits

Usar `z102_FinalTrain.ipynb` en Colab para entrenar sobre todo 202107 con cada combinación de hiperparámetros y generar el CSV para Kaggle.

---

## Hiperparámetros de `rpart`

| Parámetro | Significado | Valores testeados |
|---|---|---|
| `cp` | Complexity parameter — umbral mínimo de mejora para hacer un split. **Negativo** = sin límite, el árbol crece hasta las otras restricciones. Positivo = poda. | `-1`, `-0.5`, `-0.3`, `-0.1`, `0`, `0.0001`, `0.001`, `0.01` |
| `maxdepth` | Profundidad máxima del árbol | `4`–`14` |
| `minsplit` | Mínimo de registros en un nodo para intentar un split | `20`–`1000` |
| `minbucket` | Mínimo de registros en una hoja terminal | `1`–`200` (debe ser `<= minsplit`) |

---

## Hallazgos clave hasta ahora

1. **`cp >= 0` aniquila la ganancia** → cuando `cp` es positivo, la ganancia es **cero** (el árbol no crece debido a la poda agresiva). `cp` **debe ser negativo** (`-1` o `-0.5` dan resultados similares).

2. **`cp = -1` es el estándar de la cátedra** — da resultados iguales o mejores que `cp = -0.5`.

3. **`minbucket` como fracción de `minsplit`** (tip del profesor): en lugar de valores fijos, usar `minbucket = ceiling(minsplit / frac)` con `frac = 2, 3, 4, 5`.

4. **`maxdepth` 6–9 rinde mejor que 12+** — árboles demasiado profundos sobreajustan.

5. **`minsplit` 100–300 rinde mejor que 20–50** — grupos muy chicos introducen ruido.

6. **Mejor combinación encontrada hasta ahora**: `cp=-0.5, maxdepth=8, minsplit=200, minbucket=1` → ganancia ~461M (en el subset `gridsearch.txt`). Experimentos con `cp=-1` y mayor `minsplit` muestran ganancias aún mayores (~520M).

7. **El análisis de impacto marginal** (celda agregada al notebook) muestra la ganancia promedio para cada valor de cada hiperparámetro por separado, útil para identificar valores sistemáticamente malos.

---

## Convenciones

- **Semilla primigenia**: `401987`
- **Partición**: 70% train / 30% test, estratificada por `clase_ternaria`
- **Ganancia normalizada**: `ganancia_test / 0.30` (se escala como si fuera el dataset completo)
- **Umbral de estímulo**: `prob(BAJA+2) > 0.025` (equivalente a `1/40`)
- **Archivos TSV**: `fwrite(..., sep = "\t")` con columnas `semilla, cp, maxdepth, minsplit, minbucket, ganancia_test`
- **Checkpoint**: cada 50 iteraciones se persiste el archivo detalle (soporta resume si se interrumpe)

---

## Requisitos de R

```r
library(data.table)   # Manejo de datos
library(rpart)         # Árboles de decisión CART
library(parallel)     # Paralelización (mcmapply)
library(primes)       # Generación de números primos para semillas
```

---

## Notas para el agente

- **Minimalismo**: no crear archivos, código ni abstracciones de más. El proyecto se reduce a un script local + un notebook Colab. Cualquier propuesta de agregar archivos requiere justificación explícita.
- **Regla de oro**: todo cambio primero se prueba en `z290_gridsearch_local.R`. Cuando funciona, se refleja en `z290_TareaHogar_02.ipynb`. No hacer cambios directos en el notebook sin probar localmente primero.
- `datasets/` y `exp/` están en `.gitignore`, no commitear datasets ni outputs.
- El notebook de Colab usa paths `/content/buckets/b1/exp/` (Google Drive montado), el script local usa `~/Dev/dm2026b/exp/`. Misma estructura de archivos, distinto storage. Al copiar del script al notebook, mantener los paths de Colab intactos.
- `z290_TareaHogar_02_ORIGINAL.ipynb` es el esqueleto original de la cátedra — sirve para hacer diff de los cambios realizados.
- Para cambiar la grilla: modificar `cp_values`, `maxdepth_values`, `minsplit_values`, `minbucket_values` en el script local, correrlo, analizar resultados, y solo después reflejar los mismos valores en la celda correspondiente del notebook.
- El script local tiene 3 modos (DEBUG/QUICK/FULL) — el modo FULL es el que debe coincidir con lo que corre en el notebook de Colab.

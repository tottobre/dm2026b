# AGENTS.md — DM2026B

## Resumen

Proyecto para **Data Mining 2026B** (ITBA). Competencia Kaggle de predicción de bajas de clientes (`BAJA+2`). La Tarea Hogar 02 es un **Grid Search** sobre los 4 hiperparámetros de árboles de decisión `rpart` (CART) para maximizar ganancia económica.

- **Dataset**: `datasets/dataset_pequeno.csv` (~160 MB, NO trackeado)
- **Competencia Kaggle**: "Data Mining, Inicial 2026 B"
- **Alumno**: Tomas Ottobre
- **Semilla primigenia**: `401987`
- **5 semillas fijas**: `401987, 456791, 607219, 701819, 811147`
- **Métrica**: `+975000` por acierto, `-25000` por error, umbral `prob > 0.025` (1/40). Ganancia normalizada al 100%.

---

## Dataset

`datasets/dataset_pequeno.csv` — 164479 filas, 155 columnas.
- `foto_mes == 202107` → mes con `clase_ternaria` (BAJA+1, BAJA+2, CONTINUA). Se usa para entrenar y validar (partición 70/30).
- `foto_mes == 202109` → mes futuro sin clase, para predecir y submitir a Kaggle.
- No hay meses intermedios. Esto es clave: entre train y submit hay **data drifting** (los datos de septiempre no son idénticos a los de julio).

---

## Estructura del proyecto

```
dm2026b/
├── datasets/                          # NO trackeado
│   └── dataset_pequeno.csv
├── exp/                               # Output de experimentos (gitignored)
│   └── HT2900/                        # Resultados del grid search
│       ├── gridsearch_detalle.txt     # TSV: semilla,cp,maxdepth,minsplit,minbucket,ganancia_test
│       └── gridsearch.txt             # Ranking agrupado con media, sd, N
└── src/
    └── arboles/
        ├── z101_PrimerModelo.R        # Script inicial de la materia
        ├── z102_FinalTrain.ipynb      # Entrenamiento final + submit a Kaggle
        ├── z201_ComparandoModelos.ipynb  # Monte Carlo Cross Validation + Wilcoxon
        ├── z290_TareaHogar_02.ipynb   # ⭐ Notebook PRINCIPAL para Colab
        ├── z290_TareaHogar_02_ORIGINAL.ipynb  # Esqueleto original (para diff)
        └── z290_gridsearch_local.R    # ⭐ Script LOCAL para iterar en Mac
    ├── ensambles/                     # NUEVOS (merge catedra 06/08)
    │   ├── z420_ArbolesAzarosos.ipynb
    │   ├── z440_RandomForest.ipynb
    │   ├── z470_GBDT_LightGBM.ipynb
    │   └── z494_TareaHogar_04.ipynb
```

---

## Git / GitHub — Cómo funciona

### Conceptos básicos

- **Git**: programa en tu Mac que registra cambios (como historial de Google Docs pero manual, con `git commit`).
- **GitHub**: sitio web donde se sube el código (backup online + compartir).
- **Repositorio (repo)**: la carpeta del proyecto. El tuyo es `dm2026b`.
- **Fork**: tu copia personal del repo del profesor. El original es `itba-ecd/dm2026b`, tu fork es `tottobre/dm2026b`.
- **Rama (branch)**: línea de tiempo independiente. Tu repo tiene dos:
  - `main` → donde trabajás vos (tus tareas, tu código)
  - `catedra` → material que sube el profesor (no se toca, solo se mergea)

### Flujo de trabajo con GitHub

```
1. Cambiás archivos en la Mac (con Pi)
2. git add -A                          # preparás todo
3. git commit -m "mensaje"             # guardás localmente
4. git push                            # subís a GitHub
```

### Sync con el repo del profesor

El profe sube material nuevo a su rama `catedra`. GitHub automáticamente lo copia a tu fork. Para traerlo a tu Mac:

```bash
git merge origin/catedra   # junta lo del profe con tu main
git push                   # sube el resultado a GitHub
```

### Colab

Colab es una compu de Google en la nube. Abre notebooks directamente desde GitHub. Corre con runtime R. Los archivos se guardan en Google Drive (`/content/buckets/b1/exp/`), no en tu Mac. Para no tener conflictos: **editar el notebook solo en un lado a la vez**.

---

## Consigna (Tarea Hogar 02)

1. **Grid Search**: Recorrer combinaciones de 4 hiperparámetros de `rpart` (`cp`, `maxdepth`, `minsplit`, `minbucket`) y medir ganancia.
2. **Análisis**: ¿Qué regiones son buenas/malas? ¿Hay hiperparámetros que siempre dan mal?
3. **Submit**: Del ranking, tomar posiciones **1, 2, 5, 10, 50, 100**. Con `z102_FinalTrain.ipynb` generar submit a Kaggle de cada una.
4. **Planilla**: Cargar los 6 resultados en hoja `C3-GridSearch`.
5. **Zulip**: Discutir en `#Tarea Hogar 02`, topic `Analisis Grid Search`.

---

## Flujo de trabajo

**Regla de oro**: probar todo en `z290_gridsearch_local.R` (Mac, rápido). Cuando funciona, reflejar en `z290_TareaHogar_02.ipynb` (Colab). No al revés.

### Script local

```bash
# Validación (30 seg)
GS_DEBUG=TRUE Rscript src/arboles/z290_gridsearch_local.R

# Exploración rápida (~10 min)
GS_QUICK=TRUE Rscript src/arboles/z290_gridsearch_local.R

# Completo con 5 semillas (~25-40 min según grilla)
Rscript src/arboles/z290_gridsearch_local.R

# Solo 1 semilla (~12 min)
GS_SEMILLAS=1 Rscript src/arboles/z290_gridsearch_local.R
```

### Resultados

Se guardan en `exp/HT2900/`:
- `gridsearch_detalle.txt` — TSV con cada corrida (semilla × combinación)
- `gridsearch.txt` — ranking agrupado con `ganancia_mean`, `ganancia_sd`, `N`

El script soporta **resume**: si se interrumpe, al correr de nuevo saltea combinaciones ya procesadas (usa hash table por clave `cp_maxdepth_minsplit_minbucket`). Checkpoint cada 50 iteraciones.

---

## Resultados del Grid Search

### Estrategia en 2 fases

**Fase 1 — Barrido eficiente** (40 combos, 5 semillas, 25 min):

```
cp = -1
maxdepth = 5, 7, 8, 9
minsplit = 600, 500, 400, 300, 200
minbucket = ceiling(minsplit / 4), ceiling(minsplit / 5)
```

Top: maxdepth=7-8, minsplit=400-500, minbucket≈100, ~503M.

**Fase 2 — Zoom fino** (72 combos, 5 semillas, 41 min):

```
cp = -1
maxdepth = 7, 8
minsplit = 550, 525, 500, 475, 450, 425, 400, 375, 350
fracciones = 3.5, 4, 4.5, 5
```

### Mejor resultado final

| # | cp | maxdepth | minsplit | minbucket | Ganancia ± sd |
|---|---|---|---|---|---|
| 1 | -1 | 8 | 450 | 100 (=450/4.5) | **502.2M** ± 29M |
| 2 | -1 | 7 | 375 | 108 (=375/3.5) | 500.5M ± 22M |
| 3 | -1 | 7 | 450 | 113 (=450/4) | 500.2M ± 23M |

**Techo real de `rpart` en este dataset: ~502M.** Resultados anteriores de 520M estaban inflados por usar 1 sola semilla.

---

## Hallazgos clave

### Hiperparámetros

| Hallazgo | Detalle |
|---|---|
| `cp >= 0` → **ganancia 0** | El árbol no crece. Usar solo `cp = -1`. |
| `cp = -1` vs `-0.5` | No hay diferencia real. Alcanza con `cp = -1`. |
| `maxdepth` óptimo: **7-8** | 5 es competitivo. 10+ degrada. |
| `minsplit` óptimo: **400-500** | <100 degrada fuerte. >600 también cae. |
| `minbucket` como **fracción** de `minsplit` | `/4`, `/4.5`, `/5` son las mejores. `/2` y `/3` son peores. |

### Por qué más semillas importan

1 semilla = una sola partición 70/30. Puede favorecer a una combinación por azar.
5 semillas = 5 particiones distintas, se promedia. El ranking es más robusto y se correlaciona mejor con Kaggle.

### Data Drifting y Overfitting

El grid search mide ganancia en **julio 2021**. Kaggle mide en **septiembre 2021**. No son lo mismo:

- **Overfitting**: el árbol se memoriza julio, falla en septiembre.
- **Data drifting**: los clientes cambiaron entre meses. Lo que funcionaba en julio ya no funciona igual.

Por eso a veces el puesto 50 del ranking le gana al puesto 1 en Kaggle. El profesor armó la tarea para que se vea esto.

---

## z201_ComparandoModelos.ipynb

Notebook de la Clase 02. Progresión de experimentos:

| Exp | Qué hace | Concepto |
|---|---|---|
| 1 | Una partición 70/30 | Muy variable, no confiable |
| 2 | 5 semillas (Monte Carlo) | Más estable |
| 4 | 50 semillas | La media se estabiliza (Teorema Central del Límite) |
| 6 | Comparar dos modelos (bueno vs malo) | Probabilidad de que uno gane |
| 7 | Comparar dos modelos BUENOS | Difícil distinguirlos, se necesitan más semillas |
| 8 | **Test de Wilcoxon** | `wilcox.test(g1, g2, paired=TRUE)` → p-value |
| 9 | **Wilcoxon automático** | Agrega semillas hasta p-value < 0.05 o llega a 50 |

### Test de Wilcoxon

Compara dos modelos **semilla por semilla** (misma partición, ¿quién ganó?).

- **p-value < 0.05** → uno es genuinamente mejor.
- **p-value > 0.05** → no hay evidencia suficiente, pueden ser iguales.

**Nuestro resultado** (experimento 9, con semilla 401987):
- 26 iteraciones, p-value = 0.038, Arbol 1 mejor (478M vs 472M).

---

## Requisitos de R

```r
library(data.table)   # Manejo de datos
library(rpart)         # Árboles de decisión CART
library(parallel)     # Paralelización (mcmapply, 4 cores en Mac)
```

Ya no se usa `primes` (las semillas son fijas).

---

## Notas para el agente

- **Minimalismo**: no crear archivos ni código de más. Solo script local + notebook Colab.
- **Regla de oro**: probar en `z290_gridsearch_local.R` → luego reflejar en `z290_TareaHogar_02.ipynb`.
- `datasets/` y `exp/` están en `.gitignore`.
- El notebook usa paths de Colab (`/content/buckets/b1/exp/`), el script local usa `~/Dev/dm2026b/exp/`. Al reflejar cambios, **no sobreescribir los paths**.
- `z290_TareaHogar_02_ORIGINAL.ipynb` es backup para diff.
- Las 5 semillas fijas son: `401987, 456791, 607219, 701819, 811147`. Control con `GS_SEMILLAS=N`.
- Para traer material nuevo del profe: `git merge origin/catedra && git push`.
- Colab abre notebooks desde GitHub. El runtime es R. Los datos se persisten en Google Drive.

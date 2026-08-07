#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════════════════
# z290_gridsearch_local.R
# Grid Search en tu Mac — SIN depender de Google Colab
# ═══════════════════════════════════════════════════════════════════════════════
#
# 🎯 OBJETIVO: Encontrar combinaciones de 4 hiperparámetros de rpart que
#    maximicen la ganancia al predecir BAJA+2 de clientes.
#
# 🚀 CÓMO CORRERLO:
#    GS_DEBUG=TRUE  Rscript src/arboles/z290_gridsearch_local.R   → ~30 seg
#    GS_QUICK=TRUE  Rscript src/arboles/z290_gridsearch_local.R   → ~10 min
#                   Rscript src/arboles/z290_gridsearch_local.R   → ~1 hr (5 sem)
#    GS_SEMILLAS=1  Rscript src/arboles/z290_gridsearch_local.R   → ~12 min (1 sem)
#
# 🧠 ESTRATEGIA:
#    Fase 1 (barrido): 5 semillas, 40 combos eficientes → ranking robusto
#    Fase 2 (zoom): zoom fino alrededor del top 5, 5 semillas → máx ganancia
#
# ═══════════════════════════════════════════════════════════════════════════════

# ── CONFIGURACIÓN ─────────────────────────────────────────────────────────────
DEBUG_MODE    <- Sys.getenv("GS_DEBUG", unset = "FALSE") == "TRUE"
QUICK_TEST    <- Sys.getenv("GS_QUICK", unset = "FALSE") == "TRUE"
QSEMILLAS     <- as.integer(Sys.getenv("GS_SEMILLAS", unset = "5"))
MIS_SEMILLAS  <- c(401987, 456791, 607219, 701819, 811147)  # 5 semillas fijas
TRAINING_PCT  <- 70L
DATASET_FILE  <- "~/Dev/dm2026b/datasets/dataset_pequeno.csv"
EXPERIMENTO   <- "HT2900"
EXP_DIR       <- "~/Dev/dm2026b/exp"
CHECKPOINT_N  <- 50
SAMPLE_N      <- 20000
CORES         <- max(1, min(4, parallel::detectCores() - 2))

cat("\n")
cat("======================================================\n")
cat("  Grid Search LOCAL\n")
cat("  DEBUG:", DEBUG_MODE, " | QUICK:", QUICK_TEST, "\n")
cat("  Semillas a usar:", QSEMILLAS, "\n")
cat("  Cores a usar:", CORES, "\n")
cat("======================================================\n\n")

# ── Librerías ─────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(data.table)
  library(rpart)
  library(parallel)
})

# ── Funciones ─────────────────────────────────────────────────────────────────

# Parte el dataset en 70% entrenamiento / 30% prueba
particionar <- function(data, division, agrupa = "", campo = "fold",
                        start = 1, seed = NA) {
  if (!is.na(seed)) set.seed(seed)
  bloque <- unlist(mapply(function(x, y) rep(y, x),
    division,
    seq(from = start, length.out = length(division))
  ))
  data[, (campo) := sample(rep(bloque, ceiling(.N / length(bloque))))[1:.N],
    by = agrupa]
}

# Entrena UN árbol y calcula SU ganancia
ArbolEstimarGanancia <- function(semilla, training_pct, param_basicos) {

  # 1. Partir 70/30
  particionar(dataset,
    division = c(training_pct, 100L - training_pct),
    agrupa = "clase_ternaria",
    seed = semilla
  )

  # 2. Construir árbol con el 70%
  modelo <- rpart("clase_ternaria ~ .",
    data = dataset[fold == 1],
    xval = 0,
    control = param_basicos
  )

  # 3. Predecir con el 30%
  prediccion <- predict(modelo, dataset[fold == 2], type = "prob")

  # 4. Calcular ganancia: +975000 por acierto, -25000 por error
  ganancia_test <- dataset[
    fold == 2,
    sum(ifelse(prediccion[, "BAJA+2"] > 0.025,
      ifelse(clase_ternaria == "BAJA+2", 975000, -25000),
      0
    ))
  ]

  ganancia_test_normalizada <- ganancia_test / ((100 - TRAINING_PCT) / 100)

  return(c(
    list("semilla" = semilla),
    param_basicos,
    list("ganancia_test" = ganancia_test_normalizada)
  ))
}

# Llama a ArbolEstimarGanancia en paralelo
ArbolesMontecarlo <- function(semillas, param_basicos) {
  salida <- mcmapply(ArbolEstimarGanancia,
    semillas,
    MoreArgs = list(TRAINING_PCT, param_basicos),
    SIMPLIFY = FALSE,
    mc.cores = CORES
  )
  return(salida)
}

# Clave única: "cp_maxdepth_minsplit_minbucket"
combinacion_key <- function(cp, maxdepth, minsplit, minbucket) {
  paste(cp, maxdepth, minsplit, minbucket, sep = "_")
}

# ── Cargar dataset ────────────────────────────────────────────────────────────
dataset <- fread(DATASET_FILE)
dataset <- dataset[clase_ternaria != ""]

if (DEBUG_MODE) {
  set.seed(MIS_SEMILLAS[1])
  dataset <- dataset[sample(.N, min(SAMPLE_N, .N))]
  cat("DEBUG: dataset reducido a", nrow(dataset), "filas\n")
}
cat("Dataset:", nrow(dataset), "filas,", ncol(dataset), "columnas\n")

# ── Semillas ──────────────────────────────────────────────────────────────────
if (QSEMILLAS <= length(MIS_SEMILLAS)) {
  semillas <- MIS_SEMILLAS[1:QSEMILLAS]
} else {
  semillas <- MIS_SEMILLAS
  warning("QSEMILLAS > 5, usando solo las 5 semillas fijas")
}
cat("Semillas:", paste(semillas, collapse = ", "), "\n")

# ── Grilla de valores a probar ────────────────────────────────────────────────
# minbucket se calcula como FRACCIÓN de minsplit (validado por el profe)
# Fracciones: /3, /4, /5  (las mejores; /2 es peor)
# Solo cp = -1 (cp >= 0 da ganancia 0 siempre, y -1 vs -0.5 no difiere)

if (DEBUG_MODE) {
  cp_values       <- c(-1)
  maxdepth_values <- c(5, 8)
  minsplit_values <- c(500, 200)
  fracciones      <- c(3, 5)
  cat("MODO DEBUG: validación rápida\n")
} else if (QUICK_TEST) {
  # Fase 1 reducida: solo combinaciones más prometedoras
  cp_values       <- c(-1)
  maxdepth_values <- c(5, 7, 8, 9)
  minsplit_values <- c(700, 500, 300, 200)
  fracciones      <- c(3, 4, 5)
  cat("MODO RÁPIDO: región prometedora\n")
} else {
  # Fase 2: zoom fino al top de la fase 1 (~72 combos)
  cp_values       <- c(-1)
  maxdepth_values <- c(7, 8)
  minsplit_values <- c(550, 525, 500, 475, 450, 425, 400, 375, 350)
  fracciones      <- c(3.5, 4, 4.5, 5)
  cat("MODO COMPLETO: zoom fino\n")
}

# Contar combinaciones válidas (minbucket >= 1 y < minsplit)
total_validas <- 0
for (cp in cp_values) {
  for (md in maxdepth_values) {
    for (ms in minsplit_values) {
      for (frac in fracciones) {
        mb <- ceiling(ms / frac)
        if (mb >= 1 && mb < ms) total_validas <- total_validas + 1
      }
    }
  }
}
cat("Combinaciones a probar:", total_validas, "\n")
cat("Modelos a entrenar:", total_validas * QSEMILLAS, "\n\n")

# ── Setup carpeta ─────────────────────────────────────────────────────────────
dir.create(EXP_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(EXP_DIR, EXPERIMENTO), showWarnings = FALSE)
setwd(file.path(EXP_DIR, EXPERIMENTO))
cat("Resultados en:", getwd(), "\n\n")

# ── Cargar/crear tabla de resultados ──────────────────────────────────────────
DETALLE_FILE <- "gridsearch_detalle.txt"

if (file.exists(DETALLE_FILE)) {
  tb <- fread(DETALLE_FILE)
  cat("Archivo existente:", nrow(tb), "registros (RESUME activado)\n")
  claves_procesadas <- new.env(hash = TRUE, parent = emptyenv())
  for (i in 1:nrow(tb)) {
    key <- combinacion_key(tb[i, cp], tb[i, maxdepth],
      tb[i, minsplit], tb[i, minbucket])
    claves_procesadas[[key]] <- TRUE
  }
} else {
  tb <- data.table(
    semilla = integer(), cp = numeric(), maxdepth = integer(),
    minsplit = integer(), minbucket = integer(), ganancia_test = numeric()
  )
  claves_procesadas <- new.env(hash = TRUE, parent = emptyenv())
  cat("Archivo nuevo — empezando de cero\n")
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                  EL LOOP PRINCIPAL — GRID SEARCH                             ║
# ║  Para cada combinación de las 4 perillas:                                   ║
# ║    1. Construye un árbol                                                    ║
# ║    2. Mide cuánta plata genera                                               ║
# ║    3. Guarda el resultado                                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resultados_buffer <- list()
iter_procesadas  <- 0L
iter_salteadas   <- 0L
t_inicio <- Sys.time()

for (vcp in cp_values) {
  for (vmd in maxdepth_values) {
    for (vms in minsplit_values) {
      for (frac in fracciones) {
        vmb <- ceiling(vms / frac)
        if (vmb < 1 || vmb >= vms) next  # minbucket debe ser >=1 y < minsplit

        key <- combinacion_key(vcp, vmd, vms, vmb)
        if (!is.null(claves_procesadas[[key]])) {
          iter_salteadas <- iter_salteadas + 1L
          next
        }

        iter_procesadas <- iter_procesadas + 1L

        # Progreso cada 10 iteraciones
        if (iter_procesadas %% 10 == 0 || iter_procesadas == 1) {
          t_trans <- as.numeric(difftime(Sys.time(), t_inicio, units = "secs"))
          seg_iter <- t_trans / iter_procesadas
          restantes <- total_validas - iter_procesadas - iter_salteadas
          eta_min <- round(seg_iter * max(restantes, 0) / 60, 1)
          cat(sprintf("[%4d/%4d] ETA: %5.1f min | cp=%.2f md=%d ms=%d frac=1/%.1f mb=%d\n",
            iter_procesadas, total_validas, eta_min, vcp, vmd, vms, frac, vmb))
          flush.console()
        }

        param_basicos <- list(
          "cp" = vcp, "maxdepth" = vmd,
          "minsplit" = vms, "minbucket" = vmb
        )

        ganancias <- ArbolesMontecarlo(semillas, param_basicos)
        resultados_buffer[[length(resultados_buffer) + 1]] <- rbindlist(ganancias)

        # Checkpoint
        if (iter_procesadas %% CHECKPOINT_N == 0) {
          tb_nuevos <- rbindlist(resultados_buffer)
          tb <- rbindlist(list(tb, tb_nuevos), use.names = TRUE)
          fwrite(tb, file = DETALLE_FILE, sep = "\t")
          for (i in 1:nrow(tb_nuevos)) {
            key <- combinacion_key(tb_nuevos[i, cp], tb_nuevos[i, maxdepth],
              tb_nuevos[i, minsplit], tb_nuevos[i, minbucket])
            claves_procesadas[[key]] <- TRUE
          }
          resultados_buffer <- list()
          cat(sprintf("  [CHECKPOINT] %d registros\n", nrow(tb)))
        }
      }
    }
  }
}

# Guardar lo que quedó en el buffer
if (length(resultados_buffer) > 0) {
  tb_nuevos <- rbindlist(resultados_buffer)
  tb <- rbindlist(list(tb, tb_nuevos), use.names = TRUE)
  for (i in 1:nrow(tb_nuevos)) {
    key <- combinacion_key(tb_nuevos[i, cp], tb_nuevos[i, maxdepth],
      tb_nuevos[i, minsplit], tb_nuevos[i, minbucket])
    claves_procesadas[[key]] <- TRUE
  }
}
fwrite(tb, file = DETALLE_FILE, sep = "\t")

# ── Resultados ─────────────────────────────────────────────────────────────────
t_total <- difftime(Sys.time(), t_inicio, units = "mins")
cat("\n========================================\n")
cat("LISTO\n")
cat(sprintf("  Procesadas: %d | Salteadas: %d\n", iter_procesadas, iter_salteadas))
cat(sprintf("  Tiempo: %.1f min (%.1f seg/combinacion)\n",
  as.numeric(t_total), as.numeric(t_total) * 60 / max(iter_procesadas, 1)))
cat("========================================\n\n")

# Ranking top 10
tb_resumen <- tb[, .(
  ganancia_mean = mean(ganancia_test),
  ganancia_sd = sd(ganancia_test),
  .N
), by = list(cp, maxdepth, minsplit, minbucket)]

setorder(tb_resumen, -ganancia_mean)
cat("--- TOP 10 MEJORES COMBINACIONES ---\n")
print(tb_resumen[1:10], digits = 2)

# Impacto de cada perilla por separado
cat("\n--- IMPACTO DE CADA PERILLA ---\n")
for (param in c("cp", "maxdepth", "minsplit", "minbucket")) {
  cat(sprintf("\n%s:\n", param))
  print(tb_resumen[, .(ganancia_media = mean(ganancia_mean), .N),
    by = param][order(-ganancia_media)])
}

# Guardar resumen
tb_resumen[, id := .I]
fwrite(tb_resumen, file = "gridsearch.txt", sep = "\t")
cat(sprintf("\nResumen guardado: %s/gridsearch.txt\n", getwd()))

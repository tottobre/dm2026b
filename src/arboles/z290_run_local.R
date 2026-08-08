#!/usr/bin/env Rscript
# z290_run_local.R — Ejecuta la misma grilla que el notebook localmente
# Generado desde z290_TareaHogar_02.ipynb
# 256 combos × 5 semillas = 1,280 árboles

suppressPackageStartupMessages({
  library(data.table)
  library(rpart)
  library(parallel)
})

# ── CONFIG ─────────────────────────────────────────────────────────────────────
MIS_SEMILLAS  <- c(401987, 456791, 607219, 701819, 811147)
QSEMILLAS     <- length(MIS_SEMILLAS)
TRAINING_PCT  <- 70L
DATASET_FILE  <- "~/Dev/dm2026b/datasets/dataset_pequeno.csv"
EXP_DIR       <- "~/Dev/dm2026b/exp/HT2900"
CORES         <- max(1, detectCores() - 2)  # deja 2 cores libres

cat(sprintf("Grid Search Local | %d cores | %d semillas\n\n", CORES, QSEMILLAS))

# ── Funciones ──────────────────────────────────────────────────────────────────

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

ArbolEstimarGanancia <- function(semilla, training_pct, param_basicos) {
  particionar(dataset,
    division = c(training_pct, 100L - training_pct),
    agrupa = "clase_ternaria",
    seed = semilla
  )
  modelo <- rpart("clase_ternaria ~ .",
    data = dataset[fold == 1],
    xval = 0,
    control = param_basicos
  )
  prediccion <- predict(modelo, dataset[fold == 2], type = "prob")
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

ArbolesMontecarlo <- function(semillas, param_basicos) {
  salida <- mcmapply(ArbolEstimarGanancia,
    semillas,
    MoreArgs = list(TRAINING_PCT, param_basicos),
    SIMPLIFY = FALSE,
    mc.cores = CORES
  )
  return(salida)
}

# ── Dataset ────────────────────────────────────────────────────────────────────
dataset <- fread(DATASET_FILE)
dataset <- dataset[clase_ternaria != ""]
cat(sprintf("Dataset: %d filas, %d columnas\n", nrow(dataset), ncol(dataset)))

# ── Semillas ───────────────────────────────────────────────────────────────────
semillas <- MIS_SEMILLAS[1:QSEMILLAS]
cat(sprintf("Semillas: %s\n\n", paste(semillas, collapse = ", ")))

# ── Grilla del notebook ────────────────────────────────────────────────────────
# Misma grilla que z290_TareaHogar_02.ipynb
# cp=-1 óptimo, cp=-0.5 competitivo
# maxdepth 7-8 óptimo, 6-9 margen
# minsplit 375-500 óptimo, 250-600 barrido
# minbucket = ceiling(minsplit / fraccion)  ← estrategia del profe

cp_values       <- c(-1, -0.5)
maxdepth_values <- c(6, 7, 8, 9)
minsplit_values <- c(250, 300, 350, 400, 450, 500, 550, 600)
fracciones      <- c(3.5, 4, 4.5, 5)

total_validas <- 0
for (cp in cp_values)
  for (md in maxdepth_values)
    for (ms in minsplit_values)
      for (frac in fracciones) {
        mb <- ceiling(ms / frac)
        if (mb >= 1 && mb < ms) total_validas <- total_validas + 1
      }

cat(sprintf("Grilla: %d combos × %d semillas = %d árboles\n\n",
  total_validas, QSEMILLAS, total_validas * QSEMILLAS))

# ── Setup ──────────────────────────────────────────────────────────────────────
dir.create(EXP_DIR, showWarnings = FALSE, recursive = TRUE)
setwd(EXP_DIR)
DETALLE_FILE <- "gridsearch_detalle.txt"

# Resume
if (file.exists(DETALLE_FILE)) {
  tb <- fread(DETALLE_FILE)
  cat(sprintf("RESUME: %d registros existentes\n", nrow(tb)))
  claves <- new.env(hash = TRUE, parent = emptyenv())
  for (i in 1:nrow(tb)) {
    key <- paste(tb[i, cp], tb[i, maxdepth], tb[i, minsplit], tb[i, minbucket], sep = "_")
    claves[[key]] <- TRUE
  }
} else {
  tb <- data.table(
    semilla = integer(), cp = numeric(), maxdepth = integer(),
    minsplit = integer(), minbucket = integer(), ganancia_test = numeric()
  )
  claves <- new.env(hash = TRUE, parent = emptyenv())
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         GRID SEARCH LOOP                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

buffer <- list()
iter_done <- 0L
iter_skip <- 0L
t0 <- Sys.time()

for (vcp in cp_values) {
  for (vmd in maxdepth_values) {
    for (vms in minsplit_values) {
      for (frac in fracciones) {
        vmb <- ceiling(vms / frac)
        if (vmb < 1 || vmb >= vms) next

        key <- paste(vcp, vmd, vms, vmb, sep = "_")
        if (!is.null(claves[[key]])) {
          iter_skip <- iter_skip + 1L
          next
        }

        iter_done <- iter_done + 1L

        if (iter_done %% 5 == 0 || iter_done == 1) {
          t_elap <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
          eta <- round(t_elap / iter_done * (total_validas - iter_done - iter_skip) / 60, 1)
          cat(sprintf("[%3d/%3d] ETA:%5.1f min | cp=%.1f md=%d ms=%d frac=1/%.1f mb=%d\n",
            iter_done, total_validas, eta, vcp, vmd, vms, frac, vmb))
        }

        param_basicos <- list(
          "cp" = vcp, "maxdepth" = vmd,
          "minsplit" = vms, "minbucket" = vmb
        )

        ganancias <- ArbolesMontecarlo(semillas, param_basicos)
        buffer[[length(buffer) + 1]] <- rbindlist(ganancias)

        # Checkpoint cada 25 iteraciones
        if (iter_done %% 25 == 0) {
          tb_nuevo <- rbindlist(buffer)
          tb <- rbindlist(list(tb, tb_nuevo), use.names = TRUE)
          fwrite(tb, file = DETALLE_FILE, sep = "\t")
          for (i in 1:nrow(tb_nuevo))
            claves[[paste(tb_nuevo[i, cp], tb_nuevo[i, maxdepth],
              tb_nuevo[i, minsplit], tb_nuevo[i, minbucket], sep = "_")]] <- TRUE
          buffer <- list()
          cat(sprintf("  [CHECKPOINT] total: %d registros\n", nrow(tb)))
        }
      }
    }
  }
}

# Guardar buffer final
if (length(buffer) > 0) {
  tb_nuevo <- rbindlist(buffer)
  tb <- rbindlist(list(tb, tb_nuevo), use.names = TRUE)
  for (i in 1:nrow(tb_nuevo))
    claves[[paste(tb_nuevo[i, cp], tb_nuevo[i, maxdepth],
      tb_nuevo[i, minsplit], tb_nuevo[i, minbucket], sep = "_")]] <- TRUE
}
fwrite(tb, file = DETALLE_FILE, sep = "\t")

# ── Resultados ─────────────────────────────────────────────────────────────────
t_total <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
cat(sprintf("\nLISTO | %d combos | %d saltados | %.1f min\n\n",
  iter_done, iter_skip, t_total))

tb_resumen <- tb[, .(
  ganancia_mean = mean(ganancia_test),
  ganancia_sd   = sd(ganancia_test),
  .N
), by = list(cp, maxdepth, minsplit, minbucket)]

setorder(tb_resumen, -ganancia_mean)

cat("══════════ TOP 15 ══════════\n")
print(tb_resumen[1:15], digits = 2, topn = 15)

# Guardar resumen
tb_resumen[, id := .I]
fwrite(tb_resumen, file = "gridsearch.txt", sep = "\t")
cat(sprintf("\nResultados: %s/gridsearch.txt\n", EXP_DIR))

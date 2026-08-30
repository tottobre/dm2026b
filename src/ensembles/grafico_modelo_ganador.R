# grafico_modelo_ganador.R
# Curvas exactas del modelo récord (380.998) con Target puro BAJA+2 y parámetros óptimos

rm(list = ls(all.names = TRUE))
gc(full = TRUE, verbose = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(lightgbm)
})

dir_base <- "/Users/tomas/dev/dm2026b"
dataset <- fread(file.path(dir_base, "datasets/dataset_pequeno.csv"), stringsAsFactors = TRUE)

# TARGET PURO DEL MODELO GANADOR:
dataset[, clase01 := ifelse(clase_ternaria == "BAJA+2", 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

julio <- dataset[foto_mes == 202107]
set.seed(401987, kind = "L'Ecuyer-CMRG")
julio[, azar := runif(.N)]

# 70% Train / 30% Validation
dtrain <- lgb.Dataset(
  data = data.matrix(julio[azar <= 0.70, campos_buenos, with = FALSE]),
  label = julio[azar <= 0.70, clase01],
  free_raw_data = FALSE
)

dval <- lgb.Dataset(
  data = data.matrix(julio[azar > 0.70, campos_buenos, with = FALSE]),
  label = julio[azar > 0.70, clase01],
  free_raw_data = FALSE
)

# PARÁMETROS EXACTOS DEL MODELO 380K
params_ganador <- list(
  objective = "binary",
  metric = "binary_logloss",
  boosting = "gbdt",
  max_bin = 31L,
  learning_rate = 0.018,
  num_leaves = 24,
  min_data_in_leaf = 50,
  feature_fraction = 0.65,
  bagging_fraction = 0.85,
  bagging_freq = 1L,
  lambda_l1 = 0.5,
  lambda_l2 = 5.0,
  seed = 401987,
  verbosity = -100
)

cat("Entrenando modelo récord a 1.000 iteraciones para evaluar curvas...\n")
modelo <- lgb.train(
  data = dtrain,
  valids = list(train = dtrain, val = dval),
  param = params_ganador,
  nrounds = 1000,
  verbose = -100
)

hist_train <- unlist(modelo$record_evals$train$binary_logloss$eval)
hist_val   <- unlist(modelo$record_evals$val$binary_logloss$eval)

archivo_png <- file.path(dir_base, "exp/curva_modelo_ganador.png")
png(archivo_png, width = 950, height = 550, res = 120)

y_min <- min(c(hist_train, hist_val))
y_max <- max(c(hist_train[1:50], hist_val[1:50]))

plot(hist_train, type = "l", col = "#1f77b4", lwd = 2,
     ylim = c(y_min * 0.95, y_max),
     xlab = "Cantidad de Árboles (Iteraciones)",
     ylab = "Pérdida (Binary LogLoss)",
     main = "Curva de Aprendizaje - Modelo Ganador (Target BAJA+2 Puro)")

lines(hist_val, col = "#d62728", lwd = 2)

# Punto óptimo en validación
min_idx <- which.min(hist_val)
points(min_idx, hist_val[min_idx], col = "#2ca02c", pch = 19, cex = 1.5)
text(min_idx, hist_val[min_idx], labels = paste("Mínimo Error:", min_idx, "árboles"), pos = 3, col = "#2ca02c", font = 2)

# Línea vertical en los 650 árboles usados
abline(v = 650, col = "darkorange", lty = 2, lwd = 2)
text(650, y_max * 0.9, labels = "Corte fijado (650)", pos = 4, col = "darkorange", font = 2)

legend("topright",
       legend = c("Train (Entrenamiento)", "Validation (Datos Nuevos)", "Mínimo Error Global", "Corte Elegido (650 árboles)"),
       col = c("#1f77b4", "#d62728", "#2ca02c", "darkorange"),
       lty = c(1, 1, NA, 2),
       pch = c(NA, NA, 19, NA),
       lwd = c(2, 2, NA, 2))

dev.off()
cat("Gráfico guardado en:", archivo_png, "\n")

# grafico_overfitting.R
# Genera el gráfico de curvas de aprendizaje (Train vs Validation) para detectar sobreajuste

rm(list = ls(all.names = TRUE))
gc(full = TRUE, verbose = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(lightgbm)
})

dir_base <- "/Users/tomas/dev/dm2026b"
dataset <- fread(file.path(dir_base, "datasets/dataset_pequeno.csv"), stringsAsFactors = TRUE)
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+1", "BAJA+2"), 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

julio <- dataset[foto_mes == 202107]
set.seed(401987, kind = "L'Ecuyer-CMRG")
julio[, azar := runif(.N)]

# Partición 70% Train / 30% Validation
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

# Parámetros a monitorear
params <- list(
  objective = "binary",
  metric = "binary_logloss",
  boosting = "gbdt",
  max_bin = 31L,
  learning_rate = 0.02,
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

cat("Entrenando 1.000 árboles y registrando evolución de Train vs Validation...\n")
modelo <- lgb.train(
  data = dtrain,
  valids = list(train = dtrain, val = dval),
  param = params,
  nrounds = 1000,
  verbose = -100
)

# Extraer métricas históricas convirtiendo a vector numérico
hist_train <- unlist(modelo$record_evals$train$binary_logloss$eval)
hist_val   <- unlist(modelo$record_evals$val$binary_logloss$eval)

# Guardar gráfico en PNG
dir_out <- file.path(dir_base, "exp")
dir.create(dir_out, showWarnings = FALSE)
archivo_png <- file.path(dir_out, "curva_overfitting.png")

png(archivo_png, width = 900, height = 600, res = 120)
y_min <- min(c(hist_train, hist_val))
y_max <- max(c(hist_train[1:50], hist_val[1:50]))

plot(hist_train, type = "l", col = "blue", lwd = 2,
     ylim = c(y_min * 0.95, y_max),
     xlab = "Cantidad de Árboles (Iteraciones)",
     ylab = "Pérdida Logarítmica (LogLoss)",
     main = "Detección de Overfitting: Train vs. Validación")

lines(hist_val, col = "red", lwd = 2)

# Marcar punto mínimo en validación
min_idx <- which.min(hist_val)
points(min_idx, hist_val[min_idx], col = "darkgreen", pch = 19, cex = 1.5)
text(min_idx, hist_val[min_idx], labels = paste("Óptimo:", min_idx, "árboles"), pos = 3, col = "darkgreen", font = 2)

legend("topright",
       legend = c("Train (Entrenamiento)", "Validation (Datos nuevos)", paste("Punto Óptimo (", min_idx, " árboles)", sep="")),
       col = c("blue", "red", "darkgreen"),
       lty = c(1, 1, NA),
       pch = c(NA, NA, 19),
       lwd = c(2, 2, NA))

dev.off()
cat("Gráfico generado exitosamente en:", archivo_png, "\n")

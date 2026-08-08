# z470_GBDT_LightGBM — Final train + Kaggle submission
# Semilla 401987, best params from quick grid search
library(data.table)
library(lightgbm)

PARAM <- list()
PARAM$experimento <- 4700
PARAM$semilla_primigenia <- 401987

PARAM$lgb$num_iterations <- 570
PARAM$lgb$learning_rate <- 0.015
PARAM$lgb$feature_fraction <- 0.60
PARAM$lgb$min_data_in_leaf <- 50
PARAM$lgb$num_leaves <- 20
PARAM$lgb$max_bin <- 31

cat("===========================================\n")
cat("LightGBM Final Train — Semilla 401987\n")
cat("num_leaves=20  lr=0.015  feat=0.60  min_data=50  iter=570\n")
cat("===========================================\n\n")

# Load data
dataset <- fread("/Users/tomas/Dev/dm2026b/datasets/dataset_pequeno.csv", stringsAsFactors = TRUE)

# Binary class
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+2"), 1L, 0L)]

# Features
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

# Train on ALL July
dataset[, train := 0L]
dataset[foto_mes == 202107, train := 1L]

dtrain <- lgb.Dataset(
  data = data.matrix(dataset[train == 1L, campos_buenos, with = FALSE]),
  label = dataset[train == 1L, clase01]
)

cat("Training on", dataset[train == 1L, .N], "rows\n")
cat("Features:", length(campos_buenos), "\n\n")

# Train model
set.seed(PARAM$semilla_primigenia, kind = "L'Ecuyer-CMRG")

modelo <- lgb.train(
  data = dtrain,
  param = list(
    objective = "binary",
    max_bin = PARAM$lgb$max_bin,
    learning_rate = PARAM$lgb$learning_rate,
    num_iterations = PARAM$lgb$num_iterations,
    num_leaves = PARAM$lgb$num_leaves,
    min_data_in_leaf = PARAM$lgb$min_data_in_leaf,
    feature_fraction = PARAM$lgb$feature_fraction,
    seed = PARAM$semilla_primigenia,
    verbosity = -1
  ),
  verbose = 0
)

cat("Model trained.\n\n")

# Predict on September (future data)
dfuture <- dataset[foto_mes == 202109]
prediccion <- predict(
  modelo,
  data.matrix(dfuture[, campos_buenos, with = FALSE])
)

# Build prediction table
tb_prediccion <- dfuture[, list(numero_de_cliente)]
tb_prediccion[, prob := prediccion]

# Order by probability descending
setorder(tb_prediccion, -prob)

# Apply threshold prob > 0.025
tb_prediccion[, Predicted := 0L]
tb_prediccion[prob > (1/40), Predicted := 1L]

# Save CSV
archivo_salida <- "salidaLIGHTGBM.csv"
fwrite(tb_prediccion[, list(numero_de_cliente, Predicted)],
  file = archivo_salida,
  sep = ","
)

cat("File saved:", archivo_salida, "\n")
cat("Total rows:", nrow(tb_prediccion), "\n")
cat("Predicted=1:", tb_prediccion[Predicted == 1, .N], "\n")
cat("Predicted=0:", tb_prediccion[Predicted == 0, .N], "\n")

cat("\nDone! 🚀\n")

# z494_benchmark_baja2.R
# LightGBM enfocado puramente en BAJA+2 con Ensamble de 5 Semillas (Seed Averaging)
# Diseñado para maximizar la métrica real de la competencia Kaggle

rm(list = ls(all.names = TRUE))
gc(full = TRUE, verbose = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(lightgbm)
  library(yaml)
})

PARAM <- list()
PARAM$experimento <- 5950
PARAM$semillas <- c(401987, 456791, 607219, 701819, 811147)
PARAM$semilla_primigenia <- 401987

# Hiperparámetros óptimos para BAJA+2
PARAM$lgb <- list(
  objective = "binary",
  metric = "auc",
  boosting = "gbdt",
  max_bin = 31L,
  learning_rate = 0.018,
  num_iterations = 650,
  num_leaves = 24,
  min_data_in_leaf = 50,
  feature_fraction = 0.65,
  bagging_fraction = 0.85,
  bagging_freq = 1L,
  lambda_l1 = 0.5,
  lambda_l2 = 5.0,
  extra_trees = FALSE,
  force_row_wise = TRUE,
  feature_pre_filter = FALSE,
  verbosity = -100
)

dir_base <- "/Users/tomas/dev/dm2026b"
dir_exp <- file.path(dir_base, "exp", paste0("exp", PARAM$experimento))
dir_kaggle <- file.path(dir_exp, "kaggle")
dir.create(dir_kaggle, recursive = TRUE, showWarnings = FALSE)

dataset <- fread(file.path(dir_base, "datasets/dataset_pequeno.csv"), stringsAsFactors = TRUE)
dataset[, clase01 := ifelse(clase_ternaria == "BAJA+2", 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

julio <- dataset[foto_mes == 202107]
dfuture <- dataset[foto_mes == 202109]

dtrain <- lgb.Dataset(
  data = data.matrix(julio[, campos_buenos, with = FALSE]),
  label = julio$clase01,
  free_raw_data = FALSE
)

matriz_futuro <- data.matrix(dfuture[, campos_buenos, with = FALSE])
prob_acumulada <- numeric(nrow(dfuture))

for (idx in seq_along(PARAM$semillas)) {
  sem <- PARAM$semillas[idx]
  param_sem <- copy(PARAM$lgb)
  param_sem$seed <- sem
  
  set.seed(sem, kind = "L'Ecuyer-CMRG")
  modelo <- lgb.train(
    data = dtrain,
    param = param_sem,
    verbose = -100
  )
  
  preds_sem <- predict(modelo, matriz_futuro)
  prob_acumulada <- prob_acumulada + preds_sem
}

prob_promedio <- prob_acumulada / length(PARAM$semillas)

tb_prediccion <- dfuture[, .(numero_de_cliente)]
tb_prediccion[, prob := prob_promedio]
setorder(tb_prediccion, -prob)

fwrite(tb_prediccion, file = file.path(dir_exp, "prediccion.txt"), sep = "\t")

# Generar cortes extendidos
cortes <- seq(9000, 13500, by = 500)

for (env in cortes) {
  tb_prediccion[, Predicted := 0L]
  tb_prediccion[1:env, Predicted := 1L]
  
  archivo_csv <- file.path(dir_kaggle, paste0("KA", PARAM$experimento, "_", env, ".csv"))
  fwrite(tb_prediccion[, .(numero_de_cliente, Predicted)], file = archivo_csv, sep = ",")
}

cat("Generados todos los cortes de 9000 a 13500 en", dir_kaggle, "\n")

# z494_optimizacion_lgbm.R
# Optimizacion de Hiperparametros LightGBM para Tarea Hogar 04 (DM2026B)
# Semilla primigenia: 401987

rm(list = ls(all.names = TRUE))
gc(full = TRUE, verbose = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(lightgbm)
  library(parallel)
  library(yaml)
})

# ==========================================
# 1. PARAMETROS GLOBALES
# ==========================================
PARAM <- list()
PARAM$experimento <- 5940
PARAM$semilla_primigenia <- 401987
PARAM$semilla2 <- 456791  # Para undersampling reproducible
PARAM$kaggle$competencia <- "data-mining-inicial-2026-b"
PARAM$kaggle$cortes <- seq(9000, 12000, by = 500)
PARAM$trainingstrategy$undersampling <- 0.5
PARAM$hyperparametertuning$xval_folds <- 5

# Directorios
dir_base <- "/Users/tomas/dev/dm2026b"
dir_exp_ht <- file.path(dir_base, "exp", paste0("HT", PARAM$experimento))
dir_exp_final <- file.path(dir_base, "exp", paste0("exp", PARAM$experimento))
dir.create(dir_exp_ht, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_exp_final, recursive = TRUE, showWarnings = FALSE)

cat("\n========================================================\n")
cat("🚀 INICIANDO OPTIMIZACIÓN LIGHTGBM — TAREA HOGAR 04\n")
cat("Experimento:", PARAM$experimento, "| Semilla:", PARAM$semilla_primigenia, "\n")
cat("========================================================\n\n")

# ==========================================
# 2. CARGA Y PREPARACIÓN DE DATOS
# ==========================================
dataset_path <- file.path(dir_base, "datasets/dataset_pequeno.csv")
dataset <- fread(dataset_path, stringsAsFactors = TRUE)

# Clase binaria (BAJA+1 y BAJA+2 son 1L, CONTINUA es 0L)
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+1", "BAJA+2"), 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01", "azar", "training", "fold"))

# Dataset Julio 2021
julio <- dataset[foto_mes == 202107]

# Undersampling reproducible para la optimización
set.seed(PARAM$semilla2, kind = "L'Ecuyer-CMRG")
julio[, azar := runif(.N)]
julio[, training := 0L]
julio[
  azar <= PARAM$trainingstrategy$undersampling | clase01 == 1L,
  training := 1L
]

julio_train <- julio[training == 1L]
cat(sprintf("Julio original: %d filas | Post-undersampling (0.5): %d filas (Positivos: %d)\n",
            nrow(julio), nrow(julio_train), sum(julio_train$clase01)))

# Asignar folds estratificados
set.seed(PARAM$semilla_primigenia, kind = "L'Ecuyer-CMRG")
julio_train[, fold := (sample(.N) %% PARAM$hyperparametertuning$xval_folds) + 1L]

# Función para calcular ganancia en un conjunto de predicciones
calc_ganancia_cortes <- function(probs, labels, cortes_eval) {
  dt_eval <- data.table(prob = probs, label = labels)
  setorder(dt_eval, -prob)
  
  ganancias <- sapply(cortes_eval, function(corte) {
    # Proporción del corte para el tamaño del dataset de validación
    n_envios <- min(corte, nrow(dt_eval))
    sub <- dt_eval[1:n_envios]
    tp <- sum(sub$label == 1L)
    fp <- n_envios - tp
    (tp * 975000) - (fp * 25000)
  })
  names(ganancias) <- paste0("corte_", cortes_eval)
  return(ganancias)
}

# ==========================================
# 3. ESPACIO DE BÚSQUEDA DE HIPERPARÁMETROS
# ==========================================
# Diseñamos un grid fino y diversificado basado en la zona óptima
grid_combos <- data.table(
  num_leaves       = c( 15,    20,    20,    25,    25,    31,    31,    35,    20,    25,    31,    40,    20,    25),
  min_data_in_leaf = c( 50,    50,    75,    50,    75,    50,    75,    60,    40,    60,    40,    50,    50,    75),
  learning_rate    = c(0.015, 0.015, 0.020, 0.015, 0.020, 0.015, 0.020, 0.018, 0.025, 0.020, 0.015, 0.015, 0.015, 0.020),
  num_iterations   = c( 600,   600,   550,   650,   600,   550,   500,   600,   450,   550,   600,   500,   700,   650),
  feature_fraction = c( 0.60,  0.60,  0.70,  0.60,  0.70,  0.60,  0.65,  0.55,  0.70,  0.65,  0.60,  0.55,  0.60,  0.70),
  bagging_fraction = c( 1.0,   1.0,   0.9,   1.0,   0.9,   1.0,   0.9,   0.85,  1.0,   0.9,   1.0,   0.9,   0.9,   1.0),
  lambda_l1        = c(  0.0,   0.1,   0.5,   1.0,   0.0,   1.0,   2.0,   0.5,   0.0,   1.0,   0.5,   2.0,   1.0,   0.0),
  lambda_l2        = c(  0.0,   1.0,   5.0,   2.0,  10.0,   5.0,  10.0,   5.0,   1.0,   5.0,   2.0,  10.0,   5.0,   0.0),
  extra_trees      = c(FALSE, FALSE,  TRUE, FALSE,  TRUE, FALSE,  TRUE,  TRUE, FALSE, FALSE,  TRUE, FALSE,  TRUE, FALSE)
)

cat(sprintf("Evaluando %d combinaciones con %d-Fold Cross-Validation...\n\n",
            nrow(grid_combos), PARAM$hyperparametertuning$xval_folds))

# ==========================================
# 4. EJECUCIÓN DE CROSS-VALIDATION
# ==========================================
resultados <- list()

for (i in 1:nrow(grid_combos)) {
  p <- as.list(grid_combos[i])
  t0 <- Sys.time()
  
  # Out-Of-Fold predictions
  oof_probs <- numeric(nrow(julio_train))
  
  for (f in 1:PARAM$hyperparametertuning$xval_folds) {
    idx_val <- which(julio_train$fold == f)
    idx_tr  <- which(julio_train$fold != f)
    
    dtrain_fold <- lgb.Dataset(
      data = data.matrix(julio_train[idx_tr, campos_buenos, with = FALSE]),
      label = julio_train[idx_tr, clase01],
      free_raw_data = FALSE
    )
    
    param_lgb <- list(
      objective = "binary",
      metric = "auc",
      boosting = "gbdt",
      max_bin = 31L,
      learning_rate = p$learning_rate,
      num_iterations = p$num_iterations,
      num_leaves = p$num_leaves,
      min_data_in_leaf = p$min_data_in_leaf,
      feature_fraction = p$feature_fraction,
      bagging_fraction = p$bagging_fraction,
      bagging_freq = ifelse(p$bagging_fraction < 1.0, 1L, 0L),
      lambda_l1 = p$lambda_l1,
      lambda_l2 = p$lambda_l2,
      extra_trees = p$extra_trees,
      force_row_wise = TRUE,
      feature_pre_filter = FALSE,
      seed = PARAM$semilla_primigenia,
      verbosity = -100
    )
    
    modelo_fold <- lgb.train(
      data = dtrain_fold,
      param = param_lgb,
      verbose = -100
    )
    
    val_preds <- predict(modelo_fold, data.matrix(julio_train[idx_val, campos_buenos, with = FALSE]))
    oof_probs[idx_val] <- val_preds
    
    rm(dtrain_fold, modelo_fold)
  }
  
  # Escalar cortes de envíos al tamaño del training undersampled (aprox ~80k filas vs 160k completas)
  # Proporción de envíos equivalentes: 9000 a 12000 en base completa equivale a ~4500 a 6000 en 0.5 undersampling
  cortes_undersampled <- round(PARAM$kaggle$cortes * PARAM$trainingstrategy$undersampling)
  ganancias_oof <- calc_ganancia_cortes(oof_probs, julio_train$clase01, cortes_undersampled)
  
  # Normalizar ganancia a escala 100% (multiplicar por 1 / undersampling = 2)
  ganancias_normalizadas <- ganancias_oof / PARAM$trainingstrategy$undersampling
  max_ganancia <- max(ganancias_normalizadas)
  mejor_corte_idx <- which.max(ganancias_normalizadas)
  mejor_corte_envios <- PARAM$kaggle$cortes[mejor_corte_idx]
  
  t1 <- Sys.time()
  duracion <- as.numeric(difftime(t1, t0, units = "secs"))
  
  cat(sprintf("[%2d/%2d] leaves=%2d min_d=%2d lr=%.3f iter=%4d feat=%.2f xtrees=%s | MaxGan: %6.1f M (corte=%5d) | %4.1f seg\n",
              i, nrow(grid_combos), p$num_leaves, p$min_data_in_leaf, p$learning_rate,
              p$num_iterations, p$feature_fraction, ifelse(p$extra_trees, "T", "F"),
              max_ganancia / 1e6, mejor_corte_envios, duracion))
  
  res_row <- as.data.table(p)
  res_row[, max_ganancia := max_ganancia]
  res_row[, mejor_corte := mejor_corte_envios]
  for (c_name in names(ganancias_normalizadas)) {
    res_row[, (c_name) := ganancias_normalizadas[c_name]]
  }
  resultados[[i]] <- res_row
}

tb_grid_search <- rbindlist(resultados)
setorder(tb_grid_search, -max_ganancia)

# Guardar tabla de grid search
archivo_grid <- file.path(dir_exp_ht, "tb_grid_search_01.txt")
fwrite(tb_grid_search, file = archivo_grid, sep = "\t")

cat("\n========================================================\n")
cat("🏆 TOP 3 MEJORES CONFIGURACIONES ENCONTRADAS:\n")
cat("========================================================\n")
print(tb_grid_search[1:min(3, nrow(tb_grid_search)), 
                     .(num_leaves, min_data_in_leaf, learning_rate, num_iterations, 
                       feature_fraction, extra_trees, max_ganancia_M = round(max_ganancia/1e6, 1), mejor_corte)])

# Guardar mejores hiperparámetros
mejor <- as.list(tb_grid_search[1])
PARAM$out$lgbm$mejores_hiperparametros <- list(
  num_leaves = mejor$num_leaves,
  min_data_in_leaf = mejor$min_data_in_leaf,
  learning_rate = mejor$learning_rate,
  num_iterations = mejor$num_iterations,
  feature_fraction = mejor$feature_fraction,
  bagging_fraction = mejor$bagging_fraction,
  lambda_l1 = mejor$lambda_l1,
  lambda_l2 = mejor$lambda_l2,
  extra_trees = mejor$extra_trees
)
PARAM$out$lgbm$mejor_ganancia_cv <- mejor$max_ganancia
PARAM$out$lgbm$mejor_corte_cv <- mejor$mejor_corte

write_yaml(PARAM, file = file.path(dir_exp_ht, "PARAM.yml"))
write_yaml(PARAM, file = file.path(dir_exp_final, "PARAM.yml"))

# ==========================================
# 5. FINAL TRAINING (SOBRE TODO JULIO 2021)
# ==========================================
cat("\n========================================================\n")
cat("🏋️ INICIANDO FINAL TRAINING SOBRE 100% DE JULIO 2021\n")
cat("========================================================\n\n")

# Dataset completo de Julio (sin undersampling)
julio_full <- dataset[foto_mes == 202107]
dtrain_full <- lgb.Dataset(
  data = data.matrix(julio_full[, campos_buenos, with = FALSE]),
  label = julio_full$clase01,
  free_raw_data = FALSE
)

# Ajuste fino: normalizar min_data_in_leaf al pasar de 0.5 a 1.0
param_final <- copy(PARAM$out$lgbm$mejores_hiperparametros)
param_final$min_data_in_leaf <- round(param_final$min_data_in_leaf / PARAM$trainingstrategy$undersampling)
param_final$objective <- "binary"
param_final$metric <- "auc"
param_final$boosting <- "gbdt"
param_final$max_bin <- 31L
param_final$seed <- PARAM$semilla_primigenia
param_final$verbosity <- -100
param_final$bagging_freq <- ifelse(param_final$bagging_fraction < 1.0, 1L, 0L)
param_final$force_row_wise <- TRUE
param_final$feature_pre_filter <- FALSE

set.seed(PARAM$semilla_primigenia, kind = "L'Ecuyer-CMRG")
modelo_final <- lgb.train(
  data = dtrain_full,
  param = param_final,
  verbose = -100
)

# Guardar importancia de variables y modelo
tb_importancia <- as.data.table(lgb.importance(modelo_final))
fwrite(tb_importancia, file = file.path(dir_exp_final, "impo.txt"), sep = "\t")
lgb.save(modelo_final, file.path(dir_exp_final, "modelo.txt"))

cat("Modelo final entrenado e importancia de variables guardada.\n\n")

# ==========================================
# 6. SCORING SOBRE SEPTIEMBRE 2021 (TEST)
# ==========================================
cat("🔮 Generando predicciones sobre Septiembre 2021 (202109)...\n")
dfuture <- dataset[foto_mes == 202109]
prediccion_futuro <- predict(
  modelo_final,
  data.matrix(dfuture[, campos_buenos, with = FALSE])
)

tb_prediccion <- dfuture[, .(numero_de_cliente)]
tb_prediccion[, prob := prediccion_futuro]
setorder(tb_prediccion, -prob)

fwrite(tb_prediccion, file = file.path(dir_exp_final, "prediccion.txt"), sep = "\t")

# Generar archivos Kaggle
dir_kaggle <- file.path(dir_exp_final, "kaggle")
dir.create(dir_kaggle, recursive = TRUE, showWarnings = FALSE)

archivos_kaggle <- list()

for (envios in PARAM$kaggle$cortes) {
  tb_prediccion[, Predicted := 0L]
  tb_prediccion[1:envios, Predicted := 1L]
  
  archivo_csv <- file.path(dir_kaggle, paste0("KA", PARAM$experimento, "_", envios, ".csv"))
  fwrite(tb_prediccion[, .(numero_de_cliente, Predicted)], file = archivo_csv, sep = ",")
  archivos_kaggle[[as.character(envios)]] <- archivo_csv
  cat(sprintf("Generado: %s (%d clientes enviados)\n", basename(archivo_csv), envios))
}

cat("\n========================================================\n")
cat("✅ PROCESO COMPLETADO EXITOSAMENTE\n")
cat("========================================================\n")

# Workflow Junior Septiembre - Grid Search
# Semilla: 456791
# Método Data Drift: ninguno

library("data.table")
library("lightgbm")

PARAM <- list()
PARAM$semilla_primigenia <- 456791
PARAM$experimento <- "WF_sep_semilla_456791-ninguno"
PARAM$dataset <- "analistajr_competencia_2026.csv.gz"

dir.create(paste0("/Users/tomas/Dev/dm2026b/exp/", PARAM$experimento), showWarnings = FALSE, recursive = TRUE)
setwd(paste0("/Users/tomas/Dev/dm2026b/exp/", PARAM$experimento))

# Cargar dataset
dataset <- fread(paste0("/Users/tomas/Dev/dm2026b/datasets/", PARAM$dataset))

# Data Drift
PARAM$DR <- list()
PARAM$DR$metodo <- "ninguno"

if (PARAM$DR$metodo != "ninguno") {
  cat("Aplicando Data Drift:", PARAM$DR$metodo, "\n")
  campos_monetarios <- colnames(dataset)[colnames(dataset) %like% "^m_"]
  
  if (PARAM$DR$metodo == "rank_cero_fijo") {
    for (campo in campos_monetarios) {
      dataset[get(campo) != 0, (campo) := frank(get(campo)) / .N, by = foto_mes]
    }
  } else if (PARAM$DR$metodo == "rank_simple") {
    for (campo in campos_monetarios) {
      dataset[, (campo) := frank(get(campo)) / .N, by = foto_mes]
    }
  } else if (PARAM$DR$metodo == "deflacion") {
    for (campo in campos_monetarios) {
      dataset[, (campo) := get(campo) / mean(get(campo), na.rm = TRUE), by = foto_mes]
    }
  }
}

# Estrategia de entrenamiento para Septiembre
PARAM$trainingstrategy <- list()
PARAM$trainingstrategy$validate <- c(202107)
PARAM$trainingstrategy$training <- c(
  201901, 201902, 201903, 201904, 201905, 201906,
  201907, 201908, 201909, 201910, 201911, 201912,
  202001, 202002, 202003, 202004, 202005, 202006,
  202007, 202008, 202009, 202010, 202011, 202012,
  202101, 202102, 202103, 202104, 202105
)
PARAM$trainingstrategy$training_pct <- 1.0
PARAM$trainingstrategy$positivos <- c("BAJA+1", "BAJA+2")

dataset[, clase01 := ifelse(clase_ternaria %in% PARAM$trainingstrategy$positivos, 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01", "numero_de_cliente", "foto_mes"))

dataset[, fold_train := foto_mes %in% PARAM$trainingstrategy$training]
dataset[, fold_validate := foto_mes %in% PARAM$trainingstrategy$validate]

dtrain <- lgb.Dataset(
  data = data.matrix(dataset[fold_train == TRUE, campos_buenos, with = FALSE]),
  label = dataset[fold_train == TRUE, clase01],
  free_raw_data = TRUE
)

dvalidate <- lgb.Dataset(
  data = data.matrix(dataset[fold_validate == TRUE, campos_buenos, with = FALSE]),
  label = dataset[fold_validate == TRUE, clase01],
  reference = dtrain,
  free_raw_data = TRUE
)

# Grid Search
PARAM$lgbm <- list()
PARAM$lgbm$param_fijos <- list(
  objective = "binary",
  metric = "auc",
  first_metric_only = TRUE,
  boost_from_average = TRUE,
  feature_pre_filter = FALSE,
  verbosity = -100,
  force_row_wise = TRUE,
  seed = PARAM$semilla_primigenia,
  max_bin = 31L,
  learning_rate = 0.03,
  early_stopping_rounds = 200L
)

PARAM$lgbm$grid_search <- list(
  num_leaves = c(64L, 128L, 256L, 384L, 512L),
  min_data_in_leaf = c(64L, 256L, 512L, 1024L, 2048L),
  feature_fraction = c(0.5, 0.8)
)

grid_comb <- expand.grid(PARAM$lgbm$grid_search)
tb_grid <- data.table()

cat(format(Sys.time(), "[%H:%M:%S]"), "Iniciando Grid Search (202107)...
")

for (i in 1:nrow(grid_comb)) {
  param_iter <- c(PARAM$lgbm$param_fijos, as.list(grid_comb[i, ]))
  param_iter$num_iterations <- 2048L
  
  m_iter <- lgb.train(data = dtrain, valids = list(val = dvalidate), param = param_iter, verbose = -100)
  
  auc_val <- m_iter$best_score
  iter_val <- m_iter$best_iter
  
  row_dt <- data.table(grid_comb[i, ], AUC = auc_val, num_iterations = iter_val)
  tb_grid <- rbind(tb_grid, row_dt)
}

setorder(tb_grid, -AUC)
fwrite(tb_grid, file = "tb_grid_search_01.txt", sep = "	")

PARAM$out$lgbm$AUC <- tb_grid[1, AUC]
PARAM$out$lgbm$mejores_hiperparametros <- as.list(tb_grid[1])
PARAM$out$lgbm$mejores_hiperparametros$AUC <- NULL

# Entrenamiento Final para Septiembre (Entrena sobre todo 201901 hasta 202107)
PARAM$trainingstrategy$final_train <- c(
  201901, 201902, 201903, 201904, 201905, 201906,
  201907, 201908, 201909, 201910, 201911, 201912,
  202001, 202002, 202003, 202004, 202005, 202006,
  202007, 202008, 202009, 202010, 202011, 202012,
  202101, 202102, 202103, 202104, 202105, 202106, 202107
)

dataset[, fold_final_train := foto_mes %in% PARAM$trainingstrategy$final_train]

dfinal_train <- lgb.Dataset(
  data = data.matrix(dataset[fold_final_train == TRUE, campos_buenos, with = FALSE]),
  label = dataset[fold_final_train == TRUE, clase01],
  free_raw_data = TRUE
)

param_final <- c(PARAM$lgbm$param_fijos, PARAM$out$lgbm$mejores_hiperparametros)
param_final$early_stopping_rounds <- NULL

cat(format(Sys.time(), "[%H:%M:%S]"), "Entrenando Modelo Final con 202107...
")
final_model <- lgb.train(data = dfinal_train, param = param_final, verbose = -100)

lgb.save(final_model, "modelo.txt")

tb_imp <- as.data.table(lgb.importance(final_model))
fwrite(tb_imp, file = "impo.txt", sep = "	")

# Scoring Futuro Septiembre (202109)
PARAM$trainingstrategy$future <- c(202109)
dfuture <- dataset[foto_mes %in% PARAM$trainingstrategy$future]

cat(format(Sys.time(), "[%H:%M:%S]"), "Prediciendo Septiembre 2021 (202109)...
")
prediccion <- predict(final_model, data.matrix(dfuture[, campos_buenos, with = FALSE]))

tb_pred <- dfuture[, list(numero_de_cliente)]
tb_pred[, prob := prediccion]
fwrite(tb_pred, file = "prediccion.txt", sep = "	")

# Generar archivos de envío para Kaggle
PARAM$kaggle$competencia <- "data-mining-junior-2026-b"
PARAM$kaggle$cortes <- seq(1800, 2400, by = 100)

setorder(tb_pred, -prob)
dir.create("kaggle", showWarnings = FALSE)

for (envios in PARAM$kaggle$cortes) {
  tb_pred[, Predicted := 0L]
  tb_pred[1:envios, Predicted := 1L]
  
  archivo_kaggle <- paste0("./kaggle/KA", PARAM$experimento, "_", envios, ".csv")
  fwrite(tb_pred[, list(numero_de_cliente, Predicted)], file = archivo_kaggle, sep = ",")
}

if (!require("yaml")) install.packages("yaml")
library("yaml")
write_yaml(PARAM, file = "PARAM.yml")

cat(format(Sys.time(), "[%H:%M:%S]"), "Workflow Septiembre Completado Exitosamente.\n")

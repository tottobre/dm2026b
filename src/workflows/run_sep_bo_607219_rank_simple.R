# Workflow Junior Septiembre - Optimización Bayesiana (BO)
# Semilla: 607219
# Método Data Drift: rank_simple

library("data.table")
library("lightgbm")
library("mlrMBO")
library("DiceKriging")

PARAM <- list()
PARAM$semilla_primigenia <- 607219
PARAM$experimento <- "WF_sep_semilla_607219-rank_simple_BO"
PARAM$dataset <- "analistajr_competencia_2026.csv.gz"

dir.create(paste0("/Users/tomas/Dev/dm2026b/exp/", PARAM$experimento), showWarnings = FALSE, recursive = TRUE)
setwd(paste0("/Users/tomas/Dev/dm2026b/exp/", PARAM$experimento))

dataset <- fread(paste0("/Users/tomas/Dev/dm2026b/datasets/", PARAM$dataset))

PARAM$DR <- list()
PARAM$DR$metodo <- "rank_simple"

if (PARAM$DR$metodo != "ninguno") {
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

evaluar_lgbm <- function(x) {
  param_eval <- list(
    objective = "binary",
    metric = "auc",
    first_metric_only = TRUE,
    boost_from_average = TRUE,
    feature_pre_filter = FALSE,
    verbosity = -100,
    force_row_wise = TRUE,
    seed = PARAM$semilla_primigenia,
    max_bin = 31L,
    num_iterations = as.integer(round(2^x$num_iterations)),
    num_leaves = as.integer(round(2^x$num_leaves)),
    learning_rate = 2^x$learning_rate,
    feature_fraction = x$feature_fraction,
    min_sum_hessian_in_leaf = 2^x$min_sum_hessian_in_leaf,
    lambda_l1 = x$lambda_l1,
    lambda_l2 = x$lambda_l2,
    min_gain_to_split = x$min_gain_to_split
  )
  
  m_eval <- lgb.train(data = dtrain, valids = list(val = dvalidate), param = param_eval, verbose = -100)
  return(m_eval$best_score)
}

obj_fun <- makeSingleObjectiveFunction(
  name = "BO_LGBM",
  fn = evaluar_lgbm,
  par.set = makeParamSet(
    makeNumericParam("num_iterations", lower = 2.0, upper = 10.0),
    makeNumericParam("num_leaves", lower = 2.0, upper = 11.0),
    makeNumericParam("learning_rate", lower = -7.0, upper = -0.1),
    makeNumericParam("feature_fraction", lower = 0.05, upper = 0.9),
    makeNumericParam("min_sum_hessian_in_leaf", lower = -10.0, upper = 10.0),
    makeNumericParam("lambda_l1", lower = 0.0, upper = 600.0),
    makeNumericParam("lambda_l2", lower = 0.0, upper = 600.0),
    makeNumericParam("min_gain_to_split", lower = 0.0, upper = 20.0)
  ),
  minimize = FALSE
)

ctrl <- makeMBOControl(save.on.disk.at.time = 60, save.file.path = "HT.RDATA")
ctrl <- setMBOControlTermination(ctrl, iters = 30)
ctrl <- setMBOControlInfill(ctrl, crit = makeMBOInfillCritEI())

surr_km <- makeLearner("regr.km", predict.type = "se", covtype = "matern3_2", control = list(trace = FALSE))

set.seed(PARAM$semilla_primigenia)
res_mbo <- mbo(obj_fun, learner = surr_km, control = ctrl, show.info = FALSE)

tb_bo <- as.data.table(res_mbo$opt.path)
fwrite(tb_bo, file = "BO_log.txt", sep = "	")

best_pars <- res_mbo$x
PARAM$out$lgbm$mejores_hiperparametros <- list(
  num_iterations = as.integer(round(2^best_pars$num_iterations)),
  num_leaves = as.integer(round(2^best_pars$num_leaves)),
  learning_rate = 2^best_pars$learning_rate,
  feature_fraction = best_pars$feature_fraction,
  min_sum_hessian_in_leaf = 2^best_pars$min_sum_hessian_in_leaf,
  lambda_l1 = best_pars$lambda_l1,
  lambda_l2 = best_pars$lambda_l2,
  min_gain_to_split = best_pars$min_gain_to_split,
  AUC = res_mbo$y
)

# Final Train para Septiembre (201901 a 202107)
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

param_final <- list(
  objective = "binary",
  metric = "auc",
  first_metric_only = TRUE,
  boost_from_average = TRUE,
  feature_pre_filter = FALSE,
  verbosity = -100,
  force_row_wise = TRUE,
  seed = PARAM$semilla_primigenia,
  max_bin = 31L,
  num_iterations = PARAM$out$lgbm$mejores_hiperparametros$num_iterations,
  num_leaves = PARAM$out$lgbm$mejores_hiperparametros$num_leaves,
  learning_rate = PARAM$out$lgbm$mejores_hiperparametros$learning_rate,
  feature_fraction = PARAM$out$lgbm$mejores_hiperparametros$feature_fraction,
  min_sum_hessian_in_leaf = PARAM$out$lgbm$mejores_hiperparametros$min_sum_hessian_in_leaf,
  lambda_l1 = PARAM$out$lgbm$mejores_hiperparametros$lambda_l1,
  lambda_l2 = PARAM$out$lgbm$mejores_hiperparametros$lambda_l2,
  min_gain_to_split = PARAM$out$lgbm$mejores_hiperparametros$min_gain_to_split
)

cat(format(Sys.time(), "[%H:%M:%S]"), "Entrenando Modelo Final con 202107 (BO)...
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

cat(format(Sys.time(), "[%H:%M:%S]"), "Workflow BO Septiembre Completado Exitosamente.\n")

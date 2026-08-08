# Quick LightGBM parameter exploration for seed 401987
library(data.table)
library(lightgbm)

semilla <- 401987

dataset <- fread("/Users/tomas/Dev/dm2026b/datasets/dataset_pequeno.csv", stringsAsFactors = TRUE)
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+2"), 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

# Train/val split 70/30 on July
set.seed(semilla, kind = "L'Ecuyer-CMRG")
julio <- dataset[foto_mes == 202107]
julio[, azar := runif(.N)]
julio[, train := azar <= 0.7]

calc_ganancia <- function(probs, labels) {
  pred <- ifelse(probs > 0.025, 1L, 0L)
  sum(ifelse(pred == 1 & labels == 1, 975000,
             ifelse(pred == 1 & labels == 0, -25000, 0)))
}

# 12 combos — focus on num_leaves, learning_rate, feature_fraction, min_data_in_leaf
grid <- data.table(
  num_leaves       = c( 8,  15,  15,  20,  20,  31,  31,  31,  40,  25,  12,  20),
  learning_rate    = c(.027,.027,.020,.020,.015,.015,.020,.010,.015,.018,.030,.025),
  feature_fraction = c(.80, .80, .70, .70, .60, .60, .70, .80, .70, .65, .85, .75),
  min_data_in_leaf = c( 76,  76,  76,  50,  50,  40,  50,  50,  40,  50,  80,  60)
)

cat("\n===========================================\n")
cat("Quick LightGBM Tuning — Semilla", semilla, "\n")
cat("===========================================\n\n")

resultados <- data.table()

for (i in 1:nrow(grid)) {
  p <- grid[i]
  
  dtrain <- lgb.Dataset(
    data = data.matrix(julio[train == TRUE, campos_buenos, with = FALSE]),
    label = julio[train == TRUE, clase01]
  )
  dval <- lgb.Dataset(
    data = data.matrix(julio[train == FALSE, campos_buenos, with = FALSE]),
    label = julio[train == FALSE, clase01]
  )
  
  set.seed(semilla, kind = "L'Ecuyer-CMRG")
  
  modelo <- lgb.train(
    data = dtrain,
    valids = list(val = dval),
    param = list(
      objective = "binary",
      max_bin = 31,
      learning_rate = p$learning_rate,
      num_leaves = p$num_leaves,
      min_data_in_leaf = p$min_data_in_leaf,
      feature_fraction = p$feature_fraction,
      feature_pre_filter = FALSE,
      seed = semilla,
      verbosity = -1
    ),
    nrounds = 2000,
    early_stopping_rounds = 50,
    verbose = -1
  )
  
  best_iter <- modelo$best_iter
  val_labels <- julio[train == FALSE, clase01]
  val_probs <- predict(modelo, data.matrix(julio[train == FALSE, campos_buenos, with = FALSE]))
  ganancia <- calc_ganancia(val_probs, val_labels)
  ganancia_M <- round(ganancia / 1e6, 1)
  
  cat(sprintf("#%2d | leaves=%2d  lr=%.3f  feat=%.2f  min_data=%3d  iter=%4d | Ganancia: %6.1f M\n",
              i, p$num_leaves, p$learning_rate, p$feature_fraction, p$min_data_in_leaf, best_iter, ganancia_M))
  
  resultados <- rbind(resultados, data.table(
    num_leaves = p$num_leaves,
    learning_rate = p$learning_rate,
    feature_fraction = p$feature_fraction,
    min_data_in_leaf = p$min_data_in_leaf,
    best_iter = best_iter,
    ganancia = ganancia
  ))
}

cat("\n===========================================\n")
cat("TOP 5:\n")
resultados <- resultados[order(-ganancia)]
print(resultados[1:min(5, nrow(resultados))])

cat("\n🏆 MEJORES PARÁMETROS para semilla 401987:\n")
best <- resultados[1]
cat(sprintf("num_leaves=%d  learning_rate=%.3f  feature_fraction=%.2f  min_data_in_leaf=%d\n",
            best$num_leaves, best$learning_rate, best$feature_fraction, best$min_data_in_leaf))
cat(sprintf("Ganancia en validación (30%%): %.1f M\n", best$ganancia / 1e6))

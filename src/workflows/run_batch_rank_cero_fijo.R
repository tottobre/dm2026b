# High-efficiency batch executor for rank_cero_fijo on the 9 missing seeds
options(threads = 8)
library(data.table)
library(lightgbm)

cat("==================================================\n")
cat("   LOADING DATASET ONCE FOR BATCH SEED RUNS\n")
cat("==================================================\n")

dataset_file <- "/Users/tomas/Dev/dm2026b/datasets/analistajr_competencia_2026.csv.gz"
dataset <- fread(dataset_file)

# Preprocessing Functions
Corregir_atributo <- function(pcampo, pmeses, pmetodo) {
  if( !(pcampo %in% colnames( dataset )) ) return( 1 )
  if( pmetodo == "MachineLearning" ) {
    if( pcampo %in% colnames( dataset ) ) {
      dataset[ foto_mes %in% pmeses, paste0(pcampo) := NA ]
    }
  }
  return( 0 )
}

Corregir_Rotas <- function(dataset, pmetodo) {
  gc(verbose= FALSE)
  Corregir_atributo("active_quarter", c(202006), pmetodo)
  Corregir_atributo("internet", c(202006), pmetodo)
  Corregir_atributo("mrentabilidad", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mrentabilidad_annual", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mcomisiones", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mactivos_margen", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mpasivos_margen", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mcuentas_saldo", c(202006), pmetodo)
  Corregir_atributo("ctarjeta_debito_transacciones", c(202006), pmetodo)
  Corregir_atributo("mautoservicio", c(202006), pmetodo)
  Corregir_atributo("ctarjeta_visa_transacciones", c(202006), pmetodo)
  Corregir_atributo("mtarjeta_visa_consumo", c(202006), pmetodo)
  Corregir_atributo("ctarjeta_master_transacciones", c(202006), pmetodo)
  Corregir_atributo("mtarjeta_master_consumo", c(202006), pmetodo)
  Corregir_atributo("ctarjeta_visa_debitos_automaticos", c(201904), pmetodo)
  Corregir_atributo("mttarjeta_visa_debitos_automaticos", c(201904), pmetodo)
  Corregir_atributo("ccajeros_propios_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("mcajeros_propios_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("ctarjeta_visa_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("mtarjeta_visa_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("ctarjeta_master_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("mtarjeta_master_descuentos", c(201910, 202002, 202006, 202009, 202010, 202102), pmetodo)
  Corregir_atributo("ccomisiones_otras", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("mcomisiones_otras", c(201905, 201910, 202006), pmetodo)
  Corregir_atributo("cextraccion_autoservicio", c(202006), pmetodo)
  Corregir_atributo("mextraccion_autoservicio", c(202006), pmetodo)
  Corregir_atributo("ccheques_depositados", c(202006), pmetodo)
  Corregir_atributo("mcheques_depositados", c(202006), pmetodo)
  Corregir_atributo("ccheques_emitidos", c(202006), pmetodo)
  Corregir_atributo("mcheques_emitidos", c(202006), pmetodo)
  Corregir_atributo("ccheques_depositados_rechazados", c(202006), pmetodo)
  Corregir_atributo("mcheques_depositados_rechazados", c(202006), pmetodo)
  Corregir_atributo("ccheques_emitidos_rechazados", c(202006), pmetodo)
  Corregir_atributo("mcheques_emitidos_rechazados", c(202006), pmetodo)
  Corregir_atributo("tcallcenter", c(202006), pmetodo)
  Corregir_atributo("ccallcenter_transacciones", c(202006), pmetodo)
  Corregir_atributo("thomebanking", c(202006), pmetodo)
  Corregir_atributo("chomebanking_transacciones", c(201910, 202006), pmetodo)
  Corregir_atributo("ccajas_transacciones", c(202006), pmetodo)
  Corregir_atributo("ccajas_consultas", c(202006), pmetodo)
  Corregir_atributo("ccajas_depositos", c(202006, 202105), pmetodo)
  Corregir_atributo("ccajas_extracciones", c(202006), pmetodo)
  Corregir_atributo("ccajas_otras", c(202006), pmetodo)
  Corregir_atributo("catm_trx", c(202006), pmetodo)
  Corregir_atributo("matm", c(202006), pmetodo)
  Corregir_atributo("catm_trx_other", c(202006), pmetodo)
  Corregir_atributo("matm_other", c(202006), pmetodo)
}

setorder( dataset, numero_de_cliente, foto_mes )
Corregir_Rotas(dataset, "MachineLearning")

# Drift rank_cero_fijo
campos_monetarios <- colnames(dataset)[colnames(dataset) %like% "^(m|Visa_m|Master_m|vm_m)"]
cat("Applying rank_cero_fijo to monetary fields...\n")
for (campo in campos_monetarios) {
  dataset[get(campo) == 0, paste0(campo, "_rank") := 0]
  dataset[get(campo) > 0, paste0(campo, "_rank") := frank(get(campo), ties.method = "random") / .N, by = list(foto_mes)]
  dataset[get(campo) < 0, paste0(campo, "_rank") := -frank(-get(campo), ties.method = "random") / .N, by = list(foto_mes)]
  dataset[, (campo) := NULL]
}

# Lags
cat("Adding Lags...\n")
setorder( dataset, numero_de_cliente, foto_mes )
cols_lags <- setdiff(colnames(dataset), c("numero_de_cliente", "foto_mes", "clase_ternaria"))
for( cname in cols_lags ) {
  dataset[, paste0(cname, "_lag1") := shift(get(cname), 1, type = "lag"), by = list(numero_de_cliente)]
}

# Splits / Datasets for Training & Future
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+2", "BAJA+1"), 1L, 0L)]

dtrain <- dataset[foto_mes >= 201901 & foto_mes <= 202105]
dfuture <- dataset[foto_mes == 202107]

campos_buenos <- setdiff(colnames(dtrain), c("numero_de_cliente", "foto_mes", "clase_ternaria", "clase01"))

m_train <- lgb.Dataset(
  data = as.matrix(dtrain[, campos_buenos, with=FALSE]),
  label = dtrain$clase01
)

# LightGBM Hyperparameters from Junior Julio
param_lgb <- list(
  objective = "binary",
  metric = "custom",
  first_metric_only = TRUE,
  boost_from_average = TRUE,
  feature_pre_filter = FALSE,
  verbosity = -1,
  max_depth = -1,
  min_gain_to_split = 0.0,
  lambda_l1 = 0.0,
  lambda_l2 = 0.0,
  max_bin = 31,
  num_iterations = 384,
  force_row_wise = TRUE,
  learning_rate = 0.041695420313554,
  feature_fraction = 0.45781352467389,
  min_data_in_leaf = 1913,
  num_leaves = 705
)

missing_seeds <- c(250033, 250037, 314161, 441989, 478069, 516349, 516353, 600111, 630013)

cat("\n==================================================\n")
cat("   TRAINING LIGHTGBM FOR ALL MISSING SEEDS\n")
cat("==================================================\n")

results_summary <- list()

for (s in missing_seeds) {
  cat(sprintf("\n---> Running Seed %d...\n", s))
  param_lgb$seed <- s
  
  model <- lgb.train(
    params = param_lgb,
    data = m_train
  )
  
  prediccion <- predict(model, as.matrix(dfuture[, campos_buenos, with=FALSE]))
  
  tb_pred <- dfuture[, list(numero_de_cliente, clase_ternaria)]
  tb_pred[, prob := prediccion]
  
  tb_pred[, ganancia := -0.025]
  tb_pred[clase_ternaria == "BAJA+2", ganancia := 0.975]
  
  setorder(tb_pred, -prob)
  tb_pred[, gan_acum := cumsum(ganancia)]
  tb_pred[, gan_suavizada := frollmean(x = gan_acum, n = 400, align = "center", na.rm = TRUE, hasNA = TRUE)]
  
  gan_max <- max(tb_pred$gan_suavizada, na.rm = TRUE)
  env_opt <- which.max(tb_pred$gan_suavizada)
  
  results_summary[[as.character(s)]] <- list(ganancia = gan_max, envios = env_opt)
  cat(sprintf("   RESULT SEED %d: Ganancia Suavizada Max = %.4f | Envios = %d\n", s, gan_max, env_opt))
}

cat("\n==================================================\n")
cat("   FINAL SUMMARY OF ALL 9 SEEDS\n")
cat("==================================================\n")
res_df <- data.frame(
  Semilla = missing_seeds,
  Ganancia_Suavizada_Max = sapply(results_summary, function(x) x$ganancia),
  Envios_Optimos = sapply(results_summary, function(x) x$envios)
)
print(res_df)

write.csv(res_df, "/Users/tomas/Dev/dm2026b/exp/batch_rank_cero_fijo_summary.csv", row.names=FALSE)
cat("\nSaved results to exp/batch_rank_cero_fijo_summary.csv\n")

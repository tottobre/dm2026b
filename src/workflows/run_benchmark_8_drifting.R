
library(data.table)
library(lightgbm)
library(parallel)

dataset_path <- '/Users/tomas/Dev/dm2026b/datasets/analistajr_competencia_2026.csv.gz'
cat('Loading dataset...
')
dataset <- fread(dataset_path)
setorder(dataset, numero_de_cliente, foto_mes)

# Catastrophe Analysis
dataset[ foto_mes==202006, active_quarter := NA ]
dataset[ foto_mes==202006, mrentabilidad := NA ]
dataset[ foto_mes==202006, mrentabilidad_annual := NA ]
dataset[ foto_mes==202006, mcomisiones := NA ]
dataset[ foto_mes==202006, mactivos_margen := NA ]
dataset[ foto_mes==202006, mpasivos_margen := NA ]
dataset[ foto_mes==202006, mcuentas_saldo := NA ]
dataset[ foto_mes==202006, ctarjeta_visa_transacciones := NA ]
dataset[ foto_mes==202006, mtarjeta_visa_consumo := NA ]
dataset[ foto_mes==202006, ctarjeta_master_transacciones := NA ]
dataset[ foto_mes==202006, mtarjeta_master_consumo := NA ]
dataset[ foto_mes==202006, ccomisiones_mantenimiento := NA ]
dataset[ foto_mes==202006, mcomisiones_mantenimiento := NA ]
dataset[ foto_mes==202006, ccomisiones_otras := NA ]
dataset[ foto_mes==202006, mcomisiones_otras := NA ]

# Define monetary fields
campos_monetarios <- c('mrentabilidad', 'mrentabilidad_annual', 'mcomisiones', 'mactivos_margen', 'mpasivos_margen', 'mcuenta_corriente', 'mcaja_ahorro', 'mcuentas_saldo', 'mtarjeta_visa_consumo', 'mtarjeta_master_consumo', 'mprestamos_personales', 'mpayroll', 'mttarjeta_visa_debitos_automaticos', 'mcomisiones_mantenimiento', 'mtransferencias_recibidas', 'Master_mfinanciacion_limite', 'Master_msaldototal', 'Master_mlimitecompra', 'Master_mconsumototal', 'Master_mpagominimo', 'Visa_mfinanciacion_limite', 'Visa_msaldototal', 'Visa_mlimitecompra', 'Visa_mconsumototal', 'Visa_mpagominimo')

# Define Data Drifting functions
drift_rank_simple <- function(dt, campos) {
  for (campo in campos) {
    if (campo %in% colnames(dt)) {
      dt[, paste0(campo, '_rank') := frankv(get(campo), ties.method = 'dense', na.last = 'keep') / .N, by = foto_mes]
    }
  }
}

drift_rank_cero_fijo <- function(dt, campos) {
  for (campo in campos) {
    if (campo %in% colnames(dt)) {
      dt[, paste0(campo, '_rank') := ifelse(get(campo) == 0, 0, frankv(get(campo), ties.method = 'dense', na.last = 'keep') / .N), by = foto_mes]
    }
  }
}

drift_deflacion <- function(dt, campos) {
  ipc <- data.table(
    foto_mes = c(201901, 201902, 201903, 201904, 201905, 201906, 201907, 201908, 201909, 201910, 201911, 201912, 202001, 202002, 202003, 202004, 202005, 202006, 202007, 202008, 202009, 202010, 202011, 202012, 202101, 202102, 202103, 202104, 202105, 202106, 202107, 202108, 202109),
    factor = c(1.99, 1.91, 1.82, 1.77, 1.72, 1.67, 1.64, 1.58, 1.49, 1.44, 1.39, 1.34, 1.31, 1.29, 1.24, 1.23, 1.21, 1.18, 1.16, 1.13, 1.10, 1.06, 1.03, 1.00, 0.96, 0.93, 0.88, 0.85, 0.82, 0.80, 0.77, 0.75, 0.72)
  )
  dt[ipc, on = 'foto_mes', (campos) := lapply(.SD, function(x) x * i.factor), .SDcols = campos]
}

drift_dolarblue <- function(dt, campos) {
  db <- data.table(
    foto_mes = c(201901, 201902, 201903, 201904, 201905, 201906, 201907, 201908, 201909, 201910, 201911, 201912, 202001, 202002, 202003, 202004, 202005, 202006, 202007, 202008, 202009, 202010, 202011, 202012, 202101, 202102, 202103, 202104, 202105, 202106, 202107, 202108, 202109),
    factor = c(39.0, 38.4, 41.6, 44.2, 46.0, 45.0, 43.9, 54.8, 61.0, 65.5, 66.7, 72.3, 77.4, 78.1, 82.4, 101.0, 126.2, 125.8, 130.7, 133.4, 137.9, 170.6, 160.4, 153.0, 157.9, 149.3, 143.6, 146.2, 153.5, 162.0, 178.4, 180.8, 184.3)
  )
  dt[db, on = 'foto_mes', (campos) := lapply(.SD, function(x) x / i.factor), .SDcols = campos]
}

drift_dolaroficial <- function(dt, campos) {
  dof <- data.table(
    foto_mes = c(201901, 201902, 201903, 201904, 201905, 201906, 201907, 201908, 201909, 201910, 201911, 201912, 202001, 202002, 202003, 202004, 202005, 202006, 202007, 202008, 202009, 202010, 202011, 202012, 202101, 202102, 202103, 202104, 202105, 202106, 202107, 202108, 202109),
    factor = c(38.4, 39.4, 42.5, 44.3, 46.0, 44.9, 43.7, 54.6, 58.7, 61.4, 63.0, 63.0, 62.9, 63.5, 65.2, 67.8, 70.0, 72.5, 75.3, 77.4, 79.4, 83.1, 85.4, 88.1, 91.4, 93.9, 96.6, 98.5, 99.6, 100.6, 101.6, 102.5, 103.7)
  )
  dt[dof, on = 'foto_mes', (campos) := lapply(.SD, function(x) x / i.factor), .SDcols = campos]
}

drift_UVA <- function(dt, campos) {
  uva <- data.table(
    foto_mes = c(201901, 201902, 201903, 201904, 201905, 201906, 201907, 201908, 201909, 201910, 201911, 201912, 202001, 202002, 202003, 202004, 202005, 202006, 202007, 202008, 202009, 202010, 202011, 202012, 202101, 202102, 202103, 202104, 202105, 202106, 202107, 202108, 202109),
    factor = c(2.00, 1.95, 1.89, 1.82, 1.74, 1.68, 1.63, 1.59, 1.55, 1.49, 1.41, 1.36, 1.31, 1.26, 1.23, 1.21, 1.17, 1.15, 1.13, 1.11, 1.09, 1.06, 1.03, 1.00, 0.96, 0.93, 0.89, 0.86, 0.82, 0.79, 0.76, 0.74, 0.72)
  )
  dt[uva, on = 'foto_mes', (campos) := lapply(.SD, function(x) x * i.factor), .SDcols = campos]
}

drift_estandarizar <- function(dt, campos) {
  for (campo in campos) {
    if (campo %in% colnames(dt)) {
      dt[, paste0(campo, '_std') := (get(campo) - mean(get(campo), na.rm=TRUE)) / (sd(get(campo), na.rm=TRUE) + 1e-6), by = foto_mes]
    }
  }
}

# 8 Methods
metodos <- c('ninguno', 'rank_simple', 'rank_cero_fijo', 'deflacion', 'dolar_blue', 'dolar_oficial', 'UVA', 'estandarizar')

semillas_fijas <- c(401987, 456791, 607219, 701819, 811147)

tb_resultados <- data.table()

for (m in metodos) {
  cat('
=========================================
')
  cat('EVALUATING DATA DRIFTING METHOD:', m, '
')
  cat('=========================================
')
  
  dt_copy <- copy(dataset)
  
  switch(m,
    'ninguno'        = cat('No drift adjustment
'),
    'rank_simple'    = drift_rank_simple(dt_copy, campos_monetarios),
    'rank_cero_fijo' = drift_rank_cero_fijo(dt_copy, campos_monetarios),
    'deflacion'      = drift_deflacion(dt_copy, campos_monetarios),
    'dolar_blue'     = drift_dolarblue(dt_copy, campos_monetarios),
    'dolar_oficial'  = drift_dolaroficial(dt_copy, campos_monetarios),
    'UVA'            = drift_UVA(dt_copy, campos_monetarios),
    'estandarizar'   = drift_estandarizar(dt_copy, campos_monetarios)
  )
  
  # Target
  dt_copy[, clase01 := ifelse(clase_ternaria == 'BAJA+2', 1L, 0L)]
  
  # Feature columns
  campos_buenos <- copy(setdiff(colnames(dt_copy), c('numero_de_cliente', 'foto_mes', 'clase_ternaria', 'clase01', 'azar', 'peso')))
  
  # Validation set: 202107
  dval <- dt_copy[foto_mes == 202107]
  
  # Training set: 201901 to 202105
  dtrain_data <- dt_copy[foto_mes %in% c(201901:202105)]
  
  dtrain <- lgb.Dataset(
    data = data.matrix(dtrain_data[, campos_buenos, with = FALSE]),
    label = dtrain_data[, clase01],
    free_raw_data = FALSE
  )
  
  dvalid <- lgb.Dataset(
    data = data.matrix(dval[, campos_buenos, with = FALSE]),
    label = dval[, clase01],
    free_raw_data = FALSE
  )
  
  aucs <- c()
  
  # Evaluate across 5 fixed seeds
  for (sem in semillas_fijas) {
    param_lgb <- list(
      objective = 'binary',
      metric = 'auc',
      boosting = 'gbdt',
      max_bin = 31L,
      learning_rate = 0.025,
      num_iterations = 350,
      num_leaves = 31,
      min_data_in_leaf = 50,
      feature_fraction = 0.65,
      bagging_fraction = 0.85,
      bagging_freq = 1L,
      seed = sem,
      verbosity = -100
    )
    
    m_lgb <- lgb.train(
      data = dtrain,
      valids = list(val = dvalid),
      eval = 'auc',
      param = param_lgb,
      verbose = -100
    )
    
    auc_val <- m_lgb$record_evals$val$auc$eval[[350]]
    aucs <- c(aucs, auc_val)
  }
  
  auc_mean <- mean(aucs)
  auc_sd <- sd(aucs)
  
  cat('Method:', m, '--> 5-Seeds Mean AUC:', round(auc_mean, 6), '(SD:', round(auc_sd, 6), ')
')
  
  tb_resultados <- rbind(tb_resultados, data.table(
    metodo = m,
    auc_medio = auc_mean,
    auc_sd = auc_sd,
    auc_semilla_1 = aucs[1],
    auc_semilla_2 = aucs[2],
    auc_semilla_3 = aucs[3],
    auc_semilla_4 = aucs[4],
    auc_semilla_5 = aucs[5]
  ))
  
  rm(dt_copy)
  gc(full = TRUE, verbose = FALSE)
}

setorder(tb_resultados, -auc_medio)
dir.create('/Users/tomas/Dev/dm2026b/exp', showWarnings = FALSE)
fwrite(tb_resultados, file = '/Users/tomas/Dev/dm2026b/exp/benchmark_8_drifting_results.txt', sep = '	')

cat('
=========================================
')
cat('FINAL BENCHMARK RESULTS (RANKED BY MEAN AUC):
')
cat('=========================================
')
print(tb_resultados)

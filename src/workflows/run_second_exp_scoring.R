
library(data.table)
library(lightgbm)

exp_dir <- '/Users/tomas/Dev/dm2026b/exp/todas_sugerencias_BO_ensemble_y_sugerencia_antigrav'
setwd(exp_dir)

cat('Loading dataset...
')
dataset <- fread('/Users/tomas/Dev/dm2026b/datasets/analistajr_competencia_2026.csv.gz')
setorder(dataset, numero_de_cliente, foto_mes)

# 1. Catastrophe Analysis
cat('Running Catastrophe Analysis...
')
dataset[ foto_mes==202006, active_quarter := NA ]
dataset[ foto_mes==202006, mrentabilidad := NA ]
dataset[ foto_mes==202006, mrentabilidad_annual := NA ]
dataset[ foto_mes==202006, mcomisiones := NA ]
dataset[ foto_mes==202006, mactivos_margen := NA ]
dataset[ foto_mes==202006, mpasivos_margen := NA ]
dataset[ foto_mes==202006, mcuentas_saldo := NA ]

# 2. Antigravity FE Ratios
if ("mpayroll" %in% colnames(dataset)) {
  dataset[, mpayroll_sobre_edad := mpayroll / (cliente_edad + 1)]
}
if ("mcuentas_saldo" %in% colnames(dataset)) {
  dataset[, mcuentas_saldo_ratio3m := mcuentas_saldo / (shift(mcuentas_saldo, 3, NA, "lag") + 1), by = numero_de_cliente]
  dataset[, mcuentas_saldo_ratio6m := mcuentas_saldo / (shift(mcuentas_saldo, 6, NA, "lag") + 1), by = numero_de_cliente]
}

# 3. Data Drifting (dolar_oficial)
cat('Running Data Drifting (dolar_oficial)...
')
vdolar_oficial <- c(
   38.430000,  39.428000,  42.542105, 44.354211,  46.088636,  44.955000,
   43.751429,  54.650476,  58.790000, 61.403182,  63.012632,  63.011579,
   62.983636,  63.580556,  65.200000, 67.872000,  70.047895,  72.520952,
   75.324286,  77.488500,  79.430909, 83.134762,  85.484737,  88.181667,
   91.474000,  93.997778,  96.635909, 98.526000,  99.613158, 100.619048,
  101.619048, 102.569048, 103.781818
)
vfoto_mes <- c(201901:201912, 202001:202012, 202101:202109)
tb_dof <- data.table(foto_mes = vfoto_mes, i.dolar_oficial = vdolar_oficial)

campos_monetarios <- c('mrentabilidad', 'mrentabilidad_annual', 'mcomisiones', 'mactivos_margen', 'mpasivos_margen', 'mcuenta_corriente', 'mcaja_ahorro', 'mcuentas_saldo', 'mtarjeta_visa_consumo', 'mtarjeta_master_consumo', 'mprestamos_personales', 'mpayroll', 'mttarjeta_visa_debitos_automaticos', 'mcomisiones_mantenimiento', 'mtransferencias_recibidas', 'Master_mfinanciacion_limite', 'Master_msaldototal', 'Master_mlimitecompra', 'Master_mconsumototal', 'Master_mpagominimo', 'Visa_mfinanciacion_limite', 'Visa_msaldototal', 'Visa_mlimitecompra', 'Visa_mconsumototal', 'Visa_mpagominimo')

dataset[tb_dof, on = 'foto_mes', (campos_monetarios) := lapply(.SD, function(x) x / i.dolar_oficial), .SDcols = campos_monetarios]

# 4. Read exact feature names from model file
model_file <- './modelos/modelo_401987.txt'
m_lines <- readLines(model_file)
fn_line <- m_lines[grep('^feature_names=', m_lines)]
trained_features <- unlist(strsplit(sub('^feature_names=', '', fn_line), ' '))

cat('Trained feature count:', length(trained_features), '
')

# Check and generate missing features (Lags, Deltas, Canaritos)
set.seed(401987)
canarito_cols <- trained_features[grep('^canarito_', trained_features)]
for (c_name in canarito_cols) {
  if (!c_name %in% colnames(dataset)) {
    dataset[, (c_name) := rnorm(.N)]
  }
}

for (f in trained_features) {
  if (!f %in% colnames(dataset)) {
    if (endsWith(f, '_lag1')) {
      base_col <- sub('_lag1$', '', f)
      if (base_col %in% colnames(dataset)) {
        dataset[, (f) := shift(get(base_col), 1, NA, 'lag'), by = numero_de_cliente]
      }
    } else if (endsWith(f, '_lag2')) {
      base_col <- sub('_lag2$', '', f)
      if (base_col %in% colnames(dataset)) {
        dataset[, (f) := shift(get(base_col), 2, NA, 'lag'), by = numero_de_cliente]
      }
    } else if (endsWith(f, '_delta1')) {
      base_col <- sub('_delta1$', '', f)
      lag_col <- paste0(base_col, '_lag1')
      if (base_col %in% colnames(dataset) && lag_col %in% colnames(dataset)) {
        dataset[, (f) := get(base_col) - get(lag_col)]
      }
    } else if (endsWith(f, '_delta2')) {
      base_col <- sub('_delta2$', '', f)
      lag_col <- paste0(base_col, '_lag2')
      if (base_col %in% colnames(dataset) && lag_col %in% colnames(dataset)) {
        dataset[, (f) := get(base_col) - get(lag_col)]
      }
    }
  }
}

# 5. Scoring & 20-Seed Averaging on 202109
dfuture <- dataset[foto_mes == 202109]
datos_matrix <- data.matrix(dfuture[, trained_features, with = FALSE])

tb_prediccion <- dfuture[, list(numero_de_cliente)]
tb_prediccion[, prob := 0]

semillas <- c(
  401987, 456791, 607219, 701819, 811147,
  102191, 200003, 314159, 420042, 555555,
  618033, 777777, 888888, 999999, 123456,
  654321, 987654, 456123, 789321, 321654
)

for (isem in seq_along(semillas)) {
  sem <- semillas[isem]
  arch <- paste0('./modelos/modelo_', sem, '.txt')
  cat('Loading 20-seed model [', isem, '/20]:', arch, '
')
  m <- lgb.load(filename = arch)
  pred <- predict(m, datos_matrix)
  tb_prediccion[, paste0('prob_', isem) := pred]
  tb_prediccion[, prob := prob + pred]
}

tb_prediccion[, prob := prob / length(semillas)]
fwrite(tb_prediccion, file = 'prediccion.txt', sep = '	')
cat('Saved 20-seed prediccion.txt successfully!
')

# 6. Kaggle Submission CSVs
dir.create('kaggle', showWarnings = FALSE)
setorder(tb_prediccion, -prob)

cortes <- seq(9000, 13000, by = 500)
for (corte in cortes) {
  tb_prediccion[, Predicted := 0L]
  tb_prediccion[1:corte, Predicted := 1L]
  arch_kaggle <- paste0('./kaggle/submission_', corte, '.csv')
  fwrite(tb_prediccion[, list(numero_de_cliente, Predicted)], file = arch_kaggle, sep = ',')
  cat('Generated:', arch_kaggle, '
')
}

cat('ALL 20-SEED KAGGLE SUBMISSIONS GENERATED CLEANLY!
')

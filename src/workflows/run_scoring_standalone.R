
library(data.table)
library(lightgbm)
library(yaml)

exp_dir <- '/Users/tomas/Dev/dm2026b/exp/WFjunior_rank_cero_fijo_semilla_primigenia_BO_ensemble'
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
dataset[ foto_mes==202006, ctarjeta_visa_transacciones := NA ]
dataset[ foto_mes==202006, mtarjeta_visa_consumo := NA ]
dataset[ foto_mes==202006, ctarjeta_master_transacciones := NA ]
dataset[ foto_mes==202006, mtarjeta_master_consumo := NA ]
dataset[ foto_mes==202006, ccomisiones_mantenimiento := NA ]
dataset[ foto_mes==202006, mcomisiones_mantenimiento := NA ]
dataset[ foto_mes==202006, ccomisiones_otras := NA ]
dataset[ foto_mes==202006, mcomisiones_otras := NA ]
dataset[ foto_mes==202006, cforex := NA ]
dataset[ foto_mes==202006, cforex_buy := NA ]
dataset[ foto_mes==202006, mforex_buy := NA ]
dataset[ foto_mes==202006, cforex_sell := NA ]
dataset[ foto_mes==202006, mforex_sell := NA ]
dataset[ foto_mes==202006, ctransferencias_recibidas := NA ]
dataset[ foto_mes==202006, mtransferencias_recibidas := NA ]
dataset[ foto_mes==202006, ctransferencias_emitidas := NA ]
dataset[ foto_mes==202006, mtransferencias_emitidas := NA ]
dataset[ foto_mes==202006, ccheques_depositados := NA ]
dataset[ foto_mes==202006, mcheques_depositados := NA ]
dataset[ foto_mes==202006, ccheques_emitidos := NA ]
dataset[ foto_mes==202006, mcheques_emitidos := NA ]
dataset[ foto_mes==202006, ccheques_depositados_rechazados := NA ]
dataset[ foto_mes==202006, mcheques_depositados_rechazados := NA ]
dataset[ foto_mes==202006, ccheques_emitidos_rechazados := NA ]
dataset[ foto_mes==202006, mcheques_emitidos_rechazados := NA ]
dataset[ foto_mes==202006, tcallcenter := NA ]
dataset[ foto_mes==202006, ccallcenter_transacciones := NA ]
dataset[ foto_mes==202006, thomebanking := NA ]
dataset[ foto_mes==202006, chomebanking_transacciones := NA ]
dataset[ foto_mes==202006, ccajas_transacciones := NA ]
dataset[ foto_mes==202006, ccajas_consultas := NA ]
dataset[ foto_mes==202006, ccajas_depositos := NA ]
dataset[ foto_mes==202006, ccajas_extracciones := NA ]
dataset[ foto_mes==202006, ccajas_other := NA ]
dataset[ foto_mes==202006, catm_trx := NA ]
dataset[ foto_mes==202006, matm := NA ]
dataset[ foto_mes==202006, catm_trx_other := NA ]
dataset[ foto_mes==202006, matm_other := NA ]
dataset[ foto_mes==202006, tmarcadodequinta := NA ]
dataset[ foto_mes==202006, mtarjeta_visa_descuentos := NA ]
dataset[ foto_mes==202006, mtarjeta_master_descuentos := NA ]
dataset[ foto_mes==202006, ccuenta_debitos_automaticos := NA ]
dataset[ foto_mes==202006, mcuenta_debitos_automaticos := NA ]
dataset[ foto_mes==202006, ctarjeta_visa_debitos_automaticos := NA ]
dataset[ foto_mes==202006, mttarjeta_visa_debitos_automaticos := NA ]
dataset[ foto_mes==202006, ctarjeta_master_debitos_automaticos := NA ]
dataset[ foto_mes==202006, mttarjeta_master_debitos_automaticos := NA ]

# 2. Data Drifting (rank_cero_fijo)
cat('Running Data Drifting (rank_cero_fijo)...
')
drift_rank_cero_fijo <- function(campos_drift) {
  for (campo in campos_drift) {
    if (campo %in% colnames(dataset)) {
      dataset[, paste0(campo, '_rank') := ifelse(get(campo) == 0, 0, frankv(get(campo), ties.method = 'dense', na.last = 'keep') / .N), by = foto_mes]
    }
  }
}
campos_monetarios <- c('mrentabilidad', 'mrentabilidad_annual', 'mcomisiones', 'mactivos_margen', 'mpasivos_margen', 'mcuenta_corriente', 'mcaja_ahorro', 'mcuentas_saldo', 'mtarjeta_visa_consumo', 'mtarjeta_master_consumo', 'mprestamos_personales', 'mpayroll', 'mttarjeta_visa_debitos_automaticos', 'mcomisiones_mantenimiento', 'mtransferencias_recibidas', 'Master_mfinanciacion_limite', 'Master_msaldototal', 'Master_mlimitecompra', 'Master_mconsumototal', 'Master_mpagominimo', 'Visa_mfinanciacion_limite', 'Visa_msaldototal', 'Visa_mlimitecompra', 'Visa_mconsumototal', 'Visa_mpagominimo')
drift_rank_cero_fijo(campos_monetarios)

dataset[, mpayroll_sobre_edad := mpayroll / cliente_edad]

# Read exact feature names from model_401987.txt
model_file <- './modelos/modelo_401987.txt'
m_lines <- readLines(model_file)
fn_line <- m_lines[grep('^feature_names=', m_lines)]
trained_features <- unlist(strsplit(sub('^feature_names=', '', fn_line), ' '))

cat('Trained feature count:', length(trained_features), '
')

# Check missing features and generate them
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

dfuture <- dataset[foto_mes == 202109]
datos_matrix <- data.matrix(dfuture[, trained_features, with = FALSE])

tb_prediccion <- dfuture[, list(numero_de_cliente)]
tb_prediccion[, prob := 0]

semillas <- c(401987, 456791, 607219, 701819, 811147)

for (isem in seq_along(semillas)) {
  sem <- semillas[isem]
  arch <- paste0('./modelos/modelo_', sem, '.txt')
  cat('Loading model:', arch, '
')
  m <- lgb.load(filename = arch)
  pred <- predict(m, datos_matrix)
  tb_prediccion[, paste0('prob_', isem) := pred]
  tb_prediccion[, prob := prob + pred]
}

tb_prediccion[, prob := prob / length(semillas)]
fwrite(tb_prediccion, file = 'prediccion.txt', sep = '	')
cat('Saved prediccion.txt successfully!
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

cat('ALL KAGGLE SUBMISSIONS GENERATED CLEANLY!
')

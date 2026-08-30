import os, sys, json

nb_path_dev = "/Users/tomas/Dev/dm2026b/src/workflows/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb"
nb_path_dl = "/Users/tomas/Downloads/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb"

base_nb_path = "/Users/tomas/Dev/dm2026b/src/workflows/primer intento con todas las sugerencias y BO y ensemble.ipynb"
with open(base_nb_path, "r", encoding="utf-8") as f:
    nb = json.load(f)

# 1. Update experiment name and paths in Cell 11
cell_11_code = """# 1. Configuración Inicial del Experimento
PARAM <- list()
PARAM$semilla_primigenia <- 401987
PARAM$experimento <- "todas_sugerencias_BO_ensemble_y_sugerencia_antigrav"
PARAM$path_output <- "/Users/tomas/Dev/dm2026b/exp/todas_sugerencias_BO_ensemble_y_sugerencia_antigrav"

dir.create(PARAM$path_output, showWarnings = FALSE, recursive = TRUE)
setwd(PARAM$path_output)

cat("Directorio de trabajo configurado en:", getwd(), "\\n")
"""
nb['cells'][11]['source'] = [cell_11_code]

# Fix Colab setwd and datasets paths
for idx, cell in enumerate(nb['cells']):
    src = ''.join(cell['source'])
    if 'setwd("/content/buckets' in src or "setwd('/content/buckets" in src:
        nb['cells'][idx]['source'] = ['# setwd for Colab overridden locally\n', 'setwd(PARAM$path_output)\n']
    if 'fread(paste0("/content/datasets/' in src or "fread(paste0('/content/datasets/" in src or 'fread("/content/datasets/' in src:
        nb['cells'][idx]['source'] = ['dataset <- fread("/Users/tomas/Dev/dm2026b/datasets/analistajr_competencia_2026.csv.gz")\n']

# 2. Insert Antigravity FE ratios BEFORE Data Drifting
cell_fe_antigrav = """# Feature Engineering Avanzado (Antigravity: Ratios y Tendencias 3m/6m)
cat("Generando Feature Engineering Avanzado (Antigravity)...\n")
if ("mpayroll" %in% colnames(dataset)) {
  dataset[, mpayroll_sobre_edad := mpayroll / (cliente_edad + 1)]
}
if ("mcuentas_saldo" %in% colnames(dataset)) {
  dataset[, mcuentas_saldo_ratio3m := mcuentas_saldo / (shift(mcuentas_saldo, 3, NA, "lag") + 1), by = numero_de_cliente]
  dataset[, mcuentas_saldo_ratio6m := mcuentas_saldo / (shift(mcuentas_saldo, 6, NA, "lag") + 1), by = numero_de_cliente]
}
"""

# Set Data Drifting to WINNER METHOD: dolar_oficial (AUC 0.901165)
for idx, cell in enumerate(nb['cells']):
    src = ''.join(cell['source'])
    if 'PARAM$DR$metodo' in src:
        new_dr = src.replace('PARAM$DR$metodo <- "rank_cero_fijo"', 'PARAM$DR$metodo <- "dolar_oficial"')
        new_dr = new_dr.replace('PARAM$DR$metodo <- "deflacion"', 'PARAM$DR$metodo <- "dolar_oficial"')
        nb['cells'][idx]['source'] = [cell_fe_antigrav + "\n" + new_dr]
        break

# Fix function call in Data Drifting switch case if needed
for idx, cell in enumerate(nb['cells']):
    src = ''.join(cell['source'])
    if 'switch( PARAM$DR$metodo' in src or 'switch(PARAM$DR$metodo' in src:
        new_sw = src.replace('"dolar_oficial"  = drift_dolaroficial(', '"dolar_oficial"  = drift_dolar_oficial(')
        new_sw = new_sw.replace('"dolar_oficial" = drift_dolaroficial(', '"dolar_oficial" = drift_dolar_oficial(')
        nb['cells'][idx]['source'] = [new_sw]

# 3. Add Canaritos Asesinos in FE Histórico cell
cell_fe_hist_code = """# 4. Feature Engineering Histórico + Inyección de Canaritos Asesinos
cat("Generando Lags, Deltas y Canaritos Asesinos...\n")
cols_lagueables <- copy(setdiff(colnames(dataset), c("numero_de_cliente", "foto_mes", "clase_ternaria")))

dataset[, paste0(cols_lagueables, "_lag1") := shift(.SD, 1, NA, "lag"), by = numero_de_cliente, .SDcols = cols_lagueables]
for (v in cols_lagueables) {
  dataset[, paste0(v, "_delta1") := get(v) - get(paste0(v, "_lag1"))]
}

dataset[, paste0(cols_lagueables, "_lag2") := shift(.SD, 2, NA, "lag"), by = numero_de_cliente, .SDcols = cols_lagueables]
for (v in cols_lagueables) {
  dataset[, paste0(v, "_delta2") := get(v) - get(paste0(v, "_lag2"))]
}

# Inyección de Canaritos Asesinos (30 variables de ruido N(0,1))
set.seed(PARAM$semilla_primigenia)
for (i in 1:30) {
  dataset[, paste0("canarito_", i) := rnorm(.N)]
}

cat("Total de columnas tras FE + Canaritos:", ncol(dataset), "\n")
"""
for idx, cell in enumerate(nb['cells']):
    src = ''.join(cell['source'])
    if 'shift(.SD, 1, NA' in src:
        nb['cells'][idx]['source'] = [cell_fe_hist_code]
        break

# 4. Enable extra_trees = TRUE in BO parameters (Cell 67)
for idx, cell in enumerate(nb['cells']):
    src = ''.join(cell['source'])
    if 'PARAM$lgbm$param_fijos' in src:
        new_fijos = src.replace('extra_trees = FALSE', 'extra_trees = TRUE')
        nb['cells'][idx]['source'] = [new_fijos]
        break

# Save to Dev and Downloads
with open(nb_path_dev, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2)

with open(nb_path_dl, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2)

print(f"Notebook fixed and saved in:\n1. {nb_path_dev}\n2. {nb_path_dl}")

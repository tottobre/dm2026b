import json
import copy

base_clean_path = "/Users/tomas/Dev/dm2026b/src/workflows/z910_WorkFlow_01_junior.ipynb"
dst_downloads = "/Users/tomas/Downloads/primer intento con todas las sugerencias y BO y ensemble.ipynb"
dst_dev = "/Users/tomas/Dev/dm2026b/src/workflows/primer intento con todas las sugerencias y BO y ensemble.ipynb"
out_r = "/Users/tomas/Dev/dm2026b/src/workflows/z910_primer_intento_sugerencias.R"

with open(base_clean_path, "r", encoding="utf-8") as f:
    nb = json.load(f)

# 1. Update Cell 11: Primigenia seed 401987 & Experiment Title
nb["cells"][11]["source"] = [
    "PARAM <- list()\n",
    "PARAM$semilla_primigenia <- 401987\n",
    "\n",
    "PARAM$experimento <- \"primer_intento_sugerencias_BO_ensemble\"\n",
    "PARAM$dataset <- \"analistajr_competencia_2026.csv.gz\"\n"
]

# 2. Update Cell 38: Data Drifting rank_cero_fijo
c38_fixed = [
    "# ejecuto el Data Drifting\n",
    "setorder( dataset, numero_de_cliente, foto_mes )\n",
    "\n",
    "\n",
    "PARAM$DR$metodo <- \"rank_cero_fijo\"\n",
    "\n",
    "switch(PARAM$DR$metodo,\n",
    "  \"ninguno\"        = cat(\"No hay correccion del data drifting\"),\n",
    "  \"rank_simple\"    = drift_rank_simple(campos_monetarios),\n",
    "  \"rank_cero_fijo\" = drift_rank_cero_fijo(campos_monetarios),\n",
    "  \"deflacion\"      = drift_deflacion(campos_monetarios),\n",
    "  \"dolar_blue\"     = drift_dolarblue(campos_monetarios),\n",
    "  \"dolar_oficial\"  = drift_dolaroficial(campos_monetarios),\n",
    "  \"UVA\"            = drift_UVA(campos_monetarios),\n",
    "  \"estandarizar\"   = drift_estandarizar(campos_monetarios)\n",
    ")\n"
]
nb["cells"][38]["source"] = c38_fixed

# 3. Update Cell 57: Training Strategy (Exclude pandemia shock months 202003, 202004, 202005, 202006)
c57_training_strategy = [
    "PARAM$trainingstrategy$validate <- c(202107)\n",
    "\n",
    "# Excluimos los meses de shock de pandemia (202003, 202004, 202005, 202006) según sugerencia del Grupo A y B\n",
    "PARAM$trainingstrategy$training <- c(\n",
    "  201901, 201902, 201903, 201904, 201905, 201906,\n",
    "  201907, 201908, 201909, 201910, 201911, 201912,\n",
    "  202001, 202002,\n",
    "  202007, 202008, 202009, 202010, 202011, 202012,\n",
    "  202101, 202102, 202103, 202104, 202105\n",
    ")\n",
    "\n",
    "PARAM$trainingstrategy$training_pct <- 1.0\n",
    "PARAM$trainingstrategy$positivos <- c(\"BAJA+1\", \"BAJA+2\")\n"
]
nb["cells"][57]["source"] = c57_training_strategy

# 4. Update Cell 67: BO Optimization (mlrMBO)
bo_code = [
    "# 1. Cargamos las librerías necesarias para mlrMBO y DiceKriging\n",
    "if(!require(\"DiceKriging\")) install.packages(\"DiceKriging\")\n",
    "require(\"DiceKriging\")\n",
    "\n",
    "if(!require(\"mlrMBO\")) install.packages(\"mlrMBO\")\n",
    "require(\"mlrMBO\")\n",
    "\n",
    "# 2. Definimos las iteraciones inteligentes (30 iteraciones)\n",
    "PARAM$hipeparametertuning$num_interations <- 30\n",
    "\n",
    "# 3. Parámetros fijos de LightGBM (Configuración limpia para optimizar)\n",
    "PARAM$lgbm$param_fijos <- list(\n",
    "  objective= \"binary\",\n",
    "  metric= \"auc\",\n",
    "  first_metric_only= TRUE,\n",
    "  boost_from_average= TRUE,\n",
    "  feature_pre_filter= FALSE,\n",
    "  verbosity= -100,\n",
    "  force_row_wise= TRUE,\n",
    "  seed= PARAM$semilla_primigenia,\n",
    "  extra_trees= FALSE,\n",
    "  max_depth= -1L,\n",
    "  min_data_in_leaf= 0,\n",
    "  bagging_fraction= 1.0,\n",
    "  pos_bagging_fraction= 1.0,\n",
    "  neg_bagging_fraction= 1.0,\n",
    "  is_unbalance= FALSE,\n",
    "  scale_pos_weight= 1.0,\n",
    "  drop_rate= 0.1,\n",
    "  max_drop= 50,\n",
    "  skip_drop= 0.5,\n",
    "  max_bin= 31,\n",
    "  early_stopping_rounds= 0\n",
    ")\n",
    "\n",
    "# 4. Definimos el espacio de búsqueda (Hs) exponencial + regularizadores de clase\n",
    "PARAM$hipeparametertuning$hs <- makeParamSet(\n",
    "  makeNumericParam(\"num_iterations\", lower= 2.0, upper= 10.0, trafo= function(x) round(2^x) ),\n",
    "  makeNumericParam(\"num_leaves\", lower= 2.0, upper= 11.0, trafo= function(x) round(2^x) ),\n",
    "  makeNumericParam(\"learning_rate\", lower= -7.0, upper= -0.1, trafo= function(x) 2^x ),\n",
    "  makeNumericParam(\"feature_fraction\", lower= 0.05, upper= 0.90),\n",
    "  makeNumericParam(\"min_sum_hessian_in_leaf\", lower= -10.0, upper= 10.0, trafo= function(x) 2^x),\n",
    "  \n",
    "  makeNumericParam(\"lambda_l1\", lower= 0.0, upper= 600.0),\n",
    "  makeNumericParam(\"lambda_l2\", lower= 0.0, upper= 600.0),\n",
    "  makeNumericParam(\"min_gain_to_split\", lower= 0.0, upper= 20.0)\n",
    ")\n",
    "\n",
    "# 5. Función de evaluación Caja Negra (AUC en Validación)\n",
    "EstimarGanancia_AUC_lightgbm <- function(x) {\n",
    "  param_completo <- modifyList(PARAM$lgbm$param_fijos, x)\n",
    "  modelo_train <- lgb.train(\n",
    "    data= dtrain,\n",
    "    valids= list(valid = dvalidate),\n",
    "    eval= \"auc\",\n",
    "    param= param_completo,\n",
    "    verbose= -100\n",
    "  )\n",
    "  AUC <- modelo_train$record_evals$valid$auc$eval[[x$num_iterations]]\n",
    "  message(format(Sys.time(), \"%a %b %d %X %Y \"),\n",
    "    toString(x),\n",
    "    \" AUC \", AUC\n",
    "  )\n",
    "  rm(modelo_train)\n",
    "  gc(full= TRUE, verbose= FALSE)\n",
    "  return(AUC)\n",
    "}\n",
    "\n",
    "# 6. Configuración interna del optimizador Bayesiano\n",
    "configureMlr(show.learner.output = FALSE)\n",
    "obj.fun <- makeSingleObjectiveFunction(\n",
    "    fn= EstimarGanancia_AUC_lightgbm,\n",
    "    minimize= FALSE,\n",
    "    noisy= FALSE,\n",
    "    par.set= PARAM$hipeparametertuning$hs,\n",
    "    has.simple.signature= FALSE\n",
    ")\n",
    "\n",
    "ctrl <- makeMBOControl(\n",
    "    save.on.disk.at.time= 600,\n",
    "    save.file.path= \"HT.RDATA\"\n",
    ")\n",
    "ctrl <- setMBOControlTermination(\n",
    "    ctrl,\n",
    "    iters= PARAM$hipeparametertuning$num_interations\n",
    ")\n",
    "ctrl <- setMBOControlInfill(ctrl, crit = makeMBOInfillCritEI())\n",
    "\n",
    "surr.km <- makeLearner(\n",
    "    \"regr.km\",\n",
    "    predict.type= \"se\",\n",
    "    covtype= \"matern3_2\",\n",
    "    control= list(trace = TRUE)\n",
    ")\n",
    "\n",
    "# 7. Ejecución de la Optimización Bayesiana (con checkpoint HT.RDATA)\n",
    "if (!file.exists(\"HT.RDATA\")) {\n",
    "  bayesiana_salida <- mbo(obj.fun, learner= surr.km, control= ctrl)\n",
    "} else {\n",
    "  bayesiana_salida <- mboContinue(\"HT.RDATA\")\n",
    "}\n",
    "\n",
    "# 8. Extraemos y guardamos en disco el log ordenado por mejor rendimiento\n",
    "tb_bayesiana <- as.data.table(bayesiana_salida$opt.path)\n",
    "setorder(tb_bayesiana, -y, -num_iterations)\n",
    "fwrite(tb_bayesiana, file=\"BO_log.txt\", sep=\"\\t\")\n",
    "\n",
    "# Guardamos el registro ganador (AUC más alta) en mejores_hiperparametros\n",
    "PARAM$out$lgbm$mejores_hiperparametros <- tb_bayesiana[\n",
    "  1,\n",
    "  setdiff(colnames(tb_bayesiana),\n",
    "    c(\"y\",\"dob\",\"eol\",\"error.message\",\"exec.time\",\"ei\",\"error.model\",\n",
    "      \"train.time\",\"prop.type\",\"propose.time\",\"se\",\"mean\",\"iter\")),\n",
    "  with= FALSE\n",
    "]\n",
    "\n",
    "print(PARAM$out$lgbm$mejores_hiperparametros)\n"
]
nb["cells"][67]["source"] = bo_code

# 5. Replace cells 78 to 87 with Semillerío + param_final definition
c_78 = {
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "##### Training con Ensemble de Semillas (Semillerío)\n",
        "Se entrenan N modelos cambiando la semilla y se guardan en disco."
    ]
}

c_79 = {
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "# Definimos param_final uniendo hiperparámetros fijos + hiperparámetros óptimos de la BO\n",
        "param_final <- modifyList(\n",
        "  PARAM$lgbm$param_fijos,\n",
        "  as.list(PARAM$out$lgbm$mejores_hiperparametros)\n",
        ")\n",
        "\n",
        "# Definimos las 5 semillas fijas de la cátedra para el semillerío\n",
        "PARAM$FT$semillas <- c(401987, 456791, 607219, 701819, 811147)\n",
        "PARAM$FT$semillerio <- length(PARAM$FT$semillas)\n",
        "\n",
        "dir.create(\"modelos\", showWarnings = FALSE)\n",
        "primero <- TRUE\n",
        "\n",
        "crear_modelo_final <- function(sem) {\n",
        "  nombre_arch <- paste0(\"./modelos/modelo_\", sem, \".txt\")\n",
        "  if (!file.exists(nombre_arch)) {\n",
        "    param_final$seed <- sem\n",
        "    set.seed(sem, kind = \"L'Ecuyer-CMRG\")\n",
        "    \n",
        "    final_model <- lgb.train(\n",
        "      data = dfinal_train,\n",
        "      param = param_final,\n",
        "      verbose = -100\n",
        "    )\n",
        "    \n",
        "    lgb.save(final_model, nombre_arch)\n",
        "    \n",
        "    if (primero) {\n",
        "      primero <<- FALSE\n",
        "      tb_importancia <- as.data.table(lgb.importance(final_model))\n",
        "      fwrite(tb_importancia, file = \"impo.txt\", sep = \"\\t\")\n",
        "    }\n",
        "  }\n",
        "}\n",
        "\n",
        "gc(full = TRUE, verbose = FALSE)\n",
        "primero <- TRUE\n",
        "for (sem in PARAM$FT$semillas) crear_modelo_final(sem)\n"
    ]
}

c_80 = {
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "#### Scoring & Seed Averaging\n",
        "Aplicamos los N modelos finales a los datos del futuro y promediamos las probabilidades (Seed Averaging)."
    ]
}

c_81 = {
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "PARAM$trainingstrategy$future <- c(202109)\n",
        "dfuture <- dataset[foto_mes %in% PARAM$trainingstrategy$future]\n",
        "datos_matrix <- data.matrix(dfuture[, campos_buenos, with = FALSE])\n",
        "\n",
        "tb_prediccion <- dfuture[, list(numero_de_cliente)]\n",
        "tb_prediccion[, prob := 0]\n",
        "\n",
        "# Proceso de Seed Averaging: acumulamos probabilidades de las 5 semillas\n",
        "for (isem in seq(length(PARAM$FT$semillas))) {\n",
        "  sem <- PARAM$FT$semillas[isem]\n",
        "  nombre_arch <- paste0(\"./modelos/modelo_\", sem, \".txt\")\n",
        "  \n",
        "  final_model <- lgb.load(nombre_arch)\n",
        "  prediccion <- predict(final_model, datos_matrix)\n",
        "  \n",
        "  tb_prediccion[, paste0(\"prob_\", isem) := prediccion]\n",
        "  tb_prediccion[, prob := prob + prediccion]\n",
        "  \n",
        "  rm(final_model)\n",
        "  rm(prediccion)\n",
        "  gc(full = TRUE, verbose = FALSE)\n",
        "}\n",
        "\n",
        "rm(datos_matrix)\n",
        "gc(full = TRUE, verbose = FALSE)\n",
        "\n",
        "# Promediamos dividiendo por la cantidad de semillas\n",
        "tb_prediccion[, prob := prob / length(PARAM$FT$semillas)]\n",
        "\n",
        "# Grabamos la predicción final ensembleada\n",
        "fwrite(tb_prediccion, file = \"prediccion.txt\", sep = \"\\t\")\n"
    ]
}

new_ensemble_cells = nb["cells"][:78] + [c_78, c_79, c_80, c_81] + nb["cells"][88:]
nb["cells"] = new_ensemble_cells

with open(dst_downloads, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2, ensure_ascii=False)

with open(dst_dev, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2, ensure_ascii=False)

# Rebuild R script
r_code = ["# Auto-generated executable R script for primer intento con todas las sugerencias\n"]

for i, cell in enumerate(nb["cells"]):
    if cell["cell_type"] == "code":
        source = "".join(cell["source"])
        source = source.replace("/content/buckets/b1/exp", "/Users/tomas/Dev/dm2026b/exp")
        source = source.replace("/content/datasets/", "/Users/tomas/Dev/dm2026b/datasets/")
        r_code.append(f"# --- CELL {i} ---")
        r_code.append(source)
        r_code.append("\n")

with open(out_r, "w", encoding="utf-8") as f:
    f.write("\n".join(r_code))

print("FIXED SUGGESTIONS SCRIPT GENERATED SUCCESSFULLY!")

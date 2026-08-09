# z420_ArbolesAzarosos — ejecucion local (Mac) CON CHECKPOINT/RESUME

rm(list=ls(all.names=TRUE))
gc(full=TRUE, verbose=FALSE)

require("data.table")
require("rpart")

# --- Parametros ---
PARAM <- list()
PARAM$semilla_primigenia <- 401987
PARAM$feature_fraction <- 0.5
PARAM$rpart$cp <- -1
PARAM$rpart$minsplit <- 600
PARAM$rpart$minbucket <- 120
PARAM$rpart$maxdepth <- 9
PARAM$num_trees_max <- 512

base_dir <- "/Users/tomas/Dev/dm2026b"
exp_dir <- file.path(base_dir, "exp", "z420")
dir.create(exp_dir, showWarnings = FALSE, recursive = TRUE)
setwd(exp_dir)

grabar <- c(1, 2, 4, 8, 16, 32, 64, 128, 256, 384, 512)

# --- Checkpoint: intentar cargar estado previo ---
ckpt_file <- "z420_checkpoint.rds"
start_tree <- 1

if (file.exists(ckpt_file)) {
  ckpt <- readRDS(ckpt_file)
  tb_prediccion <- ckpt$tb_prediccion
  start_tree <- ckpt$last_tree + 1
  cat("Resume desde arbol", start_tree, "\n")
} else {
  dataset <- fread(file.path(base_dir, "datasets", "dataset_pequeno.csv"))
  dtrain <- dataset[foto_mes == 202107]
  dfuture <- dataset[foto_mes == 202109]
  dfuture[, clase_ternaria := NA]
  
  # Guardar para futuros resumes
  saveRDS(list(dtrain = dtrain, dfuture = dfuture), "z420_data.rds")
  
  tb_prediccion <- dfuture[, list(numero_de_cliente)]
  tb_prediccion[, prob_acumulada := 0]
}

# Cargar datos si no estan en memoria
if (!exists("dtrain")) {
  dat <- readRDS("z420_data.rds")
  dtrain <- dat$dtrain
  dfuture <- dat$dfuture
}

campos_buenos <- copy(setdiff(colnames(dtrain), c("clase_ternaria")))
set.seed(PARAM$semilla_primigenia)

cat("Inicio:", format(Sys.time(), "%a %b %d %X %Y"), "\n")
cat("Arrancando desde arbol:", start_tree, "/", PARAM$num_trees_max, "\n\n")

# --- Si estamos resumiendo, necesito recrear el estado de RNG ---
# Re-corremos set.seed y consumimos los arboles ya hechos
if (start_tree > 1) {
  set.seed(PARAM$semilla_primigenia)
  for (i in seq_len(start_tree - 1)) {
    qty <- as.integer(length(campos_buenos) * PARAM$feature_fraction)
    sample(campos_buenos, qty)  # consumir el sample
  }
}

for (arbolito in seq(start_tree, PARAM$num_trees_max)) {
  message(arbolito, " ", appendLF = FALSE)
  
  qty_campos_a_utilizar <- as.integer(length(campos_buenos) * PARAM$feature_fraction)
  campos_random <- sample(campos_buenos, qty_campos_a_utilizar)
  campos_random <- paste(campos_random, collapse = " + ")
  formulita <- paste0("clase_ternaria ~ ", campos_random)
  
  modelo <- rpart(formulita,
    data = dtrain,
    xval = 0,
    control = PARAM$rpart
  )
  
  prediccion <- predict(modelo, dfuture, type = "prob")
  tb_prediccion[, prob_acumulada := prob_acumulada + prediccion[, "BAJA+2"]]
  
  if (arbolito %in% grabar) {
    umbral_corte <- (1 / 40) * arbolito
    tb_prediccion[, Predicted := as.numeric(prob_acumulada > umbral_corte)]
    
    archivo_kaggle <- paste0("KA420_", sprintf("%.3d", arbolito), ".csv")
    
    fwrite(tb_prediccion[, list(numero_de_cliente, Predicted)],
      file = archivo_kaggle, sep = ","
    )
    
    # Guardar checkpoint para resume
    saveRDS(list(tb_prediccion = tb_prediccion, last_tree = arbolito), ckpt_file)
    
    cat("\n-> Grabado:", archivo_kaggle, "| checkpoint:", arbolito, "\n")
  }
}

cat("\nFin:", format(Sys.time(), "%a %b %d %X %Y"), "\n")
cat("Archivos en:", exp_dir, "\n")

# Limpiar checkpoint al terminar
if (file.exists(ckpt_file)) file.remove(ckpt_file)

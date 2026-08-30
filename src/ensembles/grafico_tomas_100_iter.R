# grafico_tomas_100_iter.R
# Curva de aprendizaje de Tomas exactamente a 100 iteraciones (mismo rango que el primer gráfico de Santiago)

rm(list = ls(all.names = TRUE))
gc(full = TRUE, verbose = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(lightgbm)
})

dir_base <- "/Users/tomas/dev/dm2026b"
dataset <- fread(file.path(dir_base, "datasets/dataset_pequeno.csv"), stringsAsFactors = TRUE)
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+1", "BAJA+2"), 1L, 0L)]
campos_buenos <- setdiff(colnames(dataset), c("clase_ternaria", "clase01"))

dataset_train <- dataset[foto_mes == 202107]

PARAM <- list()
PARAM$semillas <- c(401987, 456791, 607219, 701819, 811147)

param_curva <- list(
  objective        = "binary",
  metric           = "auc",
  boosting         = "gbdt",
  max_bin          = 31L,
  learning_rate    = 0.018,
  num_leaves       = 24,
  min_data_in_leaf = 50,
  feature_fraction = 0.65,
  bagging_fraction = 0.85,
  bagging_freq     = 1L,
  lambda_l1        = 0.5,
  lambda_l2        = 5.0,
  force_row_wise   = TRUE,
  verbosity        = -100
)

X_mat <- data.matrix(dataset_train[, campos_buenos, with = FALSE])
y_vec <- as.numeric(dataset_train[, clase01])

n_samples  <- nrow(X_mat)
train_size <- floor(0.8 * n_samples)

evals_list    <- vector("list", length(PARAM$semillas))
resumen_curva <- vector("list", length(PARAM$semillas))

cat("Entrenando tus 5 semillas a 100 iteraciones...\n")

for (isem in seq_along(PARAM$semillas)) {
  semilla_actual <- PARAM$semillas[isem]
  set.seed(semilla_actual, kind = "L'Ecuyer-CMRG")
  idx <- sample.int(n_samples, train_size)

  dtr <- lgb.Dataset(data = X_mat[idx, , drop = FALSE], label = y_vec[idx])
  dva <- lgb.Dataset(data = X_mat[-idx, , drop = FALSE], label = y_vec[-idx], reference = dtr)

  modelo_curva <- lgb.train(
    data    = dtr,
    valids  = list(valid = dva, train = dtr),
    param   = param_curva,
    nrounds = 100,
    verbose = -100
  )

  evals     <- modelo_curva$record_evals
  auc_train <- unlist(evals$train$auc$eval)
  auc_valid <- unlist(evals$valid$auc$eval)

  evals_list[[isem]] <- data.table(
    semilla = semilla_actual,
    iter    = seq_along(auc_train),
    train   = auc_train,
    valid   = auc_valid
  )

  resumen_curva[[isem]] <- data.table(
    semilla        = semilla_actual,
    best_iter      = modelo_curva$best_iter,
    auc_valid_best = max(auc_valid)
  )

  rm(dtr, dva, modelo_curva)
  gc(full = TRUE, verbose = FALSE)
}

dt_evals <- rbindlist(evals_list)
dt_long <- melt(dt_evals, id.vars = c("semilla", "iter"), variable.name = "split", value.name = "auc")

dt_summary <- dt_long[, .(
  mean_auc = mean(auc, na.rm = TRUE),
  sd_auc   = sd(auc, na.rm = TRUE)
), by = .(iter, split)]

dt_summary[, upper := mean_auc + sd_auc]
dt_summary[, lower := mean_auc - sd_auc]

resumen_curva  <- rbindlist(resumen_curva)
mean_best_iter <- mean(resumen_curva$best_iter)

p <- ggplot(dt_summary, aes(x = iter, y = mean_auc, color = split, fill = split)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, color = NA) +
  geom_line(linewidth = 1.1) +
  geom_vline(
    xintercept = mean_best_iter,
    linetype   = "dashed",
    color      = "darkgreen",
    linewidth  = 0.9
  ) +
  scale_color_manual(values = c("train" = "#D9534F", "valid" = "#0275D8")) +
  scale_fill_manual(values  = c("train" = "#D9534F", "valid" = "#0275D8")) +
  labs(
    title    = "Curvas de Aprendizaje: Train vs Valid (80/20) - Primeros 100 Árboles",
    subtitle = sprintf("Promedio ± 1 SD (5 semillas) | Best Iter Promedio: %.0f", mean_best_iter),
    x        = "Iteración",
    y        = "AUC",
    color    = "Set",
    fill     = "Set"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom",
    plot.title      = element_text(face = "bold", size = 14),
    plot.subtitle   = element_text(size = 11, color = "#333333"),
    panel.grid.minor = element_blank()
  )

archivo_downloads <- "/Users/tomas/Downloads/curva_tomas_100_iter.png"
archivo_brain <- "/Users/tomas/.gemini/antigravity/brain/7c41a9e3-c273-4627-8954-7d23f663b6e8/curva_tomas_100_iter.png"

ggsave(archivo_downloads, plot = p, width = 7.5, height = 5.5, dpi = 200)
ggsave(archivo_brain, plot = p, width = 7.5, height = 5.5, dpi = 200)

cat("Gráfico guardado en:", archivo_downloads, "\n")

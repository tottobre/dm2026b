# generar_foto_parametros.R
library(ggplot2)

texto_codigo <- "EXPERIMENTO exp5950 (MODELO GANADOR KAGGLE: 380.998 - 1° PUESTO)
Script: src/ensembles/z494_benchmark_baja2.R

PARAM <- list()
PARAM$experimento        <- 5950
PARAM$semilla_primigenia <- 401987
PARAM$semillas           <- c(401987, 456791, 607219, 701819, 811147)

PARAM$lgb <- list(
  objective          = 'binary',
  metric             = 'auc',
  boosting           = 'gbdt',
  max_bin            = 31L,
  learning_rate      = 0.018,
  num_iterations     = 650,
  num_leaves         = 24,
  min_data_in_leaf   = 50,
  feature_fraction   = 0.65,
  bagging_fraction   = 0.85,
  bagging_freq       = 1L,
  lambda_l1          = 0.5,
  lambda_l2          = 5.0,
  extra_trees        = FALSE,
  force_row_wise     = TRUE,
  feature_pre_filter = FALSE,
  verbosity          = -100
)

Target: BAJA+2 puro
Ensamble: 5 semillas oficiales promediadas (Seed Averaging)
Corte Ganador: 11.000 envios (KA5950_11000.csv) -> Score: 380.998"

p <- ggplot() +
  xlim(0, 1) + ylim(0, 1) +
  annotate("text", x = 0.04, y = 0.96, label = texto_codigo, 
           family = "mono", size = 3.2, color = "#F0F0F0", hjust = 0, vjust = 1, lineheight = 1.15) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "#1E1E1E", color = "#007ACC", linewidth = 2),
    plot.margin     = margin(12, 12, 12, 12)
  )

archivo_downloads <- "/Users/tomas/Downloads/parametros_exp5950_ganador.png"
archivo_brain     <- "/Users/tomas/.gemini/antigravity/brain/7c41a9e3-c273-4627-8954-7d23f663b6e8/parametros_exp5950_ganador.png"

ggsave(archivo_downloads, plot = p, width = 7.5, height = 7.0, dpi = 220)
ggsave(archivo_brain, plot = p, width = 7.5, height = 7.0, dpi = 220)

# Crear imagen de alta resolución con el bloque de parámetros exactos de exp5950 (380.998)
import matplotlib.pyplot as plt

code_text = """# EXPERIMENTO exp5950 (RÉCORD KAGGLE: 380.998)
# Archivo: z494_benchmark_baja2.R

PARAM <- list()
PARAM$experimento        <- 5950
PARAM$semilla_primigenia <- 401987
PARAM$semillas           <- c(401987, 456791, 607219, 701819, 811147)

# Hiperparámetros Óptimos LightGBM:
PARAM$lgb <- list(
  objective          = "binary",
  metric             = "auc",
  boosting           = "gbdt",
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

# Target: BAJA+2 puro
dataset[, clase01 := ifelse(clase_ternaria == "BAJA+2", 1L, 0L)]

# Ensamble: Promedio de 5 semillas (Seed Averaging)
# Corte Ganador: 11.000 envíos -> Public Score: 380.998 (1° Puesto)
"""

fig, ax = plt.subplots(figsize=(10, 8.5), dpi=200)
ax.set_facecolor('#1E1E1E')
fig.patch.set_facecolor('#1E1E1E')

plt.text(0.04, 0.96, code_text,
         fontsize=11.5,
         fontfamily='monospace',
         color='#D4D4D4',
         verticalalignment='top',
         linespacing=1.35)

ax.axis('off')
plt.tight_layout()

out_path = '/Users/tomas/Downloads/parametros_exp5950_ganador.png'
out_brain = '/Users/tomas/.gemini/antigravity/brain/7c41a9e3-c273-4627-8954-7d23f663b6e8/parametros_exp5950_ganador.png'

plt.savefig(out_path, facecolor=fig.get_facecolor(), bbox_inches='tight', pad_inches=0.4)
plt.savefig(out_brain, facecolor=fig.get_facecolor(), bbox_inches='tight', pad_inches=0.4)
print("Guardado en:", out_path)

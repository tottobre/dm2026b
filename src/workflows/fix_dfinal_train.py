import json

def fix_notebook_and_r(ipynb_path, out_r_path, is_suggestions=False):
    with open(ipynb_path, "r", encoding="utf-8") as f:
        nb = json.load(f)

    # 1. Prepare exact cell 79 code including dfinal_train creation
    if is_suggestions:
        final_train_months = """PARAM$trainingstrategy$final_train <- c(
  201901, 201902, 201903, 201904, 201905, 201906,
  201907, 201908, 201909, 201910, 201911, 201912,
  202001, 202002,
  202007, 202008, 202009, 202010, 202011, 202012,
  202101, 202102, 202103, 202104, 202105, 202106, 202107
)"""
        num_seeds = 20
        seeds_array = """PARAM$FT$semillas <- c(
  401987, 456791, 607219, 701819, 811147,
  102191, 200003, 314159, 420042, 555555,
  618033, 777777, 888888, 999999, 123456,
  654321, 987654, 456123, 789321, 321654
)"""
    else:
        final_train_months = """PARAM$trainingstrategy$final_train <- c(
  201901, 201902, 201903, 201904, 201905, 201906,
  201907, 201908, 201909, 201910, 201911, 201912,
  202001, 202002, 202003, 202004, 202005, 202006,
  202007, 202008, 202009, 202010, 202011, 202012,
  202101, 202102, 202103, 202104, 202105, 202106, 202107
)"""
        num_seeds = 5
        seeds_array = """PARAM$FT$semillas <- c(401987, 456791, 607219, 701819, 811147)"""

    c79_source = [
        f"# 1. Construimos el Dataset Final de Entrenamiento (dfinal_train)\n",
        f"{final_train_months}\n",
        "\n",
        "dtrain_final  <- dataset[ foto_mes %in% PARAM$trainingstrategy$final_train ]\n",
        "\n",
        "dfinal_train  <- lgb.Dataset(\n",
        "  data= data.matrix( dtrain_final[, campos_buenos, with=FALSE] ),\n",
        "  label= dtrain_final[, clase01],\n",
        "  weight= dtrain_final[, peso],\n",
        "  free_raw_data= FALSE\n",
        ")\n",
        "\n",
        "# 2. Definimos param_final uniendo hiperparámetros fijos + hiperparámetros óptimos de la BO\n",
        "param_final <- modifyList(\n",
        "  PARAM$lgbm$param_fijos,\n",
        "  as.list(PARAM$out$lgbm$mejores_hiperparametros)\n",
        ")\n",
        "\n",
        f"# 3. Definimos las {num_seeds} semillas fijas para el semillerío\n",
        f"{seeds_array}\n",
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

    for cell in nb["cells"]:
        source = "".join(cell["source"])
        if "crear_modelo_final" in source:
            cell["source"] = c79_source

    with open(ipynb_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2, ensure_ascii=False)

    # Re-extract R script
    r_code = [f"# Auto-generated executable R script ({out_r_path})\n"]
    for i, cell in enumerate(nb["cells"]):
        if cell["cell_type"] == "code":
            source = "".join(cell["source"])
            source = source.replace("/content/buckets/b1/exp", "/Users/tomas/Dev/dm2026b/exp")
            source = source.replace("/content/datasets/", "/Users/tomas/Dev/dm2026b/datasets/")
            r_code.append(f"# --- CELL {i} ---")
            r_code.append(source)
            r_code.append("\n")

    with open(out_r_path, "w", encoding="utf-8") as f:
        f.write("\n".join(r_code))

    print(f"FIXED DFINAL_TRAIN IN {ipynb_path} AND {out_r_path}")

# Fix junior run
fix_notebook_and_r(
    "/Users/tomas/Downloads/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_junior_clean_run.R",
    is_suggestions=False
)
fix_notebook_and_r(
    "/Users/tomas/Dev/dm2026b/src/workflows/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_junior_clean_run.R",
    is_suggestions=False
)

# Fix suggestions run
fix_notebook_and_r(
    "/Users/tomas/Downloads/primer intento con todas las sugerencias y BO y ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_primer_intento_sugerencias.R",
    is_suggestions=True
)
fix_notebook_and_r(
    "/Users/tomas/Dev/dm2026b/src/workflows/primer intento con todas las sugerencias y BO y ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_primer_intento_sugerencias.R",
    is_suggestions=True
)

print("ALL NOTEBOOKS & R SCRIPTS FULLY FIXED WITH DFINAL_TRAIN!")

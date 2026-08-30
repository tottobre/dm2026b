import json

paths = [
    "/Users/tomas/Downloads/primer intento con todas las sugerencias y BO y ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/primer intento con todas las sugerencias y BO y ensemble.ipynb"
]

twenty_seeds_code = [
    "# Definimos param_final uniendo hiperparámetros fijos + hiperparámetros óptimos de la BO\n",
    "param_final <- modifyList(\n",
    "  PARAM$lgbm$param_fijos,\n",
    "  as.list(PARAM$out$lgbm$mejores_hiperparametros)\n",
    ")\n",
    "\n",
    "# Definimos 20 semillas para un semillerío masivo (empezando con tus 5 semillas fijas)\n",
    "PARAM$FT$semillas <- c(\n",
    "  401987, 456791, 607219, 701819, 811147,\n",
    "  102191, 200003, 314159, 420042, 555555,\n",
    "  618033, 777777, 888888, 999999, 123456,\n",
    "  654321, 987654, 456123, 789321, 321654\n",
    ")\n",
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

for p in paths:
    with open(p, "r", encoding="utf-8") as f:
        nb = json.load(f)
    
    for cell in nb["cells"]:
        source = "".join(cell["source"])
        if "crear_modelo_final" in source:
            cell["source"] = twenty_seeds_code
            
    with open(p, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2, ensure_ascii=False)

print("TWENTY SEEDS SCRIPT UPDATED CLEANLY!")

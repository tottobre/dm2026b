import json

def fix_colab(nb_path):
    with open(nb_path, "r", encoding="utf-8") as f:
        nb = json.load(f)
    for cell in nb['cells']:
        src = ''.join(cell['source'])
        if 'setwd("/content/buckets' in src or "setwd('/content/buckets" in src:
            cell['source'] = ['# setwd for Colab overridden locally\n', 'setwd(PARAM$path_output)\n']
    with open(nb_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2)

fix_colab("/Users/tomas/Dev/dm2026b/src/workflows/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb")
fix_colab("/Users/tomas/Downloads/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb")
print("Colab setwd fixed!")

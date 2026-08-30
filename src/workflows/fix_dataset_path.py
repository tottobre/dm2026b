import json

def fix_ds(nb_path):
    with open(nb_path, "r", encoding="utf-8") as f:
        nb = json.load(f)
    for cell in nb['cells']:
        src = ''.join(cell['source'])
        if 'fread(paste0("/content/datasets/' in src or "fread(paste0('/content/datasets/" in src or 'fread("/content/datasets/' in src:
            cell['source'] = ['dataset <- fread("/Users/tomas/Dev/dm2026b/datasets/analistajr_competencia_2026.csv.gz")\n']
    with open(nb_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2)

fix_ds("/Users/tomas/Dev/dm2026b/src/workflows/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb")
fix_ds("/Users/tomas/Downloads/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb")
print("Dataset path fixed!")

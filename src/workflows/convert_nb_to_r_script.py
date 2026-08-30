import json, os

nb_path = "/Users/tomas/Dev/dm2026b/src/workflows/todas_sugerencias_BO_ensemble_y sugerencia antigrav/segundo intento FE avanzado canaritos y extra trees.ipynb"
r_out_path = "/Users/tomas/Dev/dm2026b/src/workflows/z920_segundo_intento_antigrav.R"

with open(nb_path, "r", encoding="utf-8") as f:
    nb = json.load(f)

r_lines = [
    "#!/usr/bin/env Rscript\n",
    "# ========================================================================\n",
    "# SEGUNDO INTENTO: TODAS LAS SUGERENCIAS + BO + 20 SEEDS ENSEMBLE + SUGERENCIAS ANTIGRAVITY\n",
    "# (FE Tendencias 3m/6m + Canaritos Asesinos + extra_trees=TRUE + rank_cero_fijo)\n",
    "# ========================================================================\n\n"
]

for i, cell in enumerate(nb['cells']):
    if cell['cell_type'] == 'code':
        src = ''.join(cell['source'])
        r_lines.append(f"# --- CELL {i+1} ---\n")
        r_lines.append(src)
        r_lines.append("\n\n")

with open(r_out_path, "w", encoding="utf-8") as f:
    f.writelines(r_lines)

print(f"R script generated successfully: {r_out_path}")

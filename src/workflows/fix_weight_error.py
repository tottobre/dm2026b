import json

paths = [
    "/Users/tomas/Downloads/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb",
    "/Users/tomas/Downloads/primer intento con todas las sugerencias y BO y ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb",
    "/Users/tomas/Dev/dm2026b/src/workflows/primer intento con todas las sugerencias y BO y ensemble.ipynb"
]

r_paths = [
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_junior_clean_run.R",
    "/Users/tomas/Dev/dm2026b/src/workflows/z910_primer_intento_sugerencias.R"
]

for p in paths:
    with open(p, "r", encoding="utf-8") as f:
        nb = json.load(f)
    for cell in nb["cells"]:
        source = "".join(cell["source"])
        if "dfinal_train  <- lgb.Dataset" in source or "dfinal_train <- lgb.Dataset" in source:
            lines = cell["source"]
            new_lines = [l for l in lines if "weight=" not in l and "weight =" not in l]
            cell["source"] = new_lines
    with open(p, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2, ensure_ascii=False)

for r in r_paths:
    with open(r, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("weight= dtrain_final[, peso],\n", "")
    text = text.replace("weight = dtrain_final[, peso],\n", "")
    text = text.replace("weight= dtrain_final[, peso],", "")
    with open(r, "w", encoding="utf-8") as f:
        f.write(text)

print("WEIGHT ERROR REMOVED FROM ALL NOTEBOOKS AND R SCRIPTS!")

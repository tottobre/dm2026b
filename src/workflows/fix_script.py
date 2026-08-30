import json

r_path = "/Users/tomas/Dev/dm2026b/src/workflows/z910_junior_custom_run.R"
with open(r_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i in range(len(lines)):
    if lines[i].strip() == 'PARAM <- "rank_cero_fijo"':
        lines[i] = 'PARAM$DR$metodo <- "rank_cero_fijo"\n'
    if lines[i].strip() == 'switch(PARAM,':
        lines[i] = 'switch(PARAM$DR$metodo,\n'

with open(r_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

# Also fix the ipynb files
for p in ["/Users/tomas/Downloads/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb",
          "/Users/tomas/Dev/dm2026b/src/workflows/junior,rank_cero_fijo,semilla primigenia,BO,ensemble.ipynb"]:
    with open(p, "r", encoding="utf-8") as f:
        nb = json.load(f)
    c38 = nb["cells"][38]["source"]
    for k in range(len(c38)):
        if "PARAM <- \"rank_cero_fijo\"" in c38[k] or "PARAM$DR$metodo" not in c38[k] and "rank_cero_fijo" in c38[k]:
            c38[k] = 'PARAM$DR$metodo <- "rank_cero_fijo"\n'
        if "switch(PARAM," in c38[k]:
            c38[k] = 'switch(PARAM$DR$metodo,\n'
    nb["cells"][38]["source"] = c38
    with open(p, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2, ensure_ascii=False)

print("PYTHON FIX FILE EXECUTED CLEANLY!")

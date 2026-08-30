import glob, json, os, re, subprocess, sys, time

def log(msg):
    t_str = time.strftime("[%H:%M:%S]")
    print(f"{t_str} {msg}", flush=True)

files = sorted(glob.glob("/Users/tomas/Downloads/z911_WorkFlow_01_junior_julio (metodo rank_cero_fijo) semilla *.ipynb"))
log(f"Starting batch runner for {len(files)} rank_cero_fijo notebooks.")

results = []

for idx, fpath in enumerate(files, 1):
    fname = os.path.basename(fpath)
    match_seed = re.search(r"semilla\s+(\d+)", fname)
    fname_seed = match_seed.group(1) if match_seed else "UNKNOWN"
    
    log(f"=== [{idx}/{len(files)}] Processing {fname} ===")
    
    with open(fpath) as f:
        nb = json.load(f)
    
    c11 = "".join(nb["cells"][11]["source"])
    c38 = "".join(nb["cells"][38]["source"])
    
    m_seed = re.search(r"PARAM\$semilla_primigenia\s*<-\s*(\d+)", c11)
    m_exp = re.search(r"PARAM\$experimento\s*<-\s*\"([^\"]+)\"", c11)
    m_method = re.search(r"PARAM\$DR\$metodo\s*<-\s*\"([^\"]+)\"", c38)
    
    nb_seed = m_seed.group(1) if m_seed else ""
    nb_exp = m_exp.group(1) if m_exp else ""
    nb_method = m_method.group(1) if m_method else ""
    
    if fname_seed != nb_seed:
        log(f"SKIPPING {fname}: Seed mismatch (file: {fname_seed}, notebook: {nb_seed})")
        results.append({"file": fname, "seed": fname_seed, "method": nb_method, "status": "SKIPPED_SEED_MISMATCH"})
        continue
        
    if nb_method != "rank_cero_fijo":
        log(f"SKIPPING {fname}: Method mismatch (expected rank_cero_fijo, got {nb_method})")
        results.append({"file": fname, "seed": fname_seed, "method": nb_method, "status": "SKIPPED_METHOD_MISMATCH"})
        continue

    # Prepare R script
    r_name = fname.replace(".ipynb", ".R").replace(" ", "_").replace("(", "").replace(")", "")
    r_path = os.path.join("/Users/tomas/Dev/dm2026b/src/workflows", r_name)
    
    # Run R script
    log(f"Running Rscript {r_path}...")
    start_t = time.time()
    res = subprocess.run(["Rscript", r_path], capture_output=True, text=True)
    duration_m = (time.time() - start_t) / 60.0
    
    # Determine output folder
    exp_folder1 = f"/Users/tomas/Dev/dm2026b/exp/WF{nb_exp}"
    exp_folder2 = f"/Users/tomas/Dev/dm2026b/exp/{nb_exp}"
    
    target_folder = f"/Users/tomas/Dev/dm2026b/exp/WFsemilla_{nb_seed}-rank_cero_fijo"
    os.makedirs(target_folder, exist_ok=True)
    
    source_folder = exp_folder1 if os.path.exists(exp_folder1) else (exp_folder2 if os.path.exists(exp_folder2) else None)
    
    if source_folder and os.path.exists(source_folder):
        subprocess.run(f"cp -r {source_folder}/* {target_folder}/", shell=True)
    
    yml_path = os.path.join(target_folder, "PARAM.yml")
    auc = None
    ganancia_max = None
    envios = None
    num_leaves = None
    min_data_in_leaf = None
    feature_fraction = None
    niter = None
    
    if os.path.exists(yml_path):
        with open(yml_path) as yf:
            ytext = yf.read()
        m_auc = re.search(r"AUC:\s*([0-9\.]+)", ytext)
        m_gan = re.search(r"ganancia_suavizada_max:\s*([0-9\.]+)", ytext)
        m_env = re.search(r"envios:\s*([0-9\.]+)", ytext)
        m_nl = re.search(r"num_leaves:\s*([0-9\.]+)", ytext)
        m_md = re.search(r"min_data_in_leaf:\s*([0-9\.]+)", ytext)
        m_ff = re.search(r"feature_fraction:\s*([0-9\.]+)", ytext)
        m_it = re.search(r"num_iterations:\s*([0-9\.]+)", ytext)
        
        auc = float(m_auc.group(1)) if m_auc else None
        ganancia_max = float(m_gan.group(1)) if m_gan else None
        envios = int(float(m_env.group(1))) if m_env else None
        num_leaves = int(float(m_nl.group(1))) if m_nl else None
        min_data_in_leaf = int(float(m_md.group(1))) if m_md else None
        feature_fraction = float(m_ff.group(1)) if m_ff else None
        niter = int(float(m_it.group(1))) if m_it else None
        
        log(f"COMPLETED {fname} in {duration_m:.2f} mins -> AUC: {auc}, Ganancia: {ganancia_max}, Envíos: {envios}")
        results.append({
            "file": fname,
            "seed": nb_seed,
            "method": nb_method,
            "status": "OK",
            "duration_mins": round(duration_m, 2),
            "auc": auc,
            "ganancia_max": ganancia_max,
            "envios": envios,
            "best_params": {
                "num_leaves": num_leaves,
                "min_data_in_leaf": min_data_in_leaf,
                "feature_fraction": feature_fraction,
                "num_iterations": niter
            },
            "exp_folder": target_folder
        })
    else:
        log(f"FAILED {fname}: Return code {res.returncode}. Stderr: {res.stderr[-300:]}")
        results.append({
            "file": fname,
            "seed": nb_seed,
            "method": nb_method,
            "status": "FAILED",
            "error": res.stderr[-300:]
        })

with open("/Users/tomas/Dev/dm2026b/exp/batch_rank_cero_fijo_summary.json", "w") as jf:
    json.dump(results, jf, indent=2)

log("ALL 9 NOTEBOOKS COMPLETED!")

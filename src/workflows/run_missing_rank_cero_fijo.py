import os
import re
import subprocess

base_dir = "/Users/tomas/Dev/dm2026b"
template_path = os.path.join(base_dir, "src/workflows/z911_WorkFlow_01_junior_julio_metodo_rank_cero_fijo_semilla_900211.R")

with open(template_path, "r", encoding="utf-8") as f:
    template_code = f.read()

missing_seeds = [250033, 250037, 314161, 441989, 478069, 516349, 516353, 600111, 630013]

results = {}

for seed in missing_seeds:
    print(f"\n==================================================")
    print(f"   RUNNING RANK_CERO_FIJO FOR SEED: {seed}")
    print(f"==================================================")
    
    # Customize template for seed
    code = template_code.replace("900211", str(seed))
    
    script_path = os.path.join(base_dir, f"src/workflows/z911_run_rank_cero_fijo_semilla_{seed}.R")
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(code)
    
    # Execute R script
    cmd = f"/opt/homebrew/bin/Rscript {script_path}"
    ret = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if ret.returncode != 0:
        print(f"Error running seed {seed}:\n{ret.stderr}")
    else:
        print(f"Seed {seed} completed successfully.")
        
    # Read output PARAM.yml using regex
    yml_path = os.path.join(base_dir, f"exp/WFsemilla_{seed}-rank_cero_fijo/PARAM.yml")
    if os.path.exists(yml_path):
        with open(yml_path, "r") as f:
            content = f.read()
            m_gan = re.search(r"ganancia_suavizada_max:\s*([0-9\.]+)", content)
            m_env = re.search(r"envios:\s*([0-9\.]+)", content)
            if m_gan and m_env:
                gan = float(m_gan.group(1))
                env = float(m_env.group(1))
                # Normalize ganancia to millions / percentage if scale requires (check scale: in raw code it is around 90-100 or 90000000)
                # In PARAM.yml for 900211, let's check exact scale:
                results[seed] = {"ganancia": gan, "envios": env}
                print(f"--> SEED {seed}: Ganancia Suavizada Max = {gan} (Envios: {env})")
    else:
        print(f"WARNING: PARAM.yml not found for seed {seed}")

print("\n\n==================================================")
print("   SUMMARY OF ALL NEW RUNS FOR RANK_CERO_FIJO")
print("==================================================")
for seed, res in results.items():
    print(f"Seed {seed}: Ganancia = {res['ganancia']:.4f} (Envios = {res['envios']})")

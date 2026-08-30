import os, sys, time, glob, subprocess

target_dir = "/Users/tomas/Dev/dm2026b/exp/WFjunior_rank_cero_fijo_semilla_primigenia_BO_ensemble/kaggle"
comp_name = "data-mining-junior-2026-b"

print("Monitoring for generated Kaggle submission CSVs...")

# Wait up to 10 minutes for task-495 to finish generating CSVs
max_wait = 600
start = time.time()

csv_files = []
while time.time() - start < max_wait:
    if os.path.exists(target_dir):
        csv_files = sorted(glob.glob(f"{target_dir}/*.csv"))
        if len(csv_files) > 0:
            break
    time.sleep(5)

if not csv_files:
    print("Timeout waiting for CSV files.")
    sys.exit(1)

print(f"Found {len(csv_files)} submission CSV files!")

# Target the optimal cut (~11000 or 10500 or 11500) or submit all
preferred = [f for f in csv_files if "11000" in f or "10500" in f or "11500" in f]
to_submit = preferred if preferred else csv_files[:3]

for csv in to_submit:
    filename = os.path.basename(csv)
    print(f"Submitting {filename} to Kaggle competition '{comp_name}'...")
    cmd = [
        "kaggle", "competitions", "submit",
        "-c", comp_name,
        "-f", csv,
        "-m", f"Auto submit {filename} (rank_cero_fijo + BO + 5-seed ensemble)"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)

print("KAGGLE SUBMISSION PROCESS COMPLETED!")

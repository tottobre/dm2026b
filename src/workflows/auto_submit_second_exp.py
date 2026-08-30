import os, sys, time, glob, subprocess

target_dir = "/Users/tomas/Dev/dm2026b/exp/todas_sugerencias_BO_ensemble_y_sugerencia_antigrav/kaggle"
comp_name = "data-mining-junior-2026-b"

print("Monitoring for second experiment Kaggle submission CSVs...")

max_wait = 7200
start = time.time()

csv_files = []
while time.time() - start < max_wait:
    if os.path.exists(target_dir):
        csv_files = sorted(glob.glob(f"{target_dir}/*.csv"))
        if len(csv_files) > 0:
            break
    time.sleep(10)

if not csv_files:
    print("Timeout waiting for CSV files.")
    sys.exit(1)

print(f"Found {len(csv_files)} submission CSV files in second experiment!")

preferred = [f for f in csv_files if "11000" in f or "10500" in f or "11500" in f]
to_submit = preferred if preferred else csv_files[:3]

for csv in to_submit:
    filename = os.path.basename(csv)
    print(f"Submitting {filename} to Kaggle competition '{comp_name}'...")
    cmd = [
        "kaggle", "competitions", "submit",
        "-c", comp_name,
        "-f", csv,
        "-m", f"Second Exp (All Video Suggestions + BO + 20-Seed Ensemble + Antigravity FE & ExtraTrees) ({filename})"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)

print("SECOND EXPERIMENT KAGGLE SUBMISSIONS COMPLETED!")

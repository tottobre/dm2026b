import os
import re

missing_runs = [
    (100043, 'rank_simple', 'run_z911_rank_simple_100043.R'),
    (500009, 'rank_simple', 'run_z911_rank_simple_500009.R'),
    (500009, 'deflacion',   'run_z911_deflacion_500009.R'),
    (999961, 'rank_simple', 'run_z911_rank_simple_999961.R')
]

for seed, method, filename in missing_runs:
    path = os.path.join('/Users/tomas/Dev/dm2026b/src/workflows', filename)
    with open(path, 'r') as f:
        text = f.read()
    
    text = re.sub(r'PARAM\$semilla_primigenia\s*<-\s*[0-9]+', f'PARAM$semilla_primigenia <- {seed}', text)
    text = re.sub(r'PARAM\$experimento\s*<-\s*"[^"]+"', f'PARAM$experimento <- "semilla_{seed}-{method}"', text)
    text = re.sub(r'PARAM\$DR\$metodo\s*<-\s*"[^"]+"', f'PARAM$DR$metodo <- "{method}"', text)
    
    with open(path, 'w') as f:
        f.write(text)

for seed, method, filename in missing_runs:
    path = os.path.join('/Users/tomas/Dev/dm2026b/src/workflows', filename)
    with open(path, 'r') as f:
        lines = f.readlines()
    print(f'=== {filename} ===')
    print('  Line 24:', lines[23].strip())
    print('  Line 26:', lines[25].strip())
    print('  Line 431:', lines[430].strip())

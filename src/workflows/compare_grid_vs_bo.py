import os
import re

exp_dir = '/Users/tomas/Dev/dm2026b/exp'
folders = sorted(os.listdir(exp_dir))

records = []

for folder in folders:
    param_path = os.path.join(exp_dir, folder, 'PARAM.yml')
    if os.path.exists(param_path):
        with open(param_path) as f:
            text = f.read()
            
            m_seed = re.search(r'semilla_primigenia:\s*([0-9\.]+)', text)
            m_gan = re.search(r'ganancia_suavizada_max:\s*([0-9\.]+)', text)
            m_env = re.search(r'envios:\s*([0-9\.]+)', text)
            m_dr = re.search(r'DR:\s*\n\s*metodo:\s*([^\n]+)', text)
            m_val = re.search(r'validate:\s*([0-9\.]+)', text)
            
            seed = str(int(float(m_seed.group(1)))) if m_seed else 'Unknown'
            gan = float(m_gan.group(1)) if m_gan else None
            env = int(float(m_env.group(1))) if m_env else None
            dr = m_dr.group(1).strip() if m_dr else 'Unknown'
            val = str(int(float(m_val.group(1)))) if m_val else 'Unknown'
            
            is_bo = 'BO' in folder or 'bo' in folder.lower()
            
            records.append({
                'folder': folder,
                'seed': seed,
                'method': dr,
                'validate': val,
                'is_bo': is_bo,
                'ganancia': gan,
                'envios': env
            })

# Group pairs by (seed, method, validate)
paired = {}
for r in records:
    key = (r['seed'], r['method'], r['validate'])
    if key not in paired:
        paired[key] = {'grid': None, 'bo': None}
    if r['is_bo']:
        paired[key]['bo'] = r
    else:
        paired[key]['grid'] = r

print('=== COMPARACIÓN DIRECTA: GRID SEARCH vs. OPTIMIZACIÓN BAYESIANA (BO) ===\n')
print('| SEMILLA | MÉTODO | MES VALIDACIÓN | GRID SEARCH | OPTIMIZACIÓN BAYESIANA (BO) | DIFERENCIA | ENVIOS (GS / BO) |')
print('| :---: | :---: | :---: | :---: | :---: | :---: | :---: |')

grid_wins = 0
bo_wins = 0
diffs = []

for (seed, method, validate), data in sorted(paired.items()):
    grid = data['grid']
    bo = data['bo']
    if grid or bo:
        g_val = f"{grid['ganancia']:.4f}".replace('.', ',') if (grid and grid['ganancia'] is not None) else '-'
        b_val = f"{bo['ganancia']:.4f}".replace('.', ',') if (bo and bo['ganancia'] is not None) else '-'
        
        diff_str = '-'
        if grid and bo and grid['ganancia'] is not None and bo['ganancia'] is not None:
            diff = bo['ganancia'] - grid['ganancia']
            diffs.append(diff)
            diff_str = f"{diff:+.4f}".replace('.', ',')
            if diff > 0:
                bo_wins += 1
            else:
                grid_wins += 1
            
        g_env = str(grid['envios']) if (grid and grid['envios'] is not None) else '-'
        b_env = str(bo['envios']) if (bo and bo['envios'] is not None) else '-'
        
        print(f'| **{seed}** | `{method}` | `{validate}` | {g_val} | {b_val} | {diff_str} | {g_env} / {b_env} |')

if diffs:
    avg_diff = sum(diffs)/len(diffs)
    print('| :---: | :---: | :---: | :---: | :---: | :---: | :---: |')
    print(f'| **RESUMEN** | **{len(diffs)} Pares** | - | **{grid_wins} Victorias** | **{bo_wins} Victorias** | **{avg_diff:+.4f} Prom.** | - |')

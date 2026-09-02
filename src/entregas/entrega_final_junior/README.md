# Entrega Final Competencia Junior — Data Mining 2026B (ITBA)

**Alumno**: Tomas Ottobre  
**Semilla Primigenia**: `401987`  
**Repositorio**: [tottobre/dm2026b](https://github.com/tottobre/dm2026b)

---

## 📌 Resumen de la Solución

El notebook [`Entrega_Final_Junior.ipynb`](./Entrega_Final_Junior.ipynb) constituye la entrega final oficial para la Competencia Inicial Junior 2026B. Integra todas las optimizaciones validadas:

1. **Data Drifting**: `PARAM$DR$metodo <- "rank_cero_fijo"` (Método óptimo comprobado con $p < 0,01$ en el Test de Wilcoxon pareado).
2. **Feature Selection**: Canaritos Asesinos (`ratio = 0.2`, `desvios = 2`).
3. **Hyperparameter Tuning**: Optimización Bayesiana con `mlrMBO` (40 búsquedas con transformación logarítmica $2^x$).
4. **Final Training & Ensemble (Seed Averaging)**: Ensamble de **20 semillas** independientes basadas en números primos (`generate_primes`).
5. **Estrategia de Envíos en Kaggle**: Generación de cortes en `seq(1600, 2600, by=100)` sobre el mes futuro (`202109`), centrando la meseta óptima de ganancia en **2.000 envíos**.

---

## 📁 Archivo de Entrega

- Notebook Principal: [`src/entregas/entrega_final_junior/Entrega_Final_Junior.ipynb`](./Entrega_Final_Junior.ipynb)

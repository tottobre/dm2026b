# Plan de Estudio Integral: Almacenes de Datos y OLAP (ITBA 2026-B)

> [!NOTE]
> Guía estructurada de acompañamiento pedagógico desde nivel cero (nivel -10). Este documento consolida las clases grabadas en audio, las diapositivas de la cátedra del Prof. Alejandro Vaisman, las tareas pedidas y las bases del curso de nivelación de Bases de Datos.

---

## 🗺️ Mapa General del Curso y Estado de Materiales

| Clase / Unidad | Contenido de Cátedra | Archivos de Audio Disponibles | Estado de Procesamiento |
| :--- | :--- | :--- | :--- |
| **Módulo 0: Cimientos** | Bases de Datos Relacionales (DER, 3NF, SQL) | Material de nivelación | 🟢 Consolidado en `guia_nivelacion_dw_olap.md` |
| **Clase 1 (14/08/26)** | Introducción a DW/OLAP, OLTP vs OLAP, 4 Etapas de Diseño, TP1 | `Voz 260814_175858.m4a`<br>`Voz 260814_195627.m4a` | 🟡 En proceso de extracción |
| **Clase 2 (15/08/26)** | Repaso SQL, Modelo Multidimensional, Hechos, Dims, Cubos, TP2 | `Clase 2 1ra parte.m4a`<br>`Clase 2 2da parte.m4a`<br>`Voz 260815_...m4a` | 🟡 En proceso de extracción |
| **Clase 3 (21/08/26)** | Jerarquías avanzadas, Granularidades múltiples, Relaciones N:M | `1ra parte clase 3.m4a`<br>`2da parte clase 3.m4a`<br>`Viernes 21...m4a` | 🟡 En proceso de extracción |
| **Clase 4 (22/08/26)** | **Diseño Lógico Relacional (ROLAP)**, Esquema en Estrella, TP3 | `Clase 4.m4a`<br>`Voz 260822_...m4a` | 🟡 En proceso de extracción |

---

## 📝 Tareas y Pedidos del Profesor (Extraídos de la Cátedra)

1. **TP01-SQL (Repaso de SQL sobre Northwind)**:
   - **Objetivo**: Garantizar el manejo fluido de `JOIN`, `GROUP BY`, `HAVING` y funciones de agregación antes de entrar de lleno a OLAP.
   - **Base de datos**: Script PostgreSQL `NorthwindDB_postgresql-script.sql` (Unidad 1).
2. **TP02-Diseño Conceptual**:
   - **Objetivo**: Modelar Hechos y Dimensiones a partir de enunciados de negocio reales.
3. **TP03-Diseño Lógico**:
   - **Objetivo**: Mapear el diseño conceptual a tablas relacionales ROLAP en PostgreSQL (Esquema en Estrella).
4. **Proyecto Integrador de la Materia (En grupos de 3-4)**:
   - **Parte 1 (Entrega 20/09/26)**: Requerimientos + Diseños Conceptual y Lógico.
   - **Parte 2 (Entrega 27/09/26)**: Implementación del Data Mart en SQL + Consultas analíticas.

---

## 📚 Hoja de Ruta de Aprendizaje (Módulo por Módulo)

```
[Módulo 1: Bases de Datos y SQL (Repaso TP1)]
                   ↓
[Módulo 2: Introducción a DW & OLAP (Clase 1)]
                   ↓
[Módulo 3: El Modelo Multidimensional y Operaciones OLAP (Clase 2)]
                   ↓
[Módulo 4: Diseño Conceptual Avanzado y Jerarquías (Clase 3)]
                   ↓
[Módulo 5: Diseño Lógico ROLAP y Esquemas en Estrella (Clase 4)]
```

> [!TIP]
> **Metodología de acompañamiento**:
> En cada módulo explicaremos los conceptos con ejemplos cotidianos (nivel cero), mostraremos el término técnico de cátedra, añadiremos los comentarios clave que hizo el profesor en los audios sobre las diapositivas y resolveremos los ejercicios pedidos.

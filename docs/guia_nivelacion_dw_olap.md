# Guía de Nivelación: Bases de Datos, SQL Analítico y Almacenes de Datos (DW/OLAP)

> [!NOTE]
> Documento preparado a partir de los contenidos del curso de nivelación de ITBA, estructurado específicamente como preparación para la materia **Almacenes de Datos y Procesamiento Analítico en Línea**.

---

## Módulo 1: Modelo Conceptual y Relacional (De DER a Tablas)

En sistemas transaccionales (OLTP), los datos se diseñan pensando en entidades del mundo real y en evitar inconsistencias. En OLAP, esas entidades se reorganizan en **Hechos** (eventos) y **Dimensiones** (contexto).

### 1. Conceptos Fundamentales
- **Entidad**: Objeto o concepto del negocio sobre el cual se recolectan datos (ej: `Cliente`, `Producto`, `Venta`).
- **Atributo**: Propiedad que describe a una entidad (ej: `nombre`, `precio`, `fecha`).
- **Relación**: Asociación entre dos o más entidades.

### 2. Cardinalidades de Relación
- **1:1 (Uno a Uno)**: Un registro de A se relaciona con máximo uno de B.
- **1:N (Uno a Muchos)**: Un registro de A se relaciona con muchos de B (ej: Un `Cliente` realiza muchas `Ventas`).
- **N:M (Muchos a Muchos)**: Muchos registros de A se relacionan con muchos de B (ej: Un `Pedido` contiene muchos `Productos`, y un `Producto` está en muchos `Pedidos`).

### 3. Reglas de Mapeo a Tablas Relacionales
Cuando se pasa del diseño conceptual (DER) a tablas relacionales:
1. **Entidad $\rightarrow$ Tabla**: Cada entidad pasa a ser una tabla.
2. **Relación 1:N $\rightarrow$ Clave Foránea (FK)**: La Clave Primaria (PK) del lado "1" se copia como columna (FK) en la tabla del lado "N".
3. **Relación N:M $\rightarrow$ Tabla Intermedia**: Se crea una tabla asociativa cuya PK es la combinación de las FKs de ambas tablas.

> [!IMPORTANT]
> **Conexión DW/OLAP**:
> - En un Data Warehouse, **las relaciones N:M con atributos cuantitativos** (ej: cantidad vendida, monto, descuento) se convierten en **Tablas de Hechos (*Fact Tables*)**.
> - Las entidades descriptivas del lado "1" se convierten en **Tablas de Dimensiones (*Dim Tables*)**.

---

## Módulo 2: Claves (Keys) en Bases de Datos y DW

### 1. Tipos de Claves Tradicionales
- **Natural Key / Business Key (Clave Natural o de Negocio)**: Identificador proveniente del sistema de origen (ej: DNI, CUIT, SKU de producto, código de transacción).
- **Primary Key (PK)**: Columna o conjunto de columnas que identifican de forma única e irrepetible a cada fila de una tabla. Debe ser no nula (`NOT NULL`).
- **Foreign Key (FK)**: Columna que referencia a la PK de otra tabla para garantizar **Integridad Referencial**.

### 2. Surrogate Key (Clave Sustituta) — *Crucial para DW*
Una **Surrogate Key** es un entero sin sentido de negocio (generado con `AUTO_INCREMENT`, `SERIAL` o `BIGINT`) asignado por el Data Warehouse.

```sql
-- Ejemplo de Dimensión en DW usando Surrogate Key
CREATE TABLE Dim_Cliente (
    cliente_sk BIGINT PRIMARY KEY, -- Surrogate Key (Propia del DW)
    cliente_id_origen INT NOT NULL, -- Natural/Business Key (Viene del sistema OLTP)
    nombre VARCHAR(100),
    categoria VARCHAR(50),
    fecha_inicio_validez DATE,
    fecha_fin_validez DATE
);
```

> [!TIP]
> **¿Por qué en DW se usan Surrogate Keys y NO la Clave Natural?**
> 1. **Manejo de Históricos (SCD Tipo 2)**: Si un cliente cambia de categoría, en el DW se inserta una *nueva fila* con la misma clave natural, pero una *nueva Surrogate Key*.
> 2. **Integración de Múltiples Fuentes**: Si unificás dos sistemas OLTP donde ambos tienen un `cliente_id = 100`, la Surrogate Key evita colisiones.
> 3. **Performance**: Los `JOINs` entre enteros de 4 u 8 bytes son drásticamente más rápidos que sobre textos o claves compuestas.

---

## Módulo 3: Normalización (3NF) vs. Desnormalización (DW)

La normalización es el proceso de estructurar una base relacional para reducir la redundancia de datos y evitar anomalías de modificación.

### Dependencia Funcional ($X \rightarrow Y$)
Significa que el valor del atributo $X$ determina de manera única el valor del atributo $Y$.

### Las 3 Formas Normales Transaccionales (3NF)

| Forma Normal | Regla Principal | Problema que resuelve |
| :--- | :--- | :--- |
| **1NF (Primera)** | Todos los atributos son atómicos (no arreglos, no listas). Cada celda tiene un solo valor. | Datos no estructurados dentro de celdas. |
| **2NF (Segunda)** | Estar en 1NF + Todo atributo no-clave depende de la **totalidad** de la PK (aplica a PKs compuestas). | Redundancia parcial en claves compuestas. |
| **3NF (Tercera)** | Estar en 2NF + **Sin dependencias transitivas** (ningún atributo no-clave depende de otro atributo no-clave). | Redundancia y anomalías de actualización. |

#### Ejemplo de violación de 3NF:
En la tabla `Cliente`: `(cliente_id, nombre, ciudad_id, ciudad_nombre)`
- `cliente_id` $\rightarrow$ `ciudad_id`
- `ciudad_id` $\rightarrow$ `ciudad_nombre` (Dependencia transitiva: `ciudad_nombre` depende de `ciudad_id`, no de `cliente_id`).
- **Solución 3NF**: Separar en tabla `Ciudad(ciudad_id, ciudad_nombre)` y relacionar por FK.

---

### El Gran Giro en Data Warehousing: Desnormalización

- En **OLTP** querés **3NF** porque realizás miles de `INSERT`/`UPDATE` por segundo y no querés duplicar datos.
- En **OLAP/DW** querés **DESNORMALIZAR** (Esquema en Estrella). 
  - Guardás `ciudad_nombre`, `provincia` y `pais` en la misma tabla `Dim_Cliente`.
  - **Razón**: En OLAP casi no hay `UPDATEs` (los datos se cargan en lote y no cambian). Al eliminar la necesidad de hacer `JOINs` con las tablas de `Ciudad`, `Provincia` y `Pais`, las consultas de lectura analítica son órdenes de magnitud más rápidas.

---

## Módulo 4: SQL Analítico Indispensable

Para DW & OLAP es necesario dominar el SQL que va más allá del `SELECT * FROM tabla`.

### 1. Tipos de JOIN y comportamiento con Nulos
- `INNER JOIN`: Retorna solo las filas que coinciden en ambas tablas.
- `LEFT JOIN`: Retorna todas las filas de la tabla izquierda y las coincidencias de la derecha (si no hay coincidencia, devuelve `NULL`).
  > En las tablas de hechos se usa `LEFT JOIN` hacia las dimensiones para evitar perder métricas si falta una dimensión asociada.

### 2. Agregaciones Tradicionales: `WHERE` vs. `HAVING`
- `WHERE`: Filtra filas **antes** de realizar el agrupamiento (`GROUP BY`).
- `HAVING`: Filtra grupos **después** de calcular la agregación.

```sql
SELECT 
    categoria_id,
    SUM(monto_total) AS venta_total
FROM Fact_Ventas
WHERE fecha >= '2026-01-01'          -- 1° Filtra filas individuales
GROUP BY categoria_id
HAVING SUM(monto_total) > 1000000;  -- 2° Filtra el resultado de la agregación
```

---

### 3. Funciones de Ventana (*Window Functions*) — *Obligatorias en OLAP*
Calculan un valor agrupado sin colapsar las filas de salida (a diferencia de `GROUP BY`).

Sintaxis general:
$$\text{FUNCTION}() \text{ OVER } (\text{PARTITION BY } \text{columna\_grupo} \text{ ORDER BY } \text{columna\_orden})$$

#### A) Acumulados y Promedios Móviles
```sql
SELECT 
    fecha,
    cliente_id,
    monto,
    -- Acumulado de ventas por cliente a lo largo del tiempo
    SUM(monto) OVER (
        PARTITION BY cliente_id 
        ORDER BY fecha
    ) AS acumulado_cliente
FROM Fact_Ventas;
```

#### B) Ranking y Paginación (`ROW_NUMBER`, `DENSE_RANK`)
```sql
SELECT 
    cliente_id,
    monto,
    -- Ranking de las mayores compras de cada cliente
    ROW_NUMBER() OVER (
        PARTITION BY cliente_id 
        ORDER BY monto DESC
    ) AS ranking_compra
FROM Fact_Ventas;
```

#### C) Comparación con Períodos Anteriores (`LAG` y `LEAD`)
```sql
SELECT 
    foto_mes,
    cliente_id,
    monto AS monto_mes_actual,
    -- Trae el monto del mes anterior para calcular variación
    LAG(monto, 1) OVER (
        PARTITION BY cliente_id 
        ORDER BY foto_mes
    ) AS monto_mes_anterior
FROM Fact_Ventas;
```

---

### 4. Primitivas OLAP en SQL: `ROLLUP` y `CUBE`

Permiten generar subtotales y totales generales en una sola consulta.

```sql
-- Genera subtotales por Año, por Año+Mes, y el Total General
SELECT 
    anio,
    mes,
    SUM(monto) AS venta_total
FROM Fact_Ventas
GROUP BY ROLLUP (anio, mes);
```

---

## Resumen de la Transición de Contenidos

| Concepto | Sistema Transaccional (OLTP) | Almacén de Datos (OLAP / DW) |
| :--- | :--- | :--- |
| **Diseño de tablas** | Normalizado (3NF) | Desnormalizado (Estrella / Copo de Nieve) |
| **Claves principales** | Claves Naturales (DNI, CUIT, SKU) | Surrogate Keys (Claves sustitutas numéricas) |
| **Operación principal** | `INSERT`, `UPDATE` rápido fila a fila | Lecturas analíticas masivas y cargas en lote |
| **Consultas SQL** | CRUD simple (`JOIN` de 3-5 tablas) | SQL Analítico (`Window Functions`, `ROLLUP`) |
| **Históricos** | Solo el estado actual del registro | Seguimiento de cambios en el tiempo (SCD Tipo 2) |

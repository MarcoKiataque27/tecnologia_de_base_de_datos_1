# Tecnología de Base de Datos I — Migración MariaDB → PostgreSQL 18

**Estudiante:** Marco Antonio Kiataque Uchima · **Docente:** Ing. Jared Lopez Leaños
**Universidad Privada Domingo Savio** — Facultad de Ingeniería, Santa Cruz – Bolivia
**Entrega:** 29 de septiembre de 2026 · **Consigna:** migrar tablas y vistas de `employees` desde MariaDB a PostgreSQL 18 en Docker y verificar la migración con consultas.

## Conexión con la Actividad 5 (contexto del proyecto final)

El proyecto final continúa la Actividad 5, donde se dejó lista la **estructura**: diccionario de 24 columnas extraído de `information_schema.COLUMNS`, diseño de 6 entidades en PgModeler y base `pdb_employees` creada con el DDL adaptado (`int(11)` → `integer`, `enum` → `CREATE TYPE gender_enum`, sin `ENGINE/CHARSET`). El proyecto final llena esa estructura con los ~3.9M de registros (pgloader casteó `enum → text`, `int → bigint`), migra las 2 vistas, lo verifica todo con consultas en ambos motores y lo respalda. Detalle completo de la base en `actividad-5/`.

![Diagrama ER employees en PgModeler](actividad-5/employees_diagrama.png)

El diagrama muestra las 6 relaciones 1:N: `employees → dept_emp`, `departments → dept_emp`, `employees → dept_manager`, `departments → dept_manager`, `employees → salaries`, `employees → titles`. Las FK hijas son `NOT NULL` y forman PK compuestas — por eso la verificación de huérfanos es el corazón del Punto 3.

## Qué hay en la raíz, archivo por archivo (lo que pidió el ingeniero)

| Archivo | Qué es | Qué punto cubre |
|---|---|---|
| `Informes/` | Informe final MD + PDF (exportado del Word) + README de la carpeta | Formato: Markdown, portada, código, salidas en texto, referencias |
| `final_conteos_mariadb.txt` | Conteos 9 / 331603 / 24 / 300024 / 2844047 / 443308 lado origen | Punto 3.2 (conteo ambos lados) |
| `prueba_vista_current.txt` | Vista vigente: 240124 + 10 filas reales | Punto 2.3 (probar vistas) |
| `prueba_vista_latest.txt` | Vista agrupada: 300024 + 10 filas reales | Punto 2.3 |
| `huerfanos_mariadb.txt` / `huerfanos_postgresql.txt` | 0 huérfanos en las 6 relaciones, ambos motores | Punto 3.1 (integridad referencial) |
| `checksums_mariadb.txt` / `checksums_postgresql.txt` | MD5 idénticos `fa8cbd70…` y `1e7bec35…` | Punto 3.1 (checksums) |
| `vista_latest_mariadb.txt` | `SHOW CREATE VIEW dept_emp_latest_date` original | Punto 2.1 (extraer definiciones) |
| `verificacion_backup.txt` | TOC de 62 entradas del `.dump` | Respaldo validado |
| `docker-compose.yml` | `postgresql` 18 (`5432`), `mariadb` 11.8.9 (`3306`), `adminer` (`8081`), `pgadmin` (`8080`); `marco` / `123123`, `America/La_Paz` | Escenario Docker |
| `migracion.load` | `mysql://root:123456@127.0.0.1:3306/employees → postgresql://marco:123123@127.0.0.1:5432/employees`, 8 workers, `enum→text` | Punto 1.2 (pgloader) |
| `ac06.sh` (v2) | 7 fases: vistas, conteos ×2, MD5 ×2, huérfanos 6×2, pruebas, backup + TOC | Automatización auditable |
| `pdb_employees_backup.dump` | Backup CUSTOM gzip ~36 MB: esquema `employees` (datos) + `public` (DDL Act5), 6 tablas, 2 vistas, PK/FK | Backup adjunto |
| `actividad-5/` | Todo lo de la Act5 con su propio README | Contexto y base del proyecto |

## Todos los códigos ocupados en la migración

### 0. Entorno Docker Compose (`docker-compose.yml`)

```yaml
services:
  postgres:
    image: postgres:18
    container_name: postgresql
    restart: unless-stopped
    environment:
      POSTGRES_DB: pdb_marco
      POSTGRES_USER: marco
      POSTGRES_PASSWORD: 123123
      TZ: 'America/La_Paz'
      PGTZ: 'America/La_Paz'
    command: ["postgres", "-c", "timezone=America/La_Paz"]
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U marco -d pdb_marco"]
      interval: 10s
      timeout: 5s
      retries: 5
  mariadb:
    image: mariadb:11.8.9-ubi9
    container_name: mariadb
    restart: always
    environment:
      MARIADB_ROOT_PASSWORD: 123456
      MARIADB_DATABASE: mdb_marco
      MARIADB_USER: marco
      MARIADB_PASSWORD: 123123
    volumes:
      - mariadb_data:/var/lib/mysql
    ports:
      - "3306:3306"
  adminer:
    image: adminer
    container_name: adminer
    restart: always
    ports:
      - "8081:8080"
  pgadmin:
    image: dpage/pgadmin4
    container_name: pgadmin4
    restart: always
    ports:
      - "8080:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@upds.com
      PGADMIN_DEFAULT_PASSWORD: 123123
    volumes:
      - pgadmin-data:/var/lib/pgadmin
volumes:
  mariadb_data:
  postgres_data:
  pgadmin-data:
```

Se levanta con `docker pull mariadb:11.8.9-ubi9`, `docker compose down -v` (entorno limpio) y `docker compose up -d`. El `healthcheck` con `pg_isready` evita correr comandos antes de que PostgreSQL acepte conexiones; la zona horaria `America/La_Paz` deja las fechas coherentes con Bolivia.

### 1. Carga de la BD origen en MariaDB

```bash
tar -xvf test_db-master.tar.gz
cd test_db-master/
mariadb -h 127.0.0.1 -u root -p < employees.sql
mariadb -h 127.0.0.1 -u root -p < test_employees_sha.sql
```

El `test_employees_sha.sql` valida integridad comparando filas y CRC tabla por tabla (`records_match OK / crc_match ok`, `summary result CRC OK`):

```text
table_name expected_records expected_crc
departments 9 4b315afa0e35ca6649df897b958345bcb3d2b764
dept_emp 331603 d95ab9fe07df0865f592574b3b33b9c741d9fd1b
dept_manager 24 9687a7d6f93ca8847388a42a6d8d93982a841c6c
employees 300024 4d4aa689914d8fd41db7e45c2168e7dcb9697359
salaries 2844047 b5a1785c27d75e33a4173aaa22ccf41ebd7d4a9f
titles 443308 d12d5f746b88f07e69b9e36675b6067abb01b60e
```

### 2. Análisis pre-migración (tablas, vistas, estructura)

```sql
-- Tablas y tamaños
SELECT table_name, table_rows, data_length, index_length
FROM information_schema.tables
WHERE table_schema = 'employees'
ORDER BY data_length DESC;
-- Vistas del origen
SELECT table_name FROM information_schema.views
WHERE table_schema = 'employees';
-- Resultado: dept_emp_latest_date, current_dept_emp
```

```bash
# Solo estructura, sin datos
docker exec mariadb mariadb-dump -u root -p123456 --no-data employees > employees-estructura.sql
```

El dump trae los 6 `CREATE TABLE` (`ENGINE=InnoDB`, `int(11)`, `enum('M','F')`, backticks) y las 2 vistas. Las vistas no viajan solas con pgloader: hay que recrearlas a mano.

### 3. Migración de tablas con pgloader — `migracion.load` (Punto 1)

```text
LOAD DATABASE
    FROM mysql://root:123456@127.0.0.1:3306/employees
    INTO postgresql://marco:123123@127.0.0.1:5432/employees
WITH include drop,
    create tables,
    create indexes,
    reset sequences,
    workers = 8, concurrency = 2,
    batch rows = 10000
SET maintenance_work_mem to '256MB',
    work_mem to '32MB'
CAST type datetime to timestamptz drop default drop not null
        using zero-dates-to-null,
     type enum to text
;
```

```bash
psql -h localhost -U marco -d pdb_marco -c "CREATE DATABASE employees;"
pgloader migracion.load
```

Reporte (acta de la migración, 0 errores):

```text
             table name     errors       rows      bytes      total time
-----------------------  ---------  ---------  ---------  --------------
     employees.salaries          0    2844047    94.2 MB         12.282s
       employees.titles          0     443308    16.9 MB          3.682s
     employees.dept_emp          0     331603    10.7 MB          7.832s
    employees.employees          0     300024    13.2 MB          6.219s
  employees.departments          0          9     0.1 kB          0.032s
  employees.dept_manager          0         24     0.8 kB          0.020s
         Create Indexes          0          9                     3.090s
           Primary Keys          0          6                     0.028s
    Create Foreign Keys          0          6                     0.716s
      Total import time          ✓    3919015   134.9 MB         17.901s
```

Decisión de casteo: `enum → text` (por eso `gender` queda `text`) y `datetime → timestamptz`; distinto del DDL manual de la Act5 (`gender_enum`, `integer`).

### 4. Conteos en ambos lados (Punto 3.2)

```bash
mariadb -h 127.0.0.1 -u root -p123456 -D employees -e "SELECT 'departments' AS tabla, COUNT(*) AS filas FROM departments UNION ALL SELECT 'dept_emp', COUNT(*) FROM dept_emp UNION ALL SELECT 'dept_manager', COUNT(*) FROM dept_manager UNION ALL SELECT 'employees', COUNT(*) FROM employees UNION ALL SELECT 'salaries', COUNT(*) FROM salaries UNION ALL SELECT 'titles', COUNT(*) FROM titles;" > final_conteos_mariadb.txt
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT 'employees.employees' AS tabla, COUNT(*) FROM employees.employees UNION ALL SELECT 'employees.departments', COUNT(*) FROM employees.departments UNION ALL SELECT 'employees.dept_emp', COUNT(*) FROM employees.dept_emp UNION ALL SELECT 'employees.dept_manager', COUNT(*) FROM employees.dept_manager UNION ALL SELECT 'employees.salaries', COUNT(*) FROM employees.salaries UNION ALL SELECT 'employees.titles', COUNT(*) FROM employees.titles;"
```

| Tabla | MariaDB | PostgreSQL | Coincide |
|---|---:|---:|---|
| departments | 9 | 9 | Sí |
| dept_emp | 331603 | 331603 | Sí |
| dept_manager | 24 | 24 | Sí |
| employees | 300024 | 300024 | Sí |
| salaries | 2844047 | 2844047 | Sí |
| titles | 443308 | 443308 | Sí |

### 5. Checksums MD5 comparativos (Punto 3.1)

Comparan **contenido**, no solo cantidad (`GROUP_CONCAT` ordenado por PK en MariaDB, `STRING_AGG` equivalente en PG):

```bash
mariadb -h 127.0.0.1 -u root -p123456 -D employees -e "SET SESSION group_concat_max_len = 1000000; SELECT 'departments' AS tabla, MD5(GROUP_CONCAT(CONCAT_WS('|', dept_no, dept_name) ORDER BY dept_no SEPARATOR ';;')) AS checksum FROM departments UNION ALL SELECT 'dept_manager', MD5(GROUP_CONCAT(CONCAT_WS('|', emp_no, dept_no, from_date, to_date) ORDER BY emp_no, dept_no SEPARATOR ';;')) FROM dept_manager;" > checksums_mariadb.txt
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT 'departments' AS tabla, MD5(STRING_AGG(CONCAT_WS('|', dept_no, dept_name), ';;' ORDER BY dept_no)) AS checksum FROM employees.departments UNION ALL SELECT 'dept_manager', MD5(STRING_AGG(CONCAT_WS('|', emp_no::text, dept_no, from_date::text, to_date::text), ';;' ORDER BY emp_no, dept_no)) FROM employees.dept_manager;" > checksums_postgresql.txt
```

| Tabla | MariaDB | PostgreSQL | Resultado |
|---|---|---|---|
| `departments` | `fa8cbd703ad11e1f06b31874f4ae55b5` | `fa8cbd703ad11e1f06b31874f4ae55b5` | Coincide |
| `dept_manager` | `1e7bec3546440ceca470f44da37de99f` | `1e7bec3546440ceca470f44da37de99f` | Coincide |

### 6. Huérfanos 6 relaciones × 2 motores (Punto 3.1)

`LEFT JOIN` contra el padre filtrando `IS NULL`: cada fila sería un huérfano.

```bash
mariadb -h 127.0.0.1 -u root -p123456 -D employees -e "SELECT 'dept_emp -> employees' AS relacion, COUNT(*) AS huerfanos FROM dept_emp d LEFT JOIN employees e ON d.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'dept_emp -> departments', COUNT(*) FROM dept_emp d LEFT JOIN departments p ON d.dept_no = p.dept_no WHERE p.dept_no IS NULL UNION ALL SELECT 'dept_manager -> employees', COUNT(*) FROM dept_manager d LEFT JOIN employees e ON d.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'dept_manager -> departments', COUNT(*) FROM dept_manager d LEFT JOIN departments p ON d.dept_no = p.dept_no WHERE p.dept_no IS NULL UNION ALL SELECT 'salaries -> employees', COUNT(*) FROM salaries s LEFT JOIN employees e ON s.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'titles -> employees', COUNT(*) FROM titles t LEFT JOIN employees e ON t.emp_no = e.emp_no WHERE e.emp_no IS NULL;" > huerfanos_mariadb.txt
psql -h 127.0.0.1 -U marco -d pdb_employees -v ON_ERROR_STOP=1 -c "SET max_parallel_workers_per_gather = 0; SET work_mem = '4MB';" -c "SELECT 'dept_emp -> employees' AS relacion, COUNT(*) AS huerfanos FROM employees.dept_emp d LEFT JOIN employees.employees e ON d.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'dept_emp -> departments', COUNT(*) FROM employees.dept_emp d LEFT JOIN employees.departments p ON d.dept_no = p.dept_no WHERE p.dept_no IS NULL UNION ALL SELECT 'dept_manager -> employees', COUNT(*) FROM employees.dept_manager d LEFT JOIN employees.employees e ON d.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'dept_manager -> departments', COUNT(*) FROM employees.dept_manager d LEFT JOIN employees.departments p ON d.dept_no = p.dept_no WHERE p.dept_no IS NULL UNION ALL SELECT 'salaries -> employees', COUNT(*) FROM employees.salaries s LEFT JOIN employees.employees e ON s.emp_no = e.emp_no WHERE e.emp_no IS NULL UNION ALL SELECT 'titles -> employees', COUNT(*) FROM employees.titles t LEFT JOIN employees.employees e ON t.emp_no = e.emp_no WHERE e.emp_no IS NULL;" > huerfanos_postgresql.txt
```

Resultado: **0 huérfanos en las 6 relaciones, en ambos motores**. Los dos `SET` previos en PG son el workaround de memoria compartida (`/dev/shm` de 64 MB en el contenedor): desactivan el paralelismo y bajan `work_mem` solo en esa sesión, sin tocar datos.

### 7. Vistas: definición original, adaptación y prueba (Punto 2)

Definición original capturada (`SHOW CREATE VIEW`, Punto 2.1):

```bash
docker exec mariadb mariadb -u root -p123456 -D employees -e "SHOW CREATE VIEW current_dept_emp;" > vistas_mariadb.txt
docker exec mariadb mariadb -u root -p123456 -D employees -e "SHOW CREATE VIEW dept_emp_latest_date;" > vista_latest_mariadb.txt
```

```text
dept_emp_latest_date	CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `dept_emp_latest_date` AS select `dept_emp`.`emp_no` AS `emp_no`,max(`dept_emp`.`from_date`) AS `from_date`,max(`dept_emp`.`to_date`) AS `to_date` from `dept_emp` group by `dept_emp`.`emp_no`
```

Recreación adaptada en PostgreSQL (Punto 2.2: sin `ALGORITHM`/`DEFINER`/backticks, con `search_path` al esquema `employees`):

```bash
psql -h 127.0.0.1 -U marco -d pdb_employees -c "
SET search_path TO employees, public;
CREATE OR REPLACE VIEW current_dept_emp AS
SELECT l.emp_no, d.dept_no, l.from_date, l.to_date
FROM dept_emp l JOIN departments d ON l.dept_no = d.dept_no
WHERE l.to_date = '9999-01-01';
CREATE OR REPLACE VIEW dept_emp_latest_date AS
SELECT emp_no, MAX(from_date) AS from_date, MAX(to_date) AS to_date
FROM dept_emp GROUP BY emp_no;"
```

Pruebas con datos reales (Punto 2.3):

```bash
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT COUNT(*) AS filas_current FROM employees.current_dept_emp; SELECT * FROM employees.current_dept_emp LIMIT 10;" > prueba_vista_current.txt
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT COUNT(*) AS filas_latest FROM employees.dept_emp_latest_date; SELECT * FROM employees.dept_emp_latest_date LIMIT 10;" > prueba_vista_latest.txt
```

`current_dept_emp`: **240124** filas (solo vigentes `9999-01-01`); `dept_emp_latest_date`: **300024** (uno por empleado). Primeras filas: `10001 | d005 | 1986-06-26 | 9999-01-01`, etc.

### 8. Backup y restore + validación TOC

```bash
pg_dump -h 127.0.0.1 -U marco -d employees -F c -b -v -f temp_employees.dump
pg_restore -h 127.0.0.1 -U marco -d pdb_employees -v temp_employees.dump
# crea SCHEMA employees, 6 TABLE, datos, 6 CONSTRAINT PK, 3 INDEX, 6 FK
pg_dump -h 127.0.0.1 -U marco -d pdb_employees -F c -b -v -f pdb_employees_backup.dump
pg_restore -l pdb_employees_backup.dump > verificacion_backup.txt
```

El TOC de **62 entradas** confirma: esquema `employees` (6 tablas + datos + 2 vistas + PK/FK `ibfk`), esquema `public` (DDL Act5 + `gender_enum` + FK `fk_*`).

### 9. Automatización (`ac06.sh` v2)

Las 7 fases anteriores empaquetadas (`./ac06.sh | tee migracion.log`): vistas, conteos ×2, MD5 ×2, huérfanos 6×2, pruebas, backup + TOC. Ver script completo en `ac06.sh`.

## Resultados

3 919 015 filas migradas sin errores; conteos y MD5 idénticos; 0 huérfanos en 6 relaciones × 2 motores; vistas con datos (240124 vigentes, 300024 agrupados); backup de 62 entradas validado. Incidencias resueltas: `ERROR 1045/1046` y memoria compartida. Eje transversal (emergentes/adaptabilidad, pensamiento crítico) y ODS 4/10 en el informe.

## Referencias (APA 7)

PostgreSQL Global Development Group. (2026). *PostgreSQL 18 documentation*. https://www.postgresql.org/docs/ · MariaDB Foundation. (2026). *mariadb-dump overview*. https://mariadb.com/kb/en/mariadb-dump/ · pgloader Project. (2026). *pgloader reference manual (v3.6)*. https://pgloader.readthedocs.io/ · PgModeler. (2026). *Data modeling tool for PostgreSQL*. https://pgmodeler.io/ · Datacharmer. (2026). *test_db: MySQL employees sample database*. https://github.com/datacharmer/test_db

*Informe: Marco Antonio Kiataque Uchima — TBDI, docente Ing. Jared Lopez Leaños, UPDS Santa Cruz 2026. Entrega: 29 de septiembre de 2026.*

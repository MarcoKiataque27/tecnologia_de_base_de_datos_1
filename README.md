# Tecnología de Base de Datos I — Migración MariaDB → PostgreSQL 18

**Estudiante:** Marco Antonio Kiataque Uchima · **Docente:** Jared Lopez Leaños
**Universidad Privada Domingo Savio** — Facultad de Ingeniería, Santa Cruz – Bolivia
**Entrega:** 29 de septiembre de 2026 · **Entregable final:** migrar tablas y vistas de `employees` desde MariaDB a PostgreSQL 18 en Docker y verificar la migración con consultas.

Este repositorio une en secuencia la **Actividad 5** (diccionario + diseño + estructura) y el **Proyecto Final** (datos + vistas + verificación + backup). La Act. 5 deja la estructura `pdb_employees`; el proyecto final la llena con los ~3.9M de registros, migra las 2 vistas, lo verifica todo y lo respalda.

## Estructura del repositorio

```text
tecnologia_de_base_de_datos_1/
├── README.md                        # este archivo: guía completa del proyecto
├── Informes/                        # SOLO informes del proyecto final (norma APA 7)
│   ├── README.md
│   ├── Proyecto_Final_Informe.md
│   ├── Proyecto_Final_Informe.pdf
│   └── Proyecto_Final_Informe.docx
├── actividad-5/                     # TODO lo de la Actividad 5 (base del proyecto)
│   ├── README.md                    # explica solo la Act5
│   ├── Actividad_5_Informe.md
│   ├── Actividad_5_Informe.pdf
│   ├── employees_diagrama.png       # diagrama ER de PgModeler
│   └── employees_postgres.sql       # DDL adaptado a PostgreSQL
├── docker-compose.yml               # entorno Docker del laboratorio
├── migracion.load                   # script de migración pgloader
├── ac06.sh                          # vistas + verificación + backup automatizados
└── pdb_employees_backup.dump        # backup binario final (pg_dump -F c, ~36 MB)
```

## Qué hay en la raíz, archivo por archivo (lo que pidió el ingeniero)

| Archivo | Qué es | Qué punto de la consigna cubre |
|---|---|---|
| `Informes/` | Informes del proyecto final en MD + PDF + Word con norma APA 7 | Formato de entrega: informe Markdown, portada, encabezados, código, salidas en texto, referencias |
| `actividad-5/` | Informe, diagrama y DDL de la Act5 (contexto del proyecto) | Base: diccionario, diseño PgModeler, estructura `pdb_employees` |
| `docker-compose.yml` | 4 servicios: `postgresql` (18, `5432`), `mariadb` (11.8.9, `3306`), `adminer` (`8081`), `pgadmin` (`8080`); usuario `marco` / `123123`, `TZ America/La_Paz` | Escenario: entorno Docker Compose |
| `migracion.load` | `LOAD DATABASE mysql://root:123456@127.0.0.1:3306/employees → postgresql://marco:123123@127.0.0.1:5432/employees`, 8 workers, `enum→text` | Punto 1.2: importar con pgloader |
| `ac06.sh` | Extrae vistas, las recrea en PG, verifica conteos y genera el `.dump` | Automatización y auditoría del proceso |
| `pdb_employees_backup.dump` | Backup CUSTOM gzip, 62 entradas TOC: esquema `employees` (datos) + `public` (DDL Act5), 6 tablas, 2 vistas, PK/FK | Backup adjunto exigido |

## Parte 1 — Actividad 5 (contexto del proyecto final)

### 1. Diccionario de datos

```bash
mariadb -h 127.0.0.1 -P 3306 -u marco -p123123 -e "
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'employees'
ORDER BY TABLE_NAME, ORDINAL_POSITION;"
```

Se documentan 6 tablas y 24 columnas (PK simples y compuestas, 8 FK, UNIQUE en `departments.dept_name`, única anulable `titles.to_date`). Tabla completa en `actividad-5/Actividad_5_Informe.md`.

### 2. Diseño en PgModeler

Se modelan `employees` y `departments` (fuertes), `dept_emp` y `dept_manager` (N:M), `salaries` y `titles` (historial 1:N). Se exporta la imagen y el DDL.

![Diagrama ER employees en PgModeler](actividad-5/employees_diagrama.png)

Relaciones 1:N: `employees → dept_emp`, `departments → dept_emp`, `employees → dept_manager`, `departments → dept_manager`, `employees → salaries`, `employees → titles`. Las FK hijas son `NOT NULL` y forman PK compuestas.

### 3. Migración de estructura

```bash
docker exec mariadb mariadb-dump -u root -p123456 --no-data employees > employees-estructura.sql
psql -h 127.0.0.1 -U marco -d pdb_marco -c "CREATE DATABASE pdb_employees;"
psql -h 127.0.0.1 -U marco -d pdb_employees -f employees_postgres.sql
psql -h 127.0.0.1 -U marco -d pdb_employees -c "\dt"
```

Adaptaciones MariaDB → PostgreSQL: backticks → comillas dobles, `int(11)` → `integer`, `enum('M','F')` → `CREATE TYPE gender_enum`, se elimina `ENGINE=InnoDB DEFAULT CHARSET`. Detalle en `actividad-5/employees_postgres.sql`.

## Parte 2 — Proyecto Final

### 4. Entorno y carga origen

```bash
cd ~/tecBD1 && docker compose up -d
tar -xvf test_db-master.tar.gz && cd test_db-master/
mariadb -h 127.0.0.1 -u root -p < employees.sql
mariadb -h 127.0.0.1 -u root -p < test_employees_sha.sql   # CRC OK + count OK en las 6 tablas
```

### 5. Migración de tablas con pgloader (Punto 1)

```bash
psql -h localhost -U marco -d pdb_marco -c "CREATE DATABASE employees;"
pgloader migracion.load
# Total import time: 3919015 filas, 134.9 MB, 0 errores
```

### 6. Verificación: conteos ambos lados + checksums + huérfanos (Punto 3)

```bash
# Conteos MariaDB
mariadb -h 127.0.0.1 -u root -p123456 -D employees -e "SELECT 'departments', COUNT(*) FROM departments UNION ALL SELECT 'dept_emp', COUNT(*) FROM dept_emp UNION ALL SELECT 'dept_manager', COUNT(*) FROM dept_manager UNION ALL SELECT 'employees', COUNT(*) FROM employees UNION ALL SELECT 'salaries', COUNT(*) FROM salaries UNION ALL SELECT 'titles', COUNT(*) FROM titles;"
# Conteos PostgreSQL
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT 'employees.employees', COUNT(*) FROM employees.employees UNION ALL SELECT 'employees.departments', COUNT(*) FROM employees.departments UNION ALL SELECT 'employees.dept_emp', COUNT(*) FROM employees.dept_emp UNION ALL SELECT 'employees.dept_manager', COUNT(*) FROM employees.dept_manager UNION ALL SELECT 'employees.salaries', COUNT(*) FROM employees.salaries UNION ALL SELECT 'employees.titles', COUNT(*) FROM employees.titles;"
# Checksums MD5 (contenido, no solo cantidad)
mariadb -h 127.0.0.1 -u root -p123456 -D employees -e "SET SESSION group_concat_max_len = 1000000; SELECT 'departments', MD5(GROUP_CONCAT(CONCAT_WS('|', dept_no, dept_name) ORDER BY dept_no SEPARATOR ';;')) FROM departments UNION ALL SELECT 'dept_manager', MD5(GROUP_CONCAT(CONCAT_WS('|', emp_no, dept_no, from_date, to_date) ORDER BY emp_no, dept_no SEPARATOR ';;')) FROM dept_manager;"
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT 'departments', MD5(STRING_AGG(CONCAT_WS('|', dept_no, dept_name), ';;' ORDER BY dept_no)) FROM employees.departments UNION ALL SELECT 'dept_manager', MD5(STRING_AGG(CONCAT_WS('|', emp_no::text, dept_no, from_date::text, to_date::text), ';;' ORDER BY emp_no, dept_no)) FROM employees.dept_manager;"
# Huérfanos 6 relaciones x 2 motores (en PG con workaround de memoria: SET max_parallel_workers_per_gather = 0; SET work_mem = '4MB';)
```

| Tabla | MariaDB | PostgreSQL | MD5 | Huérfanos |
|---|---:|---:|---|---|
| departments | 9 | 9 | `fa8cbd70…` = `fa8cbd70…` | 0 / 0 |
| dept_emp | 331603 | 331603 | — | 0 / 0 |
| dept_manager | 24 | 24 | `1e7bec35…` = `1e7bec35…` | 0 / 0 |
| employees | 300024 | 300024 | — | — |
| salaries | 2844047 | 2844047 | — | 0 / 0 |
| titles | 443308 | 443308 | — | 0 / 0 |

### 7. Vistas (Punto 2)

```bash
docker exec mariadb mariadb -u root -p123456 -D employees -e "SHOW CREATE VIEW dept_emp_latest_date;"
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SET search_path TO employees, public; CREATE OR REPLACE VIEW current_dept_emp AS SELECT l.emp_no, d.dept_no, l.from_date, l.to_date FROM dept_emp l JOIN departments d ON l.dept_no = d.dept_no WHERE l.to_date = '9999-01-01'; CREATE OR REPLACE VIEW dept_emp_latest_date AS SELECT emp_no, MAX(from_date) AS from_date, MAX(to_date) AS to_date FROM dept_emp GROUP BY emp_no;"
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT COUNT(*) FROM employees.current_dept_emp;"    # 240124 vigentes
psql -h 127.0.0.1 -U marco -d pdb_employees -c "SELECT COUNT(*) FROM employees.dept_emp_latest_date;" # 300024
```

Se eliminan `ALGORITHM`, `DEFINER` y backticks de MariaDB. `current_dept_emp` filtra vigentes (`9999-01-01`, 240124); `dept_emp_latest_date` agrupa uno por empleado (300024).

### 8. Backup y restore

```bash
pg_dump -h 127.0.0.1 -U marco -d employees -F c -b -v -f temp_employees.dump
pg_restore -h 127.0.0.1 -U marco -d pdb_employees -v temp_employees.dump
pg_dump -h 127.0.0.1 -U marco -d pdb_employees -F c -b -v -f pdb_employees_backup.dump
pg_restore -l pdb_employees_backup.dump   # TOC: 62 entradas (esquemas, tablas, datos, 2 vistas, PK/FK)
```

Todo automatizado en `ac06.sh` (`./ac06.sh | tee migracion.log`).

## Eje transversal y ODS

Tecnologías emergentes y adaptabilidad digital (Docker, PostgreSQL 18, pgloader, PgModeler, GitHub) + investigación y pensamiento crítico (casteos, ERROR 1045/1046 y memoria compartida resueltos con criterio). ODS 4 (educación de calidad) y ODS 10 (reducción de desigualdades, open source).

## Incidencias resueltas

`ERROR 1045` (clave root `123456`), `ERROR 1046` (BD no seleccionada) y `could not resize shared memory segment` en huérfanos PG (resuelto con `max_parallel_workers_per_gather = 0` + `work_mem = '4MB'` solo en esa sesión).

## Referencias (APA 7)

PostgreSQL Global Development Group. (2026). *PostgreSQL 18 documentation*. https://www.postgresql.org/docs/ · MariaDB Foundation. (2026). *mariadb-dump overview*. https://mariadb.com/kb/en/mariadb-dump/ · pgloader Project. (2026). *pgloader reference manual (v3.6)*. https://pgloader.readthedocs.io/ · PgModeler. (2026). *Data modeling tool for PostgreSQL*. https://pgmodeler.io/ · Datacharmer. (2026). *test_db: MySQL employees sample database*. https://github.com/datacharmer/test_db

*Informe: Marco Antonio Kiataque Uchima — TBDI, docente Jared Lopez Leaños, UPDS Santa Cruz 2026. Entrega: 29 de septiembre de 2026.*

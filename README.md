# Tecnología de Base de Datos I — Migración MariaDB → PostgreSQL 18

**Estudiante:** Marco Antonio Kiataque Uchima · **Docente:** Ing. Jared Lopez Leaños
**Universidad Privada Domingo Savio** — Facultad de Ingeniería, Santa Cruz – Bolivia
**Entrega:** 29 de septiembre de 2026 · **Consigna:** migrar tablas y vistas de `employees` desde MariaDB a PostgreSQL 18 en Docker y verificar la migración con consultas.

## Conexión con la Actividad 5 (contexto del proyecto final)

El proyecto final continúa la Actividad 5, donde se dejó lista la **estructura**: diccionario de 24 columnas, diseño de 6 entidades en PgModeler y base `pdb_employees` creada con el DDL adaptado (`integer`, `CREATE TYPE gender_enum`, sin `ENGINE/CHARSET`). El proyecto final llena esa estructura con los ~3.9M de registros (pgloader casteó `enum → text`, `bigint`), migra las 2 vistas, lo verifica todo y lo respalda. Detalle completo en `actividad-5/`.

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

## Comandos usados (resumen reproducible)

```bash
# Entorno y carga origen
cd ~/tecBD1 && docker compose up -d
mariadb -h 127.0.0.1 -u root -p < employees.sql
mariadb -h 127.0.0.1 -u root -p < test_employees_sha.sql   # CRC OK + count OK
# Estructura (Act5) + migración de datos (Punto 1)
docker exec mariadb mariadb-dump -u root -p123456 --no-data employees > employees-estructura.sql
psql -h 127.0.0.1 -U marco -d pdb_marco -c "CREATE DATABASE employees;"
pgloader migracion.load                                    # 3919015 filas, 134.9 MB, 0 errores
# Vistas (Punto 2): SHOW CREATE VIEW en MariaDB, CREATE OR REPLACE VIEW en PG (sin DEFINER/backticks)
# Verificación (Punto 3): conteos UNION ALL ×2, MD5 STRING_AGG/GROUP_CONCAT, huérfanos LEFT JOIN ×6×2
# Backup: pg_dump -F c -b + pg_restore + pg_restore -l (TOC 62)
./ac06.sh | tee migracion.log                              # todo lo anterior automatizado
```

## Resultados

3 919 015 filas migradas sin errores; conteos y MD5 idénticos; 0 huérfanos en 6 relaciones × 2 motores; vistas con datos (240124 vigentes, 300024 agrupados); backup validado. Incidencias resueltas: `ERROR 1045/1046` y memoria compartida (`max_parallel_workers_per_gather = 0` + `work_mem = '4MB'`). Eje transversal (emergentes/adaptabilidad, pensamiento crítico) y ODS 4/10 en el informe.

## Referencias (APA 7)

PostgreSQL Global Development Group. (2026). *PostgreSQL 18 documentation*. https://www.postgresql.org/docs/ · MariaDB Foundation. (2026). *mariadb-dump overview*. https://mariadb.com/kb/en/mariadb-dump/ · pgloader Project. (2026). *pgloader reference manual (v3.6)*. https://pgloader.readthedocs.io/ · PgModeler. (2026). *Data modeling tool for PostgreSQL*. https://pgmodeler.io/ · Datacharmer. (2026). *test_db: MySQL employees sample database*. https://github.com/datacharmer/test_db

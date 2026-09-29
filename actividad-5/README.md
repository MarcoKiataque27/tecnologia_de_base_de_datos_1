# Actividad 5 — Diccionario, diseño PgModeler y estructura (base del proyecto final)

**Estudiante:** Marco Antonio Kiataque Uchima · **Docente:** Ing. Jared Lopez Leaños · UPDS, septiembre 2026.

Esta carpeta reúne **todo lo de la Actividad 5**, que es el contexto del proyecto final: aquí se documentó la estructura `pdb_employees` que el proyecto final llenó con los ~3.9M de registros, migró sus 2 vistas y respaldó.

## Lo que se realizó (solo Actividad 5)

### Punto 1 — Diccionario de datos (15 pts)

```bash
mariadb -h 127.0.0.1 -P 3306 -u marco -p123123 -e "
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'employees'
ORDER BY TABLE_NAME, ORDINAL_POSITION;"
```

6 tablas y 24 columnas: PK simples y compuestas, 8 FK, UNIQUE en `departments.dept_name`, única anulable `titles.to_date`. Tabla completa con comentarios explicativos en `Actividad_5_Informe.md`.

### Punto 2 — Diseño en PgModeler (10 pts)

`employees` y `departments` (entidades fuertes), `dept_emp` y `dept_manager` (intersección N:M), `salaries` y `titles` (historial 1:N con PK compuestas). Imagen y DDL exportados:

![Diagrama ER employees en PgModeler](employees_diagrama.png)

Relaciones 1:N: `employees → dept_emp`, `departments → dept_emp`, `employees → dept_manager`, `departments → dept_manager`, `employees → salaries`, `employees → titles`. Las FK hijas son `NOT NULL` y forman PK compuestas — de ahí sale la verificación de huérfanos del proyecto final.

### Punto 3 — Migración de estructura (25 pts)

```bash
docker exec mariadb mariadb-dump -u root -p123456 --no-data employees > employees-estructura.sql
psql -h 127.0.0.1 -U marco -d pdb_marco -c "CREATE DATABASE pdb_employees;"
psql -h 127.0.0.1 -U marco -d pdb_employees -f employees_postgres.sql
psql -h 127.0.0.1 -U marco -d pdb_employees -c "\dt"
psql -h 127.0.0.1 -U marco -d pdb_employees -c "\d employees"
```

Adaptaciones MariaDB → PostgreSQL: backticks → comillas dobles, `int(11)` → `integer`, `enum('M','F')` → `CREATE TYPE gender_enum`, se elimina `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`. Verificado con `\dt` (6 tablas), `\d` e `information_schema`.

| Archivo | Contenido |
|---|---|
| `Actividad_5_Informe.md` / `Actividad_5_Informe.pdf` | Informe completo de la actividad |
| `employees_diagrama.png` | Diagrama ER (también enlazado desde el README raíz) |
| `employees_postgres.sql` | DDL PostgreSQL reutilizado por el proyecto final |

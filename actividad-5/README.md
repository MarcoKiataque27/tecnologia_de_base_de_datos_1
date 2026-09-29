# Actividad 5 — Diccionario, diseño PgModeler y estructura (base del proyecto final)

**Estudiante:** Marco Antonio Kiataque Uchima · **Docente:** Jared Lopez Leaños · UPDS, 28/09/2026.

Esta carpeta reúne **todo lo de la Actividad 5**, que es el contexto del proyecto final: aquí se documentó la estructura `pdb_employees` que el proyecto final llenó con los ~3.9M de registros.

## Lo que se realizó

### Punto 1 — Diccionario de datos (15 pts)

```bash
mariadb -h 127.0.0.1 -P 3306 -u marco -p123123 -e "
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'employees'
ORDER BY TABLE_NAME, ORDINAL_POSITION;"
```

6 tablas y 24 columnas: PK simples y compuestas, 8 FK, UNIQUE en `departments.dept_name`, única anulable `titles.to_date`. Tabla completa en `Actividad_5_Informe.md`.

### Punto 2 — Diseño en PgModeler (10 pts)

`employees` y `departments` (fuertes), `dept_emp` y `dept_manager` (N:M), `salaries` y `titles` (historial 1:N). Imagen + DDL exportados:

![Diagrama ER employees en PgModeler](employees_diagrama.png)

### Punto 3 — Estructura en PostgreSQL (25 pts)

```bash
docker exec mariadb mariadb-dump -u root -p123456 --no-data employees > employees-estructura.sql
psql -h 127.0.0.1 -U marco -d pdb_marco -c "CREATE DATABASE pdb_employees;"
psql -h 127.0.0.1 -U marco -d pdb_employees -f employees_postgres.sql
psql -h 127.0.0.1 -U marco -d pdb_employees -c "\dt"
```

Adaptaciones: backticks → comillas dobles, `int(11)` → `integer`, `enum` → `CREATE TYPE gender_enum`, sin `ENGINE/CHARSET`.

| Archivo | Contenido |
|---|---|
| `Actividad_5_Informe.md` / `.pdf` | Informe completo de la actividad |
| `employees_diagrama.png` | Diagrama ER (también referenciado desde el README raíz) |
| `employees_postgres.sql` | DDL PostgreSQL reutilizado por el proyecto final |

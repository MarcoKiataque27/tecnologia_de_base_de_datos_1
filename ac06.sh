#!/bin/bash
# ==============================================================================
# Script de Migración y Verificación (MariaDB -> PostgreSQL 18)
# Asignatura: Tecnología de Base de Datos I
# Estudiante: Marco Antonio Kiataque Uchima
# ==============================================================================

echo "=== 1. Extrayendo vistas originales desde MariaDB ==="
docker exec -it mariadb mariadb -u root -p123456 -D employees -e "SHOW CREATE VIEW current_dept_emp;" > ~/tecBD1/vistas_mariadb.txt

echo "=== 2. Recreando vistas en PostgreSQL (Esquema employees) ==="
psql -h 127.0.0.1 -U marco -d pdb_employees -c "
SET search_path TO employees, public;

CREATE OR REPLACE VIEW current_dept_emp AS
SELECT l.emp_no, d.dept_no, l.from_date, l.to_date
FROM dept_emp l
JOIN departments d ON l.dept_no = d.dept_no
WHERE l.to_date = '9999-01-01';

CREATE OR REPLACE VIEW dept_emp_latest_date AS
SELECT emp_no, MAX(from_date) AS from_date, MAX(to_date) AS to_date
FROM dept_emp
GROUP BY emp_no;
"

echo "=== 3. Verificando conteo de filas en PostgreSQL ==="
psql -h 127.0.0.1 -U marco -d pdb_employees -c "
SELECT 'employees.employees' AS tabla, COUNT(*) FROM employees.employees
UNION ALL
SELECT 'employees.departments', COUNT(*) FROM employees.departments
UNION ALL
SELECT 'employees.dept_emp', COUNT(*) FROM employees.dept_emp
UNION ALL
SELECT 'employees.dept_manager', COUNT(*) FROM employees.dept_manager
UNION ALL
SELECT 'employees.salaries', COUNT(*) FROM employees.salaries
UNION ALL
SELECT 'employees.titles', COUNT(*) FROM employees.titles;
"

echo "=== 4. Generando Backup Binario (.dump) ==="
pg_dump -h 127.0.0.1 -U marco -d pdb_employees -F c -b -v -f ~/tecBD1/pdb_employees_backup.dump

echo "=== Proceso completado exitosamente ==="

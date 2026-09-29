SET session_replication_role = 'replica';

CREATE TYPE gender_enum AS ENUM ('M', 'F');



DROP TABLE IF EXISTS "current_dept_emp";


DROP TABLE IF EXISTS "departments";
CREATE TABLE "departments" (
  "dept_no" char(4) NOT NULL,
  "dept_name" varchar(40) NOT NULL,
  PRIMARY KEY ("dept_no"),
  UNIQUE ("dept_name")
);


DROP TABLE IF EXISTS "dept_emp";
CREATE TABLE "dept_emp" (
  "emp_no" integer NOT NULL,
  "dept_no" char(4) NOT NULL,
  "from_date" date NOT NULL,
  "to_date" date NOT NULL,
  PRIMARY KEY ("emp_no","dept_no") 
);


DROP TABLE IF EXISTS "dept_emp_latest_date";


DROP TABLE IF EXISTS "dept_manager";
CREATE TABLE "dept_manager" (
  "emp_no" integer NOT NULL,
  "dept_no" char(4) NOT NULL,
  "from_date" date NOT NULL,
  "to_date" date NOT NULL,
  PRIMARY KEY ("emp_no","dept_no") 
);


DROP TABLE IF EXISTS "employees";
CREATE TABLE "employees" (
  "emp_no" integer NOT NULL,
  "birth_date" date NOT NULL,
  "first_name" varchar(14) NOT NULL,
  "last_name" varchar(16) NOT NULL,
  "gender" gender_enum NOT NULL,
  "hire_date" date NOT NULL,
  PRIMARY KEY ("emp_no")
);


DROP TABLE IF EXISTS "salaries";
CREATE TABLE "salaries" (
  "emp_no" integer NOT NULL,
  "salary" integer NOT NULL,
  "from_date" date NOT NULL,
  "to_date" date NOT NULL,
  PRIMARY KEY ("emp_no","from_date") 
);


DROP TABLE IF EXISTS "titles";
CREATE TABLE "titles" (
  "emp_no" integer NOT NULL,
  "title" varchar(50) NOT NULL,
  "from_date" date NOT NULL,
  "to_date" date DEFAULT NULL,
  PRIMARY KEY ("emp_no","title","from_date") 
);







SET session_replication_role = 'origin';

DROP PROCEDURE IF EXISTS proc_export(table_name text, file_name text, format text, separator char(1));
DROP PROCEDURE IF EXISTS proc_import(table_name text, file_name text, format text, separator char(1));

DROP PROCEDURE IF EXISTS proc_export_all(p_directory text, p_format text, p_separator char(1));
DROP PROCEDURE IF EXISTS proc_import_all(p_directory text, p_format text, p_separator char(1));


CREATE OR REPLACE PROCEDURE proc_export(table_name text, file_name text, format text,
                                        separator char(1) DEFAULT E'\t')
LANGUAGE plpgsql
AS $$
DECLARE end_separator char(1) := (SELECT CASE WHEN (format = 'TSV')
                                                THEN E'\t'
                                              ELSE separator END);
BEGIN
  EXECUTE 'COPY ' || table_name || ' TO ' || '''' 
                  || file_name || '''' 
                  || ' WITH (FORMAT CSV, HEADER, DELIMITER ' 
                  || '''' || end_separator || '''' || ')';
END
$$;


CREATE OR REPLACE PROCEDURE proc_export_all(p_directory text, p_format text, p_separator char(1) DEFAULT E'\t')
LANGUAGE plpgsql
AS $$
DECLARE table_name TEXT;
BEGIN
  FOR table_name IN (SELECT tablename FROM pg_tables
                     WHERE schemaname = 'public')
    LOOP
      CALL proc_export(table_name, CONCAT(p_directory, table_name, '.', LOWER(p_format)), p_format, p_separator);
    END LOOP;
END
$$;


CREATE OR REPLACE PROCEDURE proc_import_all(p_directory text, p_format text, p_separator char(1) DEFAULT E'\t')
LANGUAGE plpgsql
AS $$
DECLARE table_name TEXT;
BEGIN
  FOR table_name IN (SELECT tablename FROM pg_tables
                     WHERE schemaname = 'public')
    LOOP
      CALL proc_import(table_name, CONCAT(p_directory, table_name, '.', LOWER(p_format)), p_format, p_separator);
    END LOOP;
END
$$;

CREATE OR REPLACE PROCEDURE proc_import (table_name text, file_name text, format text,
                                         separator char(1) DEFAULT E'\t')
LANGUAGE plpgsql
AS $$

DECLARE end_separator char(1) := (SELECT CASE WHEN (format = 'TSV')
                                                THEN E'\t'
                                              ELSE separator END);
BEGIN
  EXECUTE CONCAT('COPY ', table_name, ' FROM ', '''', file_name, '''',
                 ' WITH (FORMAT CSV, HEADER, DELIMITER ',
                 '''', end_separator, '''', ')');
END
$$;


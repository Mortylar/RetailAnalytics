DROP PROCEDURE IF EXISTS proc_export(table_name text, file_name text, format text, separator char(1));
DROP PROCEDURE IF EXISTS proc_import(table_name text, file_name text, format text, separator char(1));

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


DROP TABLE IF EXISTS PersonalInformation CASCADE;
DROP TABLE IF EXISTS Cards CASCADE;
DROP TABLE IF EXISTS Transaction CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS ProductGrid CASCADE;
DROP TABLE IF EXISTS Stores CASCADE;
DROP TABLE IF EXISTS SKUGRoup CASCADE;
DROP TABLE IF EXISTS DateOfAnalysisFormation CASCADE;

DROP PROCEDURE IF EXISTS proc_export(table_name text, file_name text, format text, separator char(1));
DROP PROCEDURE IF EXISTS proc_import(table_name text, file_name text, format text, separator char(1));

DROP PROCEDURE IF EXISTS proc_export_all(p_directory text, p_format text, p_separator char(1));
DROP PROCEDURE IF EXISTS proc_import_all(p_directory text, p_format text, p_separator char(1));


SET DATESTYLE TO German;

CREATE TABLE IF NOT EXISTS PersonalInformation(
                             Customer_Id SERIAL PRIMARY KEY NOT null,
                             Customer_Name VARCHAR NOT null,
                             Customer_Surname VARCHAR,
                             Customer_Primary_Email VARCHAR,
                             Customer_Primary_Phone VARCHAR
);


CREATE TABLE IF NOT EXISTS SKUGroup(
                             Group_Id SERIAL PRIMARY KEY NOT null,
                             Group_Name VARCHAR
);


CREATE TABLE IF NOT EXISTS Cards(
                             Customer_Card_ID SERIAL PRIMARY KEY NOT null,
                             Customer_Id INTEGER,
                             CONSTRAINT fk_Cards_Customer_Id FOREIGN KEY (Customer_Id)
                                           REFERENCES PersonalInformation(Customer_Id)
);


CREATE TABLE IF NOT EXISTS ProductGrid(
                             SKU_Id SERIAL PRIMARY KEY NOT null,
                             SKU_Name VARCHAR,
                             Group_Id INTEGER,
                             CONSTRAINT fk_ProductGrid_Group_Id FOREIGN KEY (Group_Id)
                                           REFERENCES SKUGroup(Group_Id)
);


CREATE TABLE IF NOT EXISTS Stores(
                             Transaction_Store_Id INTEGER NOT null,
                             SKU_Id INTEGER,
                             SKU_Purchase_Price NUMERIC(12,2),
                             SKU_Retail_Price NUMERIC(12,2),	
                             CONSTRAINT fk_Stores_SKU_Id FOREIGN KEY (SKU_Id)
                                           REFERENCES ProductGrid(SKU_Id)
);


CREATE TABLE IF NOT EXISTS Transaction(
                             Transaction_Id SERIAL PRIMARY KEY NOT null,
                             Customer_Card_Id INTEGER,
                             Transaction_Summ NUMERIC(12,2),
                             Transaction_DateTime TIMESTAMP WITHOUT TIME ZONE,
                             Transaction_Store_Id INTEGER,
                             CONSTRAINT fk_Transaction_Customer_Card_Id FOREIGN KEY (Customer_Card_Id)
                                           REFERENCES Cards(Customer_Card_Id)
);


CREATE TABLE IF NOT EXISTS Checks(
                             Transaction_Id Integer,
                             SKU_Id Integer,
                             SKU_Amount NUMERIC,
                             SKU_Summ NUMERIC(12,2),
                             SKU_Summ_Paid NUMERIC(12,2),
                             SKU_Discount NUMERIC(12,2),	
                             CONSTRAINT fk_Checks_Transaction_Id FOREIGN KEY (Transaction_Id)
                                           REFERENCES Transaction(Transaction_Id),
                             CONSTRAINT fk_Checks_SKU_Id FOREIGN KEY (SKU_Id)
                                           REFERENCES ProductGrid(SKU_Id)
);


CREATE TABLE IF NOT EXISTS DateOfAnalysisFormation(
                             Analysis_Formation TIMESTAMP WITHOUT TIME ZONE);



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



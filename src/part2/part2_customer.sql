DROP MATERIALIZED VIEW IF EXISTS Customer CASCADE;

DROP FUNCTION IF EXISTS fnc_CustomerCheckSegment() CASCADE;
DROP FUNCTION IF EXISTS fnc_CustomerFrequencySegment() CASCADE;
DROP FUNCTION IF EXISTS fnc_CustomerChurnSegment() CASCADE;
DROP FUNCTION IF EXISTS fnc_CustomerSegmentID() CASCADE;

DROP FUNCTION IF EXISTS fnc_GetLastStoreTriple(p_customer_id INTEGER);
DROP FUNCTION IF EXISTS fnc_GetMaxStore(p_customer_id INTEGER);
DROP FUNCTION IF EXISTS fnc_GetPrimaryStore(p_customer_id INTEGER);

CREATE OR REPLACE FUNCTION fnc_CustomerCheckSegment()
RETURNS TABLE(Customer_ID INTEGER, Customer_Average_Check NUMERIC, Customer_Average_Check_Segment VARCHAR)
AS $$

WITH average_check AS (
  SELECT customer_id, average_check,
         CUME_DIST() OVER (ORDER BY average_check) AS per_rank
  FROM (
    SELECT customer_id, AVG(transaction_summ) AS average_check
    FROM cards
    JOIN transaction tr ON tr.customer_card_id =  cards.customer_card_id
    GROUP BY customer_id
    ORDER BY average_check DESC) AS average_table)
    
  SELECT customer_id, average_check AS customer_average_check,
       CASE 
           WHEN per_rank >= 0.9 THEN 'High'
           WHEN per_rank <= 0.67 THEN 'Low'
           ELSE 'Medium'
       END AS customer_average_check_segment
  FROM average_check;

$$ LANGUAGE SQL;



CREATE OR REPLACE FUNCTION fnc_CustomerFrequencySegment()
RETURNS TABLE(Customer_ID INTEGER, Customer_Frequency NUMERIC, Customer_Frequency_Segment VARCHAR)
AS $$

WITH frequency_tmp AS (
  SELECT customer_id, delta, CUME_DIST() OVER (ORDER BY delta) AS frequency
  FROM (
    SELECT customer_id,
      (EXTRACT (EPOCH FROM (MAX(transaction_datetime)
           - MIN(transaction_datetime)))) / COUNT(transaction_id) AS delta
    FROM transaction
    JOIN Cards ON Cards.customer_card_id = transaction.customer_card_id
    GROUP BY customer_id
    ORDER BY delta))
    
  SELECT customer_id, delta / (60*60*24) AS Customer_Frequency,
         CASE WHEN frequency <= 0.1 THEN 'Often'
              WHEN frequency >= 0.67 THEN 'Rarely'
              ELSE 'Occasionally'
         END AS Customer_Frequency_Segment
  FROM frequency_tmp


$$LANGUAGE SQL;



CREATE OR REPLACE FUNCTION fnc_CustomerChurnSegment()
RETURNS TABLE(Customer_ID INTEGER, Customer_Inactive_Period NUMERIC, Customer_Churn_Rate NUMERIC, Customer_Churn_Segment VARCHAR)
AS $$

WITH last_transaction AS (
  SELECT customer_id, MAX(transaction_datetime) FROM cards
  JOIN transaction ON transaction.customer_card_id = cards.customer_card_id
  GROUP BY customer_id
),
  days_count AS(
    SELECT customer_id,
           EXTRACT (EPOCH FROM (SELECT analysis_formation 
                                FROM dateofanalysisformation 
                                ORDER BY analysis_formation
                                LIMIT 1) - MAX)/(60*60*24)  AS Customer_Inactive_Period
    FROM last_transaction),
  churn_rate AS (
    SELECT days_count.customer_id, Customer_Inactive_Period,
           Customer_Inactive_Period / Customer_Frequency AS Customer_Churn_Rate
    FROM (SELECT * FROM fnc_customerfrequencysegment()) AS fq
    JOIN days_count 
      ON days_count.customer_id = fq.customer_id)
      
SELECT Customer_ID, Customer_Inactive_Period, Customer_Churn_Rate,
       CASE 
           WHEN Customer_Churn_Rate <= 2 THEN 'Low'
           WHEN Customer_Churn_Rate <= 5 THEN 'Medium'
           WHEN Customer_Churn_Rate > 5 THEN 'High'
       END AS Customer_Shurn_Segment
FROM churn_rate

$$LANGUAGE SQL;


CREATE OR REPLACE FUNCTION fnc_CustomerSegment()
RETURNS TABLE(Customer_ID INTEGER, Customer_Average_Check NUMERIC, Customer_Average_Check_Segment VARCHAR,
              Customer_Frequency NUMERIC, Customer_Frequency_Segment VARCHAR,
              Customer_Inactive_Period NUMERIC, Customer_Churn_Rate NUMERIC, Customer_Churn_Rate_Segment VARCHAR,
              Customer_Segment INTEGER)
AS $$

WITH Base_Customer_Segment AS(
    SELECT "check".customer_id, "check".Customer_Average_Check,
           "check".Customer_Average_Check_Segment,
           fr.Customer_Frequency, fr.Customer_Frequency_Segment,
           churn.Customer_Inactive_Period, churn.Customer_Churn_Rate,
           churn.Customer_Churn_Segment

    FROM fnc_CustomerCheckSegment() AS "check"
    JOIN (SELECT * FROM fnc_CustomerFrequencySegment()) AS fr 
      ON fr.customer_id = "check".customer_id
    JOIN (SELECT * FROM fnc_CustomerChurnSegment()) AS churn 
      ON fr.customer_id = churn.customer_id)
    
SELECT *, 1 
          + 
          CASE
              WHEN Customer_Average_Check_Segment = 'Low' THEN 0
              WHEN Customer_Average_Check_Segment = 'Medium' THEN 9
              WHEN Customer_Average_Check_Segment = 'High' THEN 18
          END
          +
          CASE
              WHEN Customer_Frequency_Segment = 'Rarely' THEN 0
              WHEN Customer_Frequency_Segment = 'Occasionally' THEN 3
              WHEN Customer_Frequency_Segment = 'Often' THEN 6
          END
          +
          CASE
              WHEN Customer_Churn_Segment = 'Low' THEN 0
              WHEN Customer_Churn_Segment = 'Medium' THEN 1
              WHEN Customer_Churn_Segment = 'High' THEN 2
          END
          AS Customer_Segment
FROM Base_Customer_Segment

$$LANGUAGE SQL;


CREATE OR REPLACE FUNCTION fnc_GetLastStoreTriple(p_customer_id INTEGER)
RETURNS INTEGER AS $$

WITH tmp AS (
  SELECT cards.customer_id, transaction_datetime, transaction_store_id 
  FROM transaction
  JOIN cards ON cards.customer_card_id = transaction.customer_card_id AND cards.customer_id = p_customer_id
  ORDER BY 2 DESC
  Limit 3),

is_eq_stores AS (
  SELECT COUNT(*)
  FROM  (SELECT DISTINCT transaction_store_id
         FROM tmp)),
 
last_store AS (
  SELECT transaction_store_id FROM tmp
  ORDER BY transaction_datetime DESC
  LIMIT 1)
       
SELECT (CASE
            WHEN ((SELECT count FROM is_eq_stores) = 1) 
                THEN (SELECT * FROM last_store)
            ELSE 0
       END)

$$ LANGUAGE SQL;




CREATE OR REPLACE FUNCTION fnc_GetMaxStore(p_customer_id INTEGER)
RETURNS INTEGER AS $$

WITH common_tr_count AS (
    SELECT cards.customer_id, COUNT(*) AS Common_Transaction_Count
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id AND cards.customer_id = p_customer_id
    GROUP BY (cards.customer_id)),
store_tr_count AS (
    SELECT cards.customer_id, transaction_store_id, COUNT(*) AS Store_Transaction_Count
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id AND cards.customer_id = p_customer_id
    GROUP BY cards.customer_id, transaction_store_id
    ORDER BY 1,2),
tr_part AS (
    SELECT store_tr_count.customer_id, transaction_store_id, 
    Store_Transaction_Count::NUMERIC/Common_Transaction_Count AS tr_part
    FROM store_tr_count
    JOIN common_tr_count ON common_tr_count.customer_id = store_tr_count.customer_id
    ORDER BY tr_part),
max_tr_part AS (
    SELECT transaction_store_id, tr_part
    FROM tr_part
    WHERE tr_part = (SELECT tr_part FROM tr_part ORDER BY tr_part DESC LIMIT 1)),
max_date_tr AS (
    SELECT MAX(transaction_datetime), transaction_store_id 
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id 
               AND cards.customer_id = p_customer_id
    GROUP BY transaction_store_id
) 
   
SELECT (CASE
         WHEN ((SELECT COUNT(*) FROM max_tr_part) = 1)
             THEN (SELECT transaction_store_id FROM max_tr_part)
             ELSE (SELECT max_tr_part.transaction_store_id from max_tr_part 
                   JOIN max_date_tr 
                   ON max_tr_part.transaction_store_id = max_date_tr.transaction_store_id
                   ORDER BY max DESC
                   LIMIT 1)
         END)

$$ LANGUAGE SQL;




CREATE OR REPLACE FUNCTION fnc_GetPrimaryStore(p_customer_id INTEGER)
RETURNS INTEGER AS $$

DECLARE store_triple INTEGER := fnc_GetLastStoreTriple(p_customer_id);

BEGIN
  IF (store_triple = 0)
    THEN store_triple = fnc_GetMaxStore(p_customer_id);
  END IF;
  RETURN store_triple;
END;

$$ LANGUAGE plpgsql;




CREATE MATERIALIZED VIEW IF NOT EXISTS Customer AS(
SELECT customer_id AS "Customer_ID",
       customer_average_check AS "Customer_Average_Check",
       customer_average_check_segment AS "Customer_Average_Check_Segment",
       customer_frequency AS "Customer_Frequency",
       customer_frequency_segment AS "Customer_Frequency_Segment",
       customer_inactive_period AS "Customer_Inactive_Period",
       customer_churn_rate AS "Customer_Churn_Rate",
       customer_churn_rate_segment AS "Customer_Churn_Rate_Segment",
       customer_segment AS "Customer_Segment",
       fnc_GetPrimaryStore(customer_id) AS "Customer_Primary_Store"
FROM fnc_CustomerSegment())

DROP MATERIALIZED VIEW IF EXISTS Customer CASCADE;

DROP FUNCTION IF EXISTS fnc_CustomerCheckSegment() CASCADE;
DROP FUNCTION IF EXISTS fnc_CustomerFrequencySegment() CASCADE;
DROP FUNCTION IF EXISTS fnc_CustomerChurnSegment() CASCADE;

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
           WHEN per_rank <= 0.35 THEN 'Low'
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
              WHEN frequency >= 0.65 THEN 'Rarely'
              ELSE 'Occasionally'
         END AS Customer_Frequency_Segment
  FROM frequency_tmp


$$LANGUAGE SQL;



CREATE OR REPLACE FUNCTION fnc_CustomerCheckSegment()
RETURNS TABLE(Customer_ID INTEGER, Customer_Average_Check NUMERIC, Customer_Average_Check_Segment VARCHAR)
AS $$

WITH last_transaction AS (
  SELECT customer_id, MAX(transaction_datetime) FROM cards
  JOIN transaction ON transaction.customer_card_id = cards.customer_card_id
  GROUP BY customer_id
),
  days_count AS(
    SELECT customer_id,
           EXTRACT ("day" FROM (SELECT analysis_formation 
                                FROM dateofanalysisformation 
                                ORDER BY analysis_formation
                                LIMIT 1) - MAX)  AS Customer_Inactive_Period
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

CREATE MATERIALIZED VIEW IF NOT EXISTS Customer AS(

WITH average_tmp AS (
  SELECT customer_id, average_check,
         CUME_DIST() OVER (ORDER BY average_check) AS per_rank
  FROM (
    SELECT customer_id, AVG(transaction_summ) AS average_check
    FROM cards
    JOIN transaction tr ON tr.customer_card_id =  cards.customer_card_id
    GROUP BY customer_id
    ORDER BY average_check DESC) AS average_table),

average_segmentation AS(--2,3,4
  SELECT customer_id, average_check AS customer_average_check, per_rank,
         CASE 
             WHEN per_rank >= 0.9 THEN 'High'
             WHEN per_rank <= 0.35 THEN 'Low'
             ELSE 'Medium'
         END AS customer_average_check_segment
  FROM average_tmp),

frequency_tmp AS (
  SELECT customer_id, delta, CUME_DIST() OVER (ORDER BY delta) AS frequency
  FROM (
    SELECT customer_id,
      (EXTRACT (EPOCH FROM (MAX(transaction_datetime)
           - MIN(transaction_datetime)))) / COUNT(transaction_id) AS delta
    FROM transaction
    JOIN Cards ON Cards.customer_card_id = transaction.customer_card_id
    GROUP BY customer_id
    ORDER BY delta)),

customer_frequency AS ( --5,6,7
  SELECT customer_id, delta / (60*60*24) AS Customer_Frequency,
         CASE WHEN frequency <= 0.1 THEN 'Often'
              WHEN frequency >= 0.65 THEN 'Rarely'
              ELSE 'Occasionally'
         END AS Customer_Frequency_Segment
  FROM frequency_tmp)




)

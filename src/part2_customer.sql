DROP MATERIALIZED VIEW IF EXISTS Customer CASCADE;

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

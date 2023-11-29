DROP MATERIALIZED VIEW IF EXISTS Periods CASCADE;

DROP FUNCTION IF EXISTS fnc_GetMinDiscount(p_customer_id INTEGER, p_group_id INTEGER);



CREATE OR REPLACE FUNCTION fnc_GetMinDiscount(p_customer_id INTEGER, p_group_id INTEGER)
RETURNS NUMERIC AS $$

WITH base_discount_cte AS (
    SELECT customer_id AS Customer_ID,
           group_id AS Group_ID,
           checks.sku_discount / checks.sku_summ AS Discount
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id AND cards.customer_id = p_customer_id
    JOIN checks ON checks.transaction_id = transaction.transaction_id
    JOIN productgrid ON productgrid.sku_id = checks.sku_id AND group_id = p_group_id),
    
min_discount AS (
    SELECT MIN(discount)
    FROM (SELECT * FROM base_discount_cte
          WHERE NOT discount = 0))
     
SELECT CASE
         WHEN ((SELECT * FROM min_discount) IS NULL)
           THEN 0
         ELSE (SELECT min FROM min_discount)
       END;

$$ LANGUAGE SQL;



CREATE MATERIALIZED VIEW IF NOT EXISTS Periods AS (

WITH date_range AS (
    SELECT customer_id AS Customer_ID,
           group_id AS Group_ID,
           MIN(transaction_datetime) AS First_Group_Purchase_Date,
           MAX(transaction_datetime) AS Last_Group_Purchase_Date
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id
    JOIN checks ON checks.transaction_id = transaction.transaction_id
    JOIN productgrid ON productgrid.sku_id = checks.sku_id
    GROUP BY customer_id, group_id),

tr_count AS (
    SELECT customer_id AS Customer_ID,
           group_id AS Group_ID,
           COUNT(*) AS Group_Purchase
    FROM transaction
    JOIN cards ON cards.customer_card_id = transaction.customer_card_id
    JOIN checks ON checks.transaction_id = transaction.transaction_id
    JOIN productgrid ON productgrid.sku_id = checks.sku_id
    GROUP BY customer_id, group_id),

group_freq AS (
    SELECT date_range.customer_id AS Customer_ID,
           date_range.group_id AS Group_ID,
           date_range.first_group_purchase_date AS First_Group_Purchase_Date,
           date_range.last_group_purchase_date AS Last_Group_Purchase_Date,
           tr_count.group_purchase AS Group_Purchase,
           CASE
               WHEN (tr_count.group_purchase = 1)
               THEN 1.0
               ELSE
                   (EXTRACT(EPOCH FROM(last_group_purchase_date - 
                                       first_group_purchase_date)) + 1)/(24*60*60*Group_Purchase)
               END AS Group_Frequency
    FROM date_range
    JOIN tr_count ON tr_count.customer_id = date_range.customer_id
                  AND tr_count.group_id = date_range.group_id)
                  

SELECT customer_id AS "Customer_ID",
       group_id AS "Group_ID",
       first_group_purchase_date AS "First_Group_Purchase_Date",
       last_group_purchase_date AS "Last_Group_Purchase_Date",
       group_purchase AS "Group_Purchase",
       group_frequency AS "Group_Frequency",
       fnc_GetMinDiscount(customer_id, group_id) AS "Group_Min_Discount"
FROM group_freq
)

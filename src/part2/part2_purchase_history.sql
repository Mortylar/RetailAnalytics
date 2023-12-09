DROP MATERIALIZED VIEW IF EXISTS PurchaseHistory CASCADE;



CREATE MATERIALIZED VIEW IF NOT EXISTS PurchaseHistory AS (

SELECT cards.customer_id AS "Customer_ID", 
       transaction.transaction_id AS "Transaction_ID", 
       transaction_datetime AS "Transaction_DateTime",
       productgrid.group_id AS "Group_ID",
       SUM(sku_purchase_price * sku_amount) AS "Group_Cost",
       SUM(sku_summ) AS "Group_Summ",
       SUM(SKU_Summ_Paid) AS "Group_Summ_Paid"
FROM transaction
JOIN cards ON cards.customer_card_id = transaction.customer_card_id
JOIN checks ON checks.transaction_id = transaction.transaction_id
JOIN productgrid ON productgrid.sku_id = checks.sku_id
JOIN stores ON stores.sku_id = checks.sku_id
            AND transaction.transaction_store_id = stores.transaction_store_id
GROUP BY cards.Customer_ID, transaction.Transaction_ID, Transaction_DateTime, Group_ID)

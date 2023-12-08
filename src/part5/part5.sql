DROP FUNCTION IF EXISTS fnc_Part5_1(p_first_date TIMESTAMP, p_last_date TIMESTAMP, p_transactions_add INTEGER);
DROP FUNCTION IF EXISTS fnc_Part5(p_first_date TIMESTAMP, p_last_date TIMESTAMP, p_transactions_add INTEGER,
                                  p_max_churn_ind NUMERIC, p_max_transaction_share NUMERIC, p_margin_share NUMERIC);





CREATE OR REPLACE FUNCTION fnc_Part5_1(p_first_date TIMESTAMP, p_last_date TIMESTAMP, p_transaction_add INTEGER)
RETURNS TABLE(customer_id INTEGER, start_date TIMESTAMP, end_date TIMESTAMP, required_transactions_count NUMERIC)
AS $$

WITH base_cte AS (SELECT "Customer_ID",
                          (SELECT(EXTRACT(EPOCH FROM(p_last_date::TIMESTAMP - p_first_date::TIMESTAMP))) / "Customer_Frequency")
                            AS base_intensity
                  FROM Customer)

SELECT "Customer_ID", p_first_date, p_last_date,
       ROUND(base_intensity) + p_transaction_add AS Required_Transaction_Count
FROM base_cte
$$ LANGUAGE SQL;





CREATE OR REPLACE FUNCTION fnc_Part5(p_first_date TIMESTAMP, p_last_date TIMESTAMP, p_transaction_add INTEGER,
                                     p_max_churn_ind NUMERIC, p_max_transaction_share NUMERIC, p_margin_share NUMERIC)
RETURNS TABLE("Customer_ID" INTEGER, "Start_Date" TIMESTAMP, "End_Date" TIMESTAMP, "Required_Transaction_Count" NUMERIC,
              "Group_Name" VARCHAR, "Offer_Discount_Depth" NUMERIC)
AS $$

SELECT terms_of_offer.Customer_ID, Start_Date, End_Date, Required_Transaction_Count,
       Group_Name, Offer_Discount_Depth
FROM fnc_Part5_1(p_last_date, p_first_date, p_transaction_add) AS terms_of_offer
JOIN fnc_Part4GetDiscount(customer_id, p_max_churn_ind, p_max_transaction_share, p_margin_share) AS discount
   ON discount.Customer_ID = terms_of_offer.Customer_ID
JOIN SKUGroup ON SKUGroup.group_id = discount.group_id

$$ LANGUAGE SQL;



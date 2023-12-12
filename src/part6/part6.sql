DROP FUNCTION IF EXISTS fnc_Part6(p_groups_count INTEGER, p_max_churn_rate NUMERIC, p_max_stability_ind NUMERIC,
                                  p_max_sku_share NUMERIC, p_margin_share NUMERIC);
DROP FUNCTION IF EXISTS fnc_Part6GetTransactionShare(p_customer_id INTEGER, p_group_id INTEGER, p_sku_id INTEGER);
DROP FUNCTION IF EXISTS fnc_Part6GetSKU(p_customer_id INTEGER, p_groups_count INTEGER, p_max_churn_rate NUMERIC,
                                        p_max_stability_ind NUMERIC, p_max_sku_share NUMERIC);


CREATE OR REPLACE FUNCTION fnc_Part6GetTransactionShare(p_customer_id INTEGER, p_group_id INTEGER, p_sku_id INTEGER)
RETURNS NUMERIC
AS $$

WITH sku_in_group AS (SELECT "Customer_ID", "Transaction_ID", "Group_ID", sku_id
                      FROM PurchaseHistory
                      JOIN ProductGrid ON "Group_ID" = ProductGrid.Group_ID
                      AND "Customer_ID" = p_customer_id
                      AND "Group_ID" = p_group_id)

SELECT ((SELECT COUNT(*) FROM sku_in_group WHERE sku_id = p_sku_id)::NUMERIC/
        (SELECT COUNT(*) FROM sku_in_group)) AS "Transaction_Share";

$$ LANGUAGE SQL;



CREATE OR REPLACE FUNCTION fnc_Part6GetSKU(p_customer_id INTEGER, p_groups_count INTEGER, p_max_churn_rate NUMERIC,
                                           p_max_stability_ind NUMERIC, p_max_sku_share NUMERIC)
RETURNS NUMERIC
AS $$

WITH groups_cte AS (SELECT "Customer_ID", "Group_ID"
                    FROM Groups
                    WHERE "Customer_ID" = p_customer_id
                    AND "Group_Churn_Rate" <= p_max_churn_rate
                    AND "Group_Stability_Index" < p_max_stability_ind
                    ORDER BY "Group_Affinity_Index" DESC
                    LIMIT p_groups_count),

base_sku AS (SELECT "Customer_ID", "Customer_Primary_Store",
                    Stores.sku_id AS "SKU_ID", group_id AS "Group_ID",
                    (SKU_Retail_Price - SKU_Purchase_Price) AS "SKU_Coeff" 
             FROM Customer 
             JOIN Stores ON Stores.Transaction_store_id = "Customer_Primary_Store"
             JOIN ProductGrid ON Stores.sku_id = ProductGrid.sku_id 
                              AND "Customer_ID" = p_customer_id
                              AND group_id IN (SELECT "Group_ID" FROM groups_cte))
                                   
SELECT "SKU_ID" FROM (SELECT *, 
                             100 * fnc_Part6GetTransactionShare("Customer_ID", "Group_ID", "SKU_ID")
                             AS "Transaction_Share" 
                      FROM base_sku)
WHERE "Transaction_Share" <= p_max_sku_share
ORDER BY "SKU_Coeff" DESC
LIMIT 1;
$$ LANGUAGE SQL;






CREATE OR REPLACE FUNCTION fnc_Part6(p_groups_count INTEGER, p_max_churn_rate NUMERIC, p_max_stability_ind NUMERIC,
                                     p_max_sku_share NUMERIC, p_margin_share NUMERIC)
RETURNS TABLE("Customer_ID" INTEGER, "SKU_Name" VARCHAR, "Offer_Discount_Depth" NUMERIC)
AS $$

WITH base_cte AS (SELECT "Customer_ID", sku_id,
                         p_margin_share * (SKU_Retail_Price - SKU_Purchase_Price)/SKU_Retail_Price AS Discount
                  FROM Customer
                  JOIN Stores ON "Customer_Primary_Store" = Transaction_Store_ID
                              AND SKU_ID = fnc_Part6GetSku("Customer_ID", p_groups_count, p_max_churn_rate, p_max_stability_ind, p_max_sku_share)),

discount_cte AS (SELECT base_cte."Customer_ID", base_cte.SKU_ID, Discount,
                        FLOOR (100 * "Group_Minimum_Discount" / 0.05) * 0.05 AS Min_Discount
                 FROM base_cte
                 JOIN Groups ON Groups."Customer_ID" = base_cte."Customer_ID"
                             AND Groups."Group_ID" = (SELECT Group_ID FROM ProductGrid 
                                                      WHERE base_cte.sku_id = ProductGrid.sku_id))
SELECT "Customer_ID", sku_name AS "SKU_Name", min_discount AS "Offer_Discount_Depth" 
FROM discount_cte
JOIN ProductGrid ON discount_cte.sku_id = ProductGrid.sku_id
                 AND Discount >= Min_Discount
$$ LANGUAGE SQL;

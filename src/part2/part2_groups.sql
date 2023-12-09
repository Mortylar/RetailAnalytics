DROP MATERIALIZED VIEW IF EXISTS Groups CASCADE;

DROP FUNCTION IF EXISTS fnc_GetTransactionsCount(p_customer_id INTEGER, p_group_id INTEGER);
DROP FUNCTION IF EXISTS fnc_GetGroupChurnRate(p_customer_id INTEGER, p_group_id INTEGER);
DROP FUNCTION IF EXISTS fnc_GetStabilityIndex(p_customer_id INTEGER, p_group_id INTEGER);
DROP FUNCTION IF EXISTS fnc_CommonGroupMargin();
DROP FUNCTION IF EXISTS fnc_PeriodGroupMargin(p_days_count INTEGER);
DROP FUNCTION IF EXISTS fnc_TransactionCountGroupMargin(p_customer_id INTEGER, p_group_id INTEGER, p_transaction_count INTEGER);
DROP FUNCTION IF EXISTS fnc_GroupDiscount();

CREATE OR REPLACE FUNCTION fnc_GetTransactionsCount(p_customer_id INTEGER, p_group_id INTEGER)
RETURNS INTEGER AS $$

DECLARE first_date TIMESTAMP := (SELECT "First_Group_Purchase_Date" FROM Periods
                                 WHERE "Customer_ID" = p_customer_id 
                                 AND "Group_ID" = p_group_id);

DECLARE last_date TIMESTAMP := (SELECT "Last_Group_Purchase_Date" FROM Periods
                                WHERE "Customer_ID" = p_customer_id 
                                AND "Group_ID" = p_group_id);

BEGIN

RETURN (SELECT COUNT(*) FROM (
            SELECT * FROM PurchaseHistory
                WHERE "Transaction_DateTime" >= first_date
                AND "Transaction_DateTime" <= last_date
                AND "Customer_ID" = p_customer_id)); 
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fnc_GetGroupChurnRate(p_customer_id INTEGER, p_group_id INTEGER)
RETURNS NUMERIC AS $$

DECLARE last_date TIMESTAMP := (SELECT MAX("Transaction_DateTime") 
                                FROM PurchaseHistory
                                WHERE "Customer_ID" = p_customer_id 
                                AND "Group_ID" = p_group_id);

DECLARE days_count NUMERIC := (SELECT (EXTRACT (EPOCH FROM (SELECT analysis_formation 
                                                FROM DateOfAnalysisFormation) - last_date)/(24*60*60)));
BEGIN

RETURN (SELECT days_count / "Group_Frequency"::NUMERIC
        FROM Periods
        WHERE "Customer_ID" = p_customer_id
        AND "Group_ID" = p_group_id);
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fnc_GetStabilityIndex(p_customer_id INTEGER, p_group_id INTEGER)
RETURNS NUMERIC
AS $$

WITH date_shift_cte AS (SELECT "Customer_ID", "Group_ID", "Transaction_ID", "Transaction_DateTime",
                                LAG("Transaction_DateTime") OVER (ORDER BY "Customer_ID","Transaction_DateTime") AS "Last_Date"
                        FROM PurchaseHistory
                        WHERE "Customer_ID" = p_customer_id AND "Group_ID" = p_group_id
                        ORDER BY "Customer_ID", "Transaction_DateTime"),

interval_cte AS (SELECT "Customer_ID", "Group_ID", "Transaction_ID", 
                        (EXTRACT(EPOCH FROM ("Transaction_DateTime" - "Last_Date")))/(24*60*60) AS "Interval"
                FROM date_shift_cte),

pre_index AS (SELECT interval_cte."Customer_ID", interval_cte."Group_ID",
                     ABS(("Interval" / "Group_Frequency") - 1.0) AS pre_index
             FROM interval_cte
             JOIN Periods ON interval_cte."Customer_ID" = Periods."Customer_ID" 
                          AND interval_cte."Group_ID" = Periods."Group_ID")

SELECT
      CASE 
        WHEN (AVG(pre_index) IS NULL) THEN 1
        ELSE AVG(pre_index)
      END  AS "Group_Stability_Index"
FROM pre_index
GROUP BY "Customer_ID", "Group_ID";

$$ LANGUAGE SQL;



CREATE OR REPLACE FUNCTION fnc_CommonGroupMargin()
RETURNS TABLE(Customer_ID INTEGER, Group_ID INTEGER, Group_Margin NUMERIC)
AS $$

SELECT "Customer_ID", "Group_ID", SUM("Group_Summ_Paid" - "Group_Cost") AS Group_Margin
FROM PurchaseHistory
GROUP BY "Customer_ID", "Group_ID";

$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION fnc_PeriodGroupMargin(p_days_count INTEGER)
RETURNS TABLE(Customer_ID INTEGER, Group_ID INTEGER, Group_Margin NUMERIC)
AS $$

DECLARE start_date DATE := (SELECT ((SELECT Analysis_Formation 
                                     FROM DateOfAnalysisFormation)::DATE - p_days_count));

BEGIN
  RETURN QUERY (SELECT "Customer_ID", "Group_ID",
                  SUM("Group_Summ_Paid" - "Group_Cost") AS Group_Margin
          FROM PurchaseHistory
          WHERE "Transaction_DateTime" >= start_date
          GROUP BY "Customer_ID", "Group_ID");
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION  fnc_TransactionCountGroupMargin(p_customer_id INTEGER, p_group_id INTEGER, p_transaction_count INTEGER)
RETURNS TABLE(Customer_ID INTEGER, Group_ID INTEGER, Group_Margin NUMERIC)
AS $$

WITH part_ph_cte AS (SELECT * FROM PurchaseHistory
                     WHERE "Customer_ID" = p_customer_id
                       AND "Group_ID" = p_group_id
                     ORDER BY "Transaction_DateTime" DESC
                     LIMIT p_transaction_count)

SELECT "Customer_ID", "Group_ID", 
       SUM("Group_Summ_Paid" - "Group_Cost") AS Group_Margin
FROM part_ph_cte
GROUP BY "Customer_ID", "Group_ID";

$$ LANGUAGE SQL;



CREATE OR REPLACE FUNCTION  fnc_GroupDiscount()
RETURNS TABLE(Customer_ID INTEGER, Group_ID INTEGER, Group_Discount_Share NUMERIC, Group_Minimum_Discount NUMERIC, Group_Average_Discount NUMERIC)
AS $$

WITH discount_count AS (SELECT customer_id, group_id, COUNT(*) as discount_count
                        FROM checks
                        JOIN transaction ON transaction.transaction_id = checks.transaction_id
                        JOIN cards ON cards.customer_card_id = transaction.customer_card_id
                        JOIN productgrid ON productgrid.sku_id = checks.sku_id
                        WHERE sku_discount > 0
                        GROUP BY customer_id, group_id),
                        
full_discount_count AS (SELECT "Customer_ID" AS Customer_ID,
                               "Group_ID" AS Group_ID,
                               CASE WHEN (discount_count IS NULL) THEN 0
                                    ELSE discount_count
                               END AS discount_count
                       FROM (SELECT * FROM Periods
                             LEFT JOIN discount_count ON "Customer_ID" = customer_id
                                                      AND "Group_ID" = Group_ID)),
                        
discount_share AS (SELECT Customer_ID, Group_ID,
                          discount_count::NUMERIC/"Group_Purchase" AS Group_Discount_Share
                   FROM Periods
                   JOIN full_discount_count ON "Customer_ID" = customer_id
                                            AND "Group_ID" = Group_ID),
                                            
min_discount AS (SELECT "Customer_ID" AS Customer_ID, "Group_ID" AS Group_ID, 
                        CASE 
                            WHEN ("Group_Min_Discount" = 0) THEN NULL
                            ELSE "Group_Min_Discount"
                        END AS Group_Minimum_Discount           
                 FROM Periods),
                 
average_discount AS (SELECT "Customer_ID" AS customer_id, "Group_ID" AS Group_ID,
                            SUM("Group_Summ_Paid")/SUM("Group_Summ") AS Group_Average_Discount
                     FROM PurchaseHistory
                     GROUP BY "Customer_ID", "Group_ID")
                     
                     
SELECT ds.Customer_ID, ds.Group_ID, ds.Group_Discount_Share,
       md.Group_Minimum_Discount, ad.Group_Average_Discount
FROM discount_share AS ds
JOIN min_discount AS md ON md.Customer_ID = ds.Customer_ID 
                        AND md.Group_ID = ds.Group_ID
JOIN average_discount AS ad ON ad.Customer_ID = ds.Customer_ID
                            AND ad.Group_ID = ds.Group_ID;

$$ LANGUAGE SQL;









CREATE MATERIALIZED VIEW IF NOT EXISTS Groups AS (
 
WITH aff_ind_cte AS (SELECT "Customer_ID", "Group_ID", 
                       "Group_Purchase"::NUMERIC / fnc_GetTransactionsCount("Customer_ID", "Group_ID") AS "Group_Affinity_Index"
                     FROM Periods) 
  
SELECT "Customer_ID" AS "Customer_ID", 
       "Group_ID" AS "Group_ID",
       "Group_Affinity_Index" AS "Group_Affinity_Index",
       fnc_GetGroupChurnRate("Customer_ID", "Group_ID") AS "Group_Churn_Rate",
       fnc_GetStabilityIndex("Customer_ID", "Group_ID") AS "Group_Stability_Index",
       Group_Margin AS "Group_Margin", --TODO can change ->
       Group_Discount_Share AS "Group_Discount_Share",
       Group_Minimum_Discount AS "Group_Minimum_Discount",
       Group_Average_Discount AS "Group_Average_Discount"
FROM aff_ind_cte
JOIN fnc_CommonGroupMargin() AS margin
  ON margin.Customer_ID = "Customer_ID" AND margin.Group_ID = "Group_ID" --TODO change place
JOIN fnc_GroupDiscount() AS dis 
  ON dis.Customer_ID = "Customer_ID" AND dis.Group_ID = "Group_ID")

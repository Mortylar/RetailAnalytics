DROP FUNCTION IF EXISTS fnc_Part4(p_method INTEGER, p_first_date DATE, p_last_date DATE,
                                  p_transaction_count INTEGER, p_k_average_inc NUMERIC,
                                  p_max_churn_ind NUMERIC, p_max_dis_share NUMERIC,
                                  p_margin_share NUMERIC);

DROP FUNCTION IF EXISTS fnc_Part4GetDiscount(p_customer_id INTEGER, p_max_churn_ind NUMERIC,
                                             p_max_dis_share NUMERIC, p_margin_share NUMERIC);

DROP FUNCTION IF EXISTS fnc_Part4GetAverageCheck(p_method INTEGER, p_first_date DATE, p_last_date DATE
                                                 p_transaction_count INTEGER, p_k_average_inc NUMERIC);

DROP FUNCTION IF EXISTS fnc_Part4PeriodMethod(p_first_date DATE, p_last_date DATE, p_k_average_inc NUMERIC);
DROP FUNCTION IF EXISTS fnc_Part4CountMethod(p_customer_id INTEGER, p_transaction_count INTEGER, p_k_average_inc NUMERIC);



CREATE OR REPLACE FUNCTION fnc_Part4PeriodMethod(p_first_date DATE, p_last_date DATE, p_k_average_inc NUMERIC)
RETURNS TABLE(customer_id INTEGER, required_check_measure NUMERIC)
AS $$

DECLARE first_date DATE := (SELECT Transaction_DateTime FROM Transaction
                            ORDER BY Transaction_DateTime
                            LIMIT 1);
DECLARE last_date DATE := (SELECT Transaction_DateTime FROM Transaction
                           ORDER BY Transaction_DateTime DESC
                           LIMIT 1);
BEGIN
  IF ((p_first_date > p_last_date) OR (p_last_date < first_date) OR (p_first_date > last_date))
    THEN RAISE EXCEPTION 'Incorrect date interval';
  END IF;

RETURN QUERY (SELECT cards.customer_id, p_k_average_inc * AVG(transaction_summ) 
              FROM transaction
              JOIN cards ON Cards.customer_card_id = Transaction.customer_card_id
                         AND transaction_datetime >= p_first_date
                         AND transaction_datetime <= p_last_date
              GROUP BY cards.customer_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fnc_Part4CountMethod(p_customer_id INTEGER, p_transaction_count INTEGER, p_k_average_inc NUMERIC)
RETURNS NUMERIC)
AS $$

BEGIN
  IF (p_transaction_count <= 0)
    THEN RAISE EXCEPTION 'Incorrect transaction count';
  END IF;

RETURN (
  WITH part_1 AS (SELECT cards.customer_id,transaction_datetime, transaction_summ 
                  FROM transaction
                  JOIN cards ON cards.customer_card_id = transaction.customer_card_id
                             AND cards.customer_id = p_customer_id
                  ORDER BY 1, 2 DESC
                  LIMIT p_transaction_count)
  SELECT p_k_average_inc * AVG(transaction_summ)
  FROM part_1
  GROUP BY part_1.customer_id);
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION fnc_Part4GetAverageCheck(p_method INTEGER, p_first_date DATE, p_last_date DATE,
                                                    p_transaction_count INTEGER, p_k_average_inc NUMERIC)
RETURNS TABLE(customer_id INTEGER, required_check_measure NUMERIC)
AS $$
BEGIN
  IF (p_method = 1)
    THEN RETURN QUERY (SELECT * 
                       FROM fnc_Part4PeriodMethod(p_first_date, p_last_date, p_k_average_inc));

  ELSEIF (p_method = 2)
    THEN RETURN QUERY (SELECT DISTINCT cards.customer_id AS customer_id,
                              fnc_Part4CountMethod(cards.customer_id, p_transaction_count, p_k_average_inc) AS required_check_measure
                       FROM cards);

  ELSE RAISE EXCEPTION 'Incorrect method';
  END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fnc_Part4GetDiscount(p_customer_id INTEGER, p_max_churn_ind NUMERIC,
                                                p_max_dis_share NUMERIC, p_margin_share NUMERIC)
RETURNS TABLE(customer_id INTEGER, group_id INTEGER, offer_discount_depth NUMERIC)
AS $$

WITH max_discount AS (SELECT "Customer_ID" AS Customer_ID, "Group_ID" AS Group_ID,
                             "Group_Affinity_Index" AS Group_Affinity_Index,
                             "Group_Minimum_Discount" AS Group_Minimum_Discount,
                             p_margin_share*"Group_Margin" AS Max_Discount
                      FROM Groups
                      WHERE "Customer_ID" = p_customer_id
                            AND "Group_Churn_Rate" <= p_max_churn_ind
                            AND "Group_Discount_Share" <= p_max_dis_share),

offer_dis AS (SELECT Customer_ID, Group_ID, Group_Affinity_Index,
                     CASE
                         WHEN ((FLOOR(Group_Minimum_Discount / 0.05)::NUMERIC* 0.05) <= Max_Discount)
                             THEN Group_Minimum_Discount
                     ELSE 0
                     END AS Offer_Discount_Depth
              FROM max_discount)

SELECT Customer_ID, Group_ID, Offer_Discount_Depth
FROM offer_dis
WHERE Offer_Discount_Depth > 0
ORDER BY Group_Affinity_Index DESC
LIMIT 1;

$$ LANGUAGE SQL;

				
CREATE OR REPLACE FUNCTION fnc_Part4(p_method INTEGER, p_first_date DATE, p_last_date DATE,
                                     p_transaction_count INTEGER, p_k_average_inc NUMERIC,
                                     p_max_churn_ind NUMERIC, p_max_dis_share NUMERIC,
                                     p_margin_share NUMERIC)
RETURNS TABLE("Customer_ID" INTEGER, "Required_Check_Measure" NUMERIC, "Group_Name" VARCHAR, "Offer_Discount_Depth" NUMERIC)
AS $$

WITH discount_cte AS (SELECT "Customer_ID", Group_ID, Offer_Discount_Depth 
                      FROM Customer
                      JOIN fnc_Part4GetDiscount("Customer_ID", p_max_churn_ind, p_max_dis_share, p_margin_share)
                        ON "Customer_ID" = customer_id)

SELECT "Customer_ID", Required_Check_Measure, Group_Name, Offer_Discount_Depth
FROM discount_cte
JOIN SKUGroup ON SKUGroup.Group_ID = discount_cte.Group_ID
JOIN fnc_Part4GetAverageCheck(p_method, p_first_date, p_last_date, p_transaction_count, p_k_average_inc)
  ON Customer_ID = "Customer_ID"
$$ LANGUAGE SQL;

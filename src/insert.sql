
-------------------------PersonalInformation-------------------------

INSERT INTO PersonalInformation(Customer_Name, Customer_Surname,
	           Customer_Primary_Email, Customer_Primary_Phone)
VALUES('Иван', 'Иванов', 'nagibatel228@mail.ru', '+78005553535');

INSERT INTO PersonalInformation(Customer_Name, Customer_Surname,
	           Customer_Primary_Email, Customer_Primary_Phone)
VALUES('Ащьф', 'Лштшфум', 'foma-kinaev@gmail.com', '+789141204657');

INSERT INTO PersonalInformation(Customer_Name, Customer_Surname,
	           Customer_Primary_Email, Customer_Primary_Phone)
VALUES('Александр', 'Шуриков', 'shlasasha@mail.ru', '+789934855924');

INSERT INTO PersonalInformation(Customer_Name, Customer_Surname,
	           Customer_Primary_Email, Customer_Primary_Phone)
VALUES('Абрам', 'Абрамов', 'israel@tora.com', '+78005553535');

INSERT INTO PersonalInformation(Customer_Name, Customer_Surname,
	           Customer_Primary_Email, Customer_Primary_Phone)
VALUES('Владимир', 'Владимиров', 'imperror@kreml.ru', '+78005553535');

-------------------------SKUGroup-------------------------

INSERT INTO SKUGroup(Group_Name) VALUES('Горячее оружие');
INSERT INTO SKUGroup(Group_Name) VALUES('Медленная еда');
INSERT INTO SKUGroup(Group_Name) VALUES('Лекарственные препараты');
INSERT INTO SKUGroup(Group_Name) VALUES('Литература для розжига');
INSERT INTO SKUGroup(Group_Name) VALUES('Безмолочные продукты');


-------------------------Cards-------------------------

INSERT INTO Cards(Customer_Id) SELECT Customer_Id FROM PersonalInformation;


-------------------------ProductGrid-------------------------

INSERT INTO ProductGrid(SKU_Name, Group_Id) 
       VALUES('Творожок с салом ''abibas''', 5);

INSERT INTO ProductGrid(SKU_Name, Group_Id) 
       VALUES('Настойка ''Боярышник'' 4 звёзды', 3);

INSERT INTO ProductGrid(SKU_Name, Group_Id) 
       VALUES('Разбитая бутылка из под портвейна 777', 1);

INSERT INTO ProductGrid(SKU_Name, Group_Id) 
       VALUES('Лист подорожника ''Zajivai-ka''', 3);

INSERT INTO ProductGrid(SKU_Name, Group_Id) 
       VALUES('Сборник макулатуры Дарьи Донцовой с автографом Филиппа Киркорова', 4);

-------------------------Stores-------------------------
--1 - аптека = 2\4
--2 - алкашка = 1\2\3\5
--3 - продуктовый = 1\2


INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(1, 2, 20.00, 120.00);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(1, 4, 20.00, 121.00);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(2, 1, 90.00, 93.00);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(2, 2, 21.00, 21.20);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(2, 3, 77.00, 77.70);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(2, 5, 5.00, 1239.99);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(3, 1, 90.00, 146.00);

INSERT INTO Stores(Transaction_Store_Id, SKU_Id, SKU_Purchase_Price, SKU_Retail_Price)
       VALUES(3, 2, 20.00, 36.00);

-------------------------Transaction-------------------------

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(1, 21.20, '2023.01.08 14:22', 2);

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(1, 21.20, '2023.01.08 16:14', 2);

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(1, 77.70, '2023.01.08 17:11', 2);

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(1, 121.00, '2023.01.08 17:44', 1);

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(3, 146.00, '2023.03.01 11:22', 3);

INSERT INTO Transaction(Customer_Card_Id, Transaction_Summ, 
                        Transaction_DateTime, Transaction_Store_Id)
       VALUES(3, 146.00, '2023.03.02 11:31', 3);

-------------------------Checks-------------------------

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(1, 2, 21.20, 1, 21.20, 0.0);

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(2, 2, 21.20, 1, 21.20, 0.0);

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(3, 3, 77.70, 1, 77.70, 0.0);

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(4, 4, 121.00, 1, 121.00, 0.0);

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(5, 1, 146.00, 1, 146.00, 0.0);

INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
       VALUES(6, 1, 146.00, 1, 146.00, 0.0);

-------------------------DateOfAnalysisFormation-------------------------

INSERT INTO DateOfAnalysisFormation(Analysis_Formation) (SELECT CURRENT_TIMESTAMP);

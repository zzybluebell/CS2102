-- Question 1
CREATE OR REPLACE VIEW v1 (pizza) AS
SELECT S.pizza FROM Restaurants AS R INNER JOIN Sells AS S
ON R.rname = S.rname
INNER JOIN Customers AS C
ON R.area = C.area
WHERE C.cname = 'Bob';

-- Question 2
CREATE OR REPLACE VIEW v2 (cname) AS
SELECT DISTINCT L1.cname FROM Likes AS L1 INNER JOIN Likes AS L2
ON L1.cname = L2.cname
WHERE L1.pizza <> L2.pizza;

-- Question 3
CREATE OR REPLACE VIEW v3 (rname1, rname2) AS
SELECT S1.rname, S2.rname FROM Sells AS S1 INNER JOIN Sells AS S2
ON S1.pizza = S2.pizza
WHERE S1.rname <> S2.rname AND S1.price > S2.price
EXCEPT
SELECT S1.rname, S2.rname FROM Sells AS S1 INNER JOIN Sells AS S2
ON S1.pizza = S2.pizza
WHERE S1.rname <> S2.rname AND S1.price <= S2.price;

-- Question 4
CREATE OR REPLACE VIEW v4 (rname) AS
SELECT rname FROM Restaurants WHERE area = 'Central'
UNION
SELECT rname FROM Sells GROUP BY rname HAVING COUNT(pizza) >= 10
UNION
(SELECT rname FROM Sells
 EXCEPT
 SELECT rname FROM Sells WHERE price > 20);

-- Question 5
CREATE OR REPLACE VIEW v5 (rname) AS
SELECT DISTINCT S1.rname FROM Sells AS S1 INNER JOIN Sells AS S2
ON S1.rname = S2.rname
WHERE S1.pizza <> S2.pizza AND (S1.price + S2.price) <= 40;

-- Question 6
-- AtLeast2Pizzas: 记录中的Pizzas肯定被其中两个人喜欢
-- each of the friends must like at least two of the three pizzas
CREATE OR REPLACE VIEW v6 (rname, pizza1, pizza2, pizza3, totalcost) AS
WITH zz_AtLeast2Pizzas AS (
	SELECT DISTINCT S.rname, L1.cname, L1.pizza, S.price FROM Sells AS S
	INNER JOIN Likes AS L1
	ON S.pizza = L1.pizza
	INNER JOIN Likes AS L2
	ON S.pizza = L2.pizza
	WHERE L1.cname <> L2.cname AND (
		L1.cname = 'Moe' AND L2.cname = 'Larry' OR 
		L1.cname = 'Larry' AND L2.cname = 'Moe' OR 
		L1.cname = 'Moe' AND L2.cname = 'Curly' OR 
		L1.cname = 'Curly' AND L2.cname = 'Moe' OR 
		L1.cname = 'Larry' AND L2.cname = 'Curly' OR 
		L1.cname = 'Curly' AND L2.cname = 'Larry'
	)
)
-- the three pizzas ordered must be distinct pizzas,
-- the total cost of the three pizzas must not exceed $80
-- each of the three pizzas must be liked by at least one of the friends
SELECT DISTINCT A1.rname, A1.pizza, A2.pizza, A3.pizza, (A1.price + A2.price + A3.price) AS totalcost FROM zz_AtLeast2Pizzas AS A1
INNER JOIN zz_AtLeast2Pizzas AS A2
ON A1.rname = A2.rname
INNER JOIN zz_AtLeast2Pizzas AS A3
ON A2.rname = A3.rname
WHERE A1.pizza < A2.pizza AND A2.pizza < A3.pizza
AND A1.cname <> A2.cname AND A2.cname <> A3.cname
AND (A1.price + A2.price + A3.price) <= 80;
	
-- Question 7
CREATE OR REPLACE VIEW v7 (rname) AS
-- numPizza(R)
WITH
zz_T1 AS (
	SELECT R.rname, COUNT(pizza) AS numPizza FROM Restaurants AS R LEFT OUTER JOIN Sells AS S
	ON R.rname = S.rname GROUP BY R.rname
),
-- priceRange(R1)
zz_T2 AS (
	SELECT R.rname, 
	CASE WHEN (MAX(S.price) - MIN(S.price)) IS NULL THEN 0 ELSE (MAX(S.price) - MIN(S.price)) END AS pricerange 
	FROM Restaurants AS R LEFT OUTER JOIN Sells AS S
	ON R.rname = S.rname GROUP BY R.rname
),
-- numPizza(R1) > numPizza(R2) and priceRange(R1) ≥ priceRange(R2)
zz_T3 AS (
	SELECT T11.rname AS T11rname, T12.rname AS T12rname FROM zz_T1 AS T11 INNER JOIN zz_T1 AS T12
	ON T11.rname <> T12.rname
	WHERE T11.numPizza > T12.numPizza
	INTERSECT
	SELECT T21.rname, T22.rname FROM zz_T2 AS T21 INNER JOIN zz_T2 AS T22
	ON T21.rname <> T22.rname
	WHERE T21.pricerange >= T22.pricerange
),
-- numPizza(R1) ≥ numPizza(R2) and priceRange(R1) > priceRange(R2)
zz_T4 AS (
	SELECT T11.rname AS T11rname, T12.rname AS T12rname FROM zz_T1 AS T11 INNER JOIN zz_T1 AS T12
	ON T11.rname <> T12.rname
	WHERE T11.numPizza >= T12.numPizza
	INTERSECT
	SELECT T21.rname, T22.rname FROM zz_T2 AS T21 INNER JOIN zz_T2 AS T22
	ON T21.rname <> T22.rname
	WHERE T21.pricerange > T22.pricerange
)
-- 没有计算自己和自己叉乘的情况，所以要+1
SELECT rname1 FROM 
(
	SELECT R1.rname AS rname1, R2.rname AS rname2 FROM Restaurants AS R1 INNER JOIN Restaurants AS R2
	ON R1.rname <> R2.rname
	EXCEPT
	-- T11rname is more diverse than T12rname
	(
		SELECT T12rname, T11rname FROM zz_T3
		UNION
		SELECT T12rname, T11rname FROM zz_T4
	)
) AS T5
GROUP BY rname1 HAVING COUNT(rname2) + 1 = (SELECT COUNT(*) FROM Restaurants);

-- Question 8
CREATE OR REPLACE VIEW v8 (area, numCust, numRest, maxPrice) AS
WITH 
-- the total number of customers located in A
zz_C1 AS (SELECT area, COUNT(cname) AS nc FROM Customers GROUP BY area),
-- the total number of restaurants located in A
zz_C2 AS (SELECT area, COUNT(rname) AS nr FROM Restaurants GROUP BY area),
zz_C3 AS (SELECT area, MAX(price) AS mp FROM Restaurants AS R LEFT OUTER JOIN Sells AS S ON R.rname = S.rname GROUP BY area)
SELECT area,
CASE WHEN nc IS NULL THEN 0 ELSE nc END AS numCust,
CASE WHEN nr IS NULL THEN 0 ELSE nr END AS numRest,
CASE WHEN mp IS NULL THEN 0 ELSE mp END AS maxPrice
FROM zz_C1 NATURAL FULL OUTER JOIN zz_C2 NATURAL FULL OUTER JOIN zz_C3;

-- Question 9
-- Customers和至少2个Restaurants在同一个地区，这些Restaurants卖的同一些Pizzas也是Customers喜欢的
CREATE OR REPLACE VIEW v9 (cname) AS
WITH 
zz_TT AS (
	WITH zz_T AS (
		SELECT C.cname, R.rname, S.pizza FROM Customers AS C INNER JOIN Restaurants AS R
		ON C.area = R.area
		INNER JOIN Sells AS S
		ON R.rname = S.rname
		INNER JOIN Likes AS L
		ON C.cname = L.cname AND S.pizza = L.pizza
	)
	SELECT DISTINCT T1.cname, T1.pizza FROM zz_T AS T1 INNER JOIN zz_T AS T2
	ON T1.cname = T2.cname AND T1.pizza = T2.pizza
	WHERE T1.rname < T2.rname
),
-- 看Customers喜欢的Pizzas是不是符合要求
zz_TTT AS (
	SELECT * FROM Likes
	EXCEPT
	SELECT * FROM zz_TT
)
-- 把不符合要求的Customers都移除
SELECT cname FROM zz_TT
EXCEPT
SELECT cname FROM zz_TTT;

-- Question 10
CREATE OR REPLACE VIEW v10 (pizza) AS
WITH 
zz_T1 AS (
	SELECT R.area, S.pizza, COUNT(S.pizza) AS numRestaurant FROM Sells AS S INNER JOIN Restaurants AS R
	ON S.rname = R.rname GROUP BY R.area, S.pizza
),
zz_T2 AS (
	SELECT T1.area, T1.pizza FROM zz_T1 AS T1 INNER JOIN zz_T1 AS T2
	ON T1.area = T2.area	
	WHERE T1.numRestaurant >= T2.numRestaurant
	EXCEPT
	SELECT T1.area, T1.pizza FROM zz_T1 AS T1 INNER JOIN zz_T1 AS T2
	ON T1.area = T2.area	
	WHERE T1.numRestaurant < T2.numRestaurant
),
zz_T3 AS (
	SELECT pizza, COUNT(area) AS numArea FROM zz_T2 GROUP BY pizza
)	
SELECT T1.pizza FROM zz_T3 AS T1, zz_T3 AS T2
WHERE T1.numArea >= T2.numArea
EXCEPT
SELECT T1.pizza FROM zz_T3 AS T1, zz_T3 AS T2
WHERE T1.numArea < T2.numArea;


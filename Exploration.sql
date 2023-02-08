--Create table and copy data in
CREATE TABLE sales (

	order_id VARCHAR(15),
	product VARCHAR(100),
	quantity SMALLINT,
	price_each DECIMAL(8,2),
	order_date TIMESTAMP,
	address VARCHAR(50)
	
);

COPY listings 
FROM 'C:\Users\Owner\Downloads\Job Portfolio\Electronics Store\all_data.csv'
DELIMITER ','
CSV HEADER;

--Checking import

SELECT * FROM sales
LIMIT 10;

--Removing time from order date colum

UPDATE sales
SET order_date = CAST(order_date AS DATE);

ALTER TABLE sales
ALTER COLUMN order_date TYPE DATE;

SELECT * FROM sales
LIMIT 5;

--Splitting address field into just city and state

SELECT SPLIT_PART(address,',',2) 
FROM sales;

ALTER TABLE sales
ADD COLUMN city VARCHAR(30);

UPDATE sales
SET city = SPLIT_PART(address,',',2);

ALTER TABLE sales
ADD COLUMN state VARCHAR(30);

UPDATE sales
SET state = LEFT(SPLIT_PART(address,',',3),3);

SELECT * FROM sales
LIMIT 5;

--Add revenue column

ALTER TABLE sales
ADD COLUMN revenue DECIMAL(10,2);

UPDATE sales
SET revenue = (quantity * price_each);

--Seeing how much data we have in 2020

SELECT * FROM sales
WHERE EXTRACT(year FROM order_date) = 2020;

--Only 34 sales, going to just focus on 2019 and remove 2020 data

DELETE FROM sales
WHERE EXTRACT(year FROM order_date) = 2020;

--Looking at our best month revenue wise

SELECT EXTRACT(month FROM order_date) AS month, SUM(revenue)
FROM sales
GROUP BY EXTRACT(month FROM order_date)
ORDER BY sum DESC;

--December by far, overall the end of the year is great while the beginning is slow (holiday deals?)

--Now lets look at it in terms of how many items we sold

SELECT EXTRACT(month FROM order_date) AS month, SUM(quantity)
FROM sales
GROUP BY EXTRACT(month FROM order_date)
ORDER BY sum DESC;

--Similar to above: the holiday season is doing the best

--Let's look into these months, was there a certain product that was increasing revenue/quantity?

SELECT product, SUM(quantity) AS q, SUM(revenue) AS r
FROM sales
WHERE EXTRACT(month FROM order_date) = 12 OR EXTRACT(month FROM order_date) = 11
GROUP BY product
ORDER BY r DESC;

----Using EXTRACT(month FROM order_date) too much, going to just make a month column

ALTER TABLE sales
ADD COLUMN month smallint;

UPDATE sales
SET month = EXTRACT(month FROM order_date);

SELECT * FROM sales 
LIMIT 10;

--Similar story here with the best items, looks like volume just increased. Let's check if price changed for items

SELECT DISTINCT(price_each) FROM sales
WHERE product = --'Macbook Pro Laptop';
'AAA Batteries (4-pack)';

--No change, so definitely looks like volume increase across the board

SELECT product, month, percent_of_q, MAX(percent_of_q) OVER(PARTITION BY product)
FROM(
	SELECT *, 100*q/SUM(q) OVER(PARTITION BY product) as percent_of_q 
	FROM(
		SELECT product, month, SUM(quantity) AS q
		FROM sales
		GROUP BY product, month
		ORDER BY month) as m
	ORDER BY month) as n
	ORDER BY month DESC;
	
--Every single item saw its highest share of quantity sold in Decemebr

--What product sells the most?

SELECT product, SUM(quantity) AS q, SUM(revenue) AS r
FROM sales
GROUP BY product
ORDER BY --q 
r DESC;

--Batteries and charging cabes sell the most. Macbooks get the most revenue by a longshot.

--Lets see what cities sell the most by product

SELECT city, product, SUM(quantity) AS q, SUM(revenue) AS r
FROM sales
GROUP BY city, product
ORDER BY --q 
r DESC;

--San Francisco is beating every city out in revenue for macbooks by a wide margin. They're also outselling 
--every other city in terms of quantity for our 4 top sellers (batteries and charging cables).

--Let's look at what cities are our best for overall sales (not by product)

SELECT city, SUM(quantity) AS q, SUM(revenue) AS r
FROM sales
GROUP BY city 
ORDER BY --q 
r DESC;

--As expected San Fran is miles ahead of other cities in both these categories.

--What item saw the most growth from the beginning to the end of the year?

SELECT product, 100*change_q/lag_q as jan_to_dec_percent_change_q,
	100*change_r/lag_r as jan_to_dec_percent_change_r
FROM(
	SELECT *, q - LAG(q) OVER(ORDER BY product, month) as change_q, LAG(q) OVER(ORDER BY product, month) as lag_q,
		r - LAG(r) OVER(ORDER BY product, month) as change_r, LAG(r) OVER(ORDER BY product, month) as lag_r
	FROM (
		(SELECT product, month, SUM(quantity) AS q, SUM(revenue) as r
		FROM sales
		WHERE month = 12
		GROUP BY product, month
		ORDER BY product)
		UNION ALL
		(SELECT product, month, SUM(quantity) AS q, SUM(revenue) as r
		FROM sales
		WHERE month = 1
		GROUP BY product, month
		ORDER BY product)) as m
	ORDER BY product, month ASC) as n
WHERE month = 12
ORDER BY --jan_to_dec_percent_change_q
jan_to_dec_percent_change_r DESC;

--We can see bose headphones and a 27in gaming monitor has the biggest quantity and revenue increase from jan to dec

--Instead of looking at products, let's look at what cities saw the most growth

SELECT city, 100*change_q/lag_q as jan_to_dec_percent_change_q,
	100*change_r/lag_r as jan_to_dec_percent_change_r
FROM(
	SELECT *, q - LAG(q) OVER(ORDER BY city, month) as change_q, LAG(q) OVER(ORDER BY city, month) as lag_q,
		r - LAG(r) OVER(ORDER BY city, month) as change_r, LAG(r) OVER(ORDER BY city, month) as lag_r
	FROM (
		(SELECT city, month, SUM(quantity) AS q, SUM(revenue) as r
		FROM sales
		WHERE month = 12
		GROUP BY city, month
		ORDER BY city)
		UNION ALL
		(SELECT city, month, SUM(quantity) AS q, SUM(revenue) as r
		FROM sales
		WHERE month = 1
		GROUP BY city, month
		ORDER BY city)) as m
	ORDER BY city, month ASC) as n
WHERE month = 12
ORDER BY --jan_to_dec_percent_change_q
jan_to_dec_percent_change_r DESC;

--Now let's look at the change from jan to dec as a whole, not by product

SELECT
	(SELECT SUM(revenue) FROM sales
WHERE month = 12)
-
	(SELECT SUM(revenue) FROM sales
WHERE month = 1)

SELECT
	(SELECT SUM(quantity) FROM sales
WHERE month = 12)
-
	(SELECT SUM(quantity) FROM sales
WHERE month = 1)

--Let's look at the change in revenue/quantity month-by-month

SELECT month, SUM(revenue),
	SUM(revenue) - LAG (SUM(revenue)) OVER (ORDER BY month) AS revenue_growth,
	(SUM(revenue) - LAG (SUM(revenue)) OVER (ORDER BY month))/LAG (SUM(revenue)) 
	 OVER (ORDER BY month)*100 AS revenue_growth_percent
FROM sales
GROUP BY month;

SELECT month, SUM(quantity),
	SUM(quantity) - LAG (SUM(quantity)) OVER (ORDER BY month) AS quantity_growth
FROM sales
GROUP BY month;

--Let's find our bottom 2 worst months

SELECT month, SUM(revenue) as r, SUM(quantity) as q
FROM sales
GROUP BY month
ORDER BY --q
r
LIMIT 2;

--Jan Sept are the worst for both

--Top 2 best

SELECT month, SUM(revenue) as r, SUM(quantity) as q
FROM sales
GROUP BY month
ORDER BY --q
r DESC
LIMIT 2;

--Dec and Oct are the best for both



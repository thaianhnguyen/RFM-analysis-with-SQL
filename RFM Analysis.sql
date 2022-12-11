-- define used database
USE EcomSales;

-- Create new table in the database for later use in Visualization
Create table Rfm (
	customer nvarchar(50),
	recency smallint,
	frequency tinyint,
	monetary float,
	recency_rank tinyint,
	frequency_rank tinyint,
	monetary_rank tinyint, 
	rfm_score tinyint,
	segment varchar(30)
	);

-- Declare the variable of current time
declare @now date
set @now = DATEADD( day, 3, (select MAX(cast(order_purchase_timestamp as date)) from orders));
-- pulling out delivery date and revenue for only DELIVERED orders
with cte as(
select customer_unique_id, o2.order_id, 
	   cast(order_purchase_timestamp as date) as purchase_date, 
	   price
from  order_items o1 
inner join orders o2 on o1.order_id = o2.order_id
inner join customers c on o2.customer_id = c.customer_id
where order_status = 'delivered')
-- calculate recency, frequency, monetary values
insert into Rfm (customer, recency, frequency, monetary)
select customer_unique_id as customer,  
	   datediff(day,(MAX(purchase_date)), @now) as recency,
	   count(distinct order_id) as frequency, 
	   sum(price) as monetary
from cte
group by customer_unique_id;

with cte2 as (
select customer, 
	round(PERCENT_RANK() over (order by recency)*100,2) as r,
	round(PERCENT_RANK() over (order by frequency)*100,2) as f,
	round(PERCENT_RANK() over (order by monetary)*100,2) as m
from rfm)
update rfm 
set recency_rank =(
select Case when r <= 25 then 4
			when r <= 50 then 3
			when r <= 75 then 2
			else 1 end
from cte2
where cte2.customer = rfm.customer),
	frequency_rank =(
select Case when f <= 25 then 1
			when f <= 50 then 2
			when f <= 75 then 3
			else 4 end 
from cte2
where cte2.customer = rfm.customer),
	monetary_rank = (
select Case when m <= 25 then 1
			when m <= 50 then 2
			when m <= 75 then 3
			else 4 end
from cte2
where cte2.customer = rfm.customer);

-- use summary statistics to check the distribution of indices:
select frequency_rank, count(*)
from rfm
group by frequency_rank;
-- check the distribution of frequency values
select frequency, count(*)
from rfm
group by frequency
order by frequency;
-- Re-calculated the frequency_rank:
update rfm 
set frequency_rank =(
	select 
	Case when frequency > 2 then 3
  		 when frequency >1 then 2
  		 else 1 end
    from rfm);

with cte3 as (
select customer,
	   recency_rank + frequency_rank + monetary_rank as rfm_score
from rfm),
cte4 as (
select customer,
	   Round(PERCENT_RANK() over (order by rfm_score)*100, 2) as RFM_rank 
from cte3)
update  Rfm 
set segment =(
select  
	Case when RFM_rank <= 25 then 'Churn'
	when RFM_rank <= 50 then 'Likely to churn'
	when RFM_rank <= 75 then 'Middle'
	else 'Loyal' end
	from  cte4
	where cte4.customer = rfm.customer);
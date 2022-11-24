# RFM analysis with SQL
Dataset was collected from Kaggle: [Bank Customer Churn Dataset](https://www.kaggle.com/datasets/gauravtopre/bank-customer-churn-dataset)

For this project, I will conduct an RFM analysis to segment customers, in hopes of helping business users develop their targeted marketing campaigns as well as CRM. </br>
The segmentation is based on 3 dimensions: Recency (how long has it been since the last order of customers), Frequency (How often do they make purchases) and Monetary (How much do they pay for our goods). </br>
The company in this project is Olist, an e-commerce company, which connects small business owners from all over Brazil to sellers, who sell their products through the Olist Store and ship them directly to the customers using Olist logistics partners.

Because the analysis will be featured on my subsequent Power BI project; therefore, I will create a separate table for more conveniences:
~~~~sql
-- define used database
USE EcomSales

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
	)
~~~~
Next step, I will pull out the three dimensional values for the analysis. </br>For the calculation of recency values, I set the current time is 3 days after the last recorded date of purchases.
~~~~sql
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
~~~~
Results:</br>
![alt text](https://github.com/thaianhnguyen/RFM-analysis-with-SQL/blob/main/images%20rfm/Screenshot_1.jpg)


I then calculate the percentile rank for each index (for recency, the lower the better, and the opposite for the other two)
~~~sql
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
~~~~
Results:</br>
![alt text](https://github.com/thaianhnguyen/RFM-analysis-with-SQL/blob/main/images%20rfm/Screenshot_2.jpg)

Before moving further, I checked the distribution of the indices to make sure score are given equally. I then discovered _only_ value 1 and 4 were available for frequency index; therefore, I check the distribution of frequency values. </br>Most frequency values are 1 or 2; therefore, I altered my way of calculating frequency index (1 for 1, 2 for 2 and >2 for 3) to give scoring mechanism a better meaning
~~~~sql
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
~~~~
![alt text](https://github.com/thaianhnguyen/RFM-analysis-with-SQL/blob/main/images%20rfm/Screenshot_3.jpg)

I then calculated the aggregated RFM score and finish segmenting customers
~~~~sql
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
  ~~~~
Results:</br>
![alt text](https://github.com/thaianhnguyen/RFM-analysis-with-SQL/blob/main/images%20rfm/Screenshot_4.jpg)

And here is the tree map of the customer segmentation we've just gone through</br>
![alt text](https://github.com/thaianhnguyen/RFM-analysis-with-SQL/blob/main/images%20rfm/Screenshot_5.jpg)


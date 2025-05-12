--1. Retrieve Active Retailers in the last 30 days rolling? (Active Retailers : did at least 1 Delivered order).
 
select distinct(r.id), r.full_name
from Retailers r join Orders o
on r.id = o.id
where status = 'delivered' and o.created_at between dateadd(day, -29,  (select Max(created_at) from orders)) and 
(select Max(created_at) from orders)



--2. Sign up Retailers in the last 30 days (Signed up within the last 30 days) 
select distinct(r.id), r.created_at
from Retailers r
where created_at between dateadd(day, -29,  (select Max(created_at) from orders)) and 
(select Max(created_at) from orders)
order by r.created_at


--3. New Retailers in the last 30 days (Made his first order within the last 30 days) 
with First_order_date as (select distinct(o.Retailer_id), min(created_at) as thedate
from Orders o
where status = 'delivered'
Group by Retailer_id
),


orders_in_last_3_day as (select distinct(o.Retailer_id), o.created_at
from Orders o
where status = 'delivered' and 
o.created_at between dateadd(day, -29, (select Max(created_at) from orders)) and 
(select Max(created_at) from orders)
)

select *
from First_order_date
where thedate in (select created_at from orders_in_last_3_day)


--4. Churned Retailers who didn't do any delivered order in the last 30 days and their total GMV lifetime is above 3000 \

with orders_in_last_3_day as (select distinct(o.Retailer_id), o.created_at
from Orders o
where status = 'delivered' and 
o.created_at between dateadd(day, -29, (select Max(created_at) from orders)) and 
(select Max(created_at) from orders)
),


GMV_lifetime as (select o.Retailer_id, sum(GMV) as total_GMV 
from Orders o
group by o.Retailer_id
)

select GMV_lifetime.Retailer_id, GMV_lifetime.total_GMV
from GMV_lifetime 
where total_GMV > 3000 and GMV_lifetime.Retailer_id not in (select Retailer_id from orders_in_last_3_day) 


--5. Retailers whom their last order was between 60 days and 30 days

with Last_order as (select Retailer_id, max(created_at) as last_order
from orders
group by Retailer_id
),


previous_order as (select Retailer_id, created_at as order_date,
lag(created_at) over (partition by Retailer_id order by created_at) as previous_order
from orders
),

days_between_orders as (select pr.Retailer_id, ls.last_order, pr.order_date,DATEDIFF(DAY,previous_order, order_date) AS days_between_orders
from previous_order pr join last_order ls
on pr.Retailer_id = ls.Retailer_id
)

select Retailer_id,last_order, order_date
from days_between_orders
where days_between_orders between 30 and 60

--6. Retailers who didn't create any orders 
select Retailer_id, full_name
from Orders o left join Retailers r
on o.id = r.id
where o.created_at is null

--7. Retailers who created orders but not delivered >> Like Vlookup
select r.id, r.full_name		
from Retailers r
where exists (select o.Retailer_id
from orders o 
where r.id = o.Retailer_id
)

and not exists (
    select r.id 
    from Orders o
    where o.Retailer_id = r.id AND o.status = 'Delivered'
)


--8. Retailers who did more than 5 delivered orders in the last 30 days with their total GMV 
select o.Retailer_id, o.created_at,count(*) as no_of_orders, sum(GMV) as total_GMV
from orders o 
where status = 'delivered' and created_at between dateadd(day, -29,  (select Max(created_at) from orders)) and 
(select Max(created_at) from orders)
group by Retailer_id, created_at
having count(*) > 5



--9. How many Retailers who were active last month and still active this month 
with active_retailers as (select o.Retailer_id, created_at, format(created_at,'yyyy-MM') as order_month
from Orders o
where status = 'delivered'
),

Last_2_orders as (select distinct top 2 format(created_at,'yyyy-MM') as order_month
from Orders
where status = 'delivered'
order by format(created_at,'yyyy-MM') desc
),

count_per_retailer as(select ar.Retailer_id,format(ar.created_at, 'yyyy-MM') as order_month,
row_number() over (partition by ar.Retailer_id order by ar.created_at) as rn
from active_retailers ar join Last_2_orders l2o
on format(ar.created_at,'yyyy-MM') = l2o.order_month
)

select count(distinct Retailer_id) as no_of_retailers
from count_per_retailer
having Count(*) = 2


--10 . How many orders have more than 5 Products 
select count(*) as no_of_orders_bigger_t_5P
from (
select o.id
from orders o join Order_Details od
on o.id = od.Order_Id
group by o.id
having count(Product_Supplier_Id) > 5
) as a

--11. Average of number of items in orders
select (sum(amount) / count(distinct Order_Id)) as AVG_items_per_orders
from Order_Details

--12. Count of orders and retailers per Area

with orders_per_area as (select o.Retailer_id, r.full_name,count(*) as no_of_orders, r.Area_id
from Orders o join Retailers r
on o.Retailer_id = r.id
group by Retailer_id, full_name,Area_id
)

select Area_id, count(Retailer_id) as no_of_retailers, sum(no_of_orders) as total_orders 
from orders_per_area
group by Area_id


--13. Number of orders for each retailer in his first 30 days 

with retailer_sign_up_date as (select r.id, min(created_at) as sign_up
from Retailers r
group by id
)

select o.Retailer_id, count(*)
from Orders o join retailer_sign_up_date rsud
on o.Retailer_id = rsud.id
where o.created_at between sign_up and dateadd(day, 30, (select min(created_at) from Orders))
group by Retailer_id


--14. Retention Rate per month in year 2020 (Retention means Retailers who were active last month and still active this month) 
with active_months as (select distinct Retailer_id,format(created_at, 'yyyy-MM') as year_month
from Orders
where status = 'delivered' and year(created_at) = '2020'
),

ranked_activity as (select Retailer_id, year_month,
lag(year_month) over (partition by Retailer_id order by year_month) as prev_month
from active_months
),

retained as (select year_month,Retailer_id
from ranked_activity
where dateadd(month, -1, cast(year_month + '-01' as date)) = CAST(prev_month + '-01' as date)
)

select year_month,COUNT(distinct Retailer_id) as retained_retailers
from retained
group by year_month
order by year_month;


--15. GMV of the first order per Retailer

with first_order_date as (select o.Retailer_id, min(created_at) as first_order_date
from Orders o
group by Retailer_id
)

select o.Retailer_id, round(o.GMV,2)
from Orders o join first_order_date fod
on o.Retailer_id = fod.Retailer_id
and o.created_at = fod.first_order_date





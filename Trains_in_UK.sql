use railway;

select * from rc_upload; 

-- 1) Average ticket price by purchase type (online/station) each month, compared to the overall average
with 
first_step as  
(
	select 	
		purchase_type,
		date_format(date_of_purchase, '%Y-%m') as month_of_purchase,
		concat(round(avg(price), 2), ' GBP') as avg_price
	from rc_upload
	group by purchase_type, date_format(date_of_purchase, '%Y-%m')
),
second_step as
(
	select 
		concat(round(avg(price), 2), ' GBP') as overall_avg_price
	from rc_upload
)
	select  
		fs.purchase_type,
		fs.month_of_purchase,
		fs.avg_price,
		ss.overall_avg_price
	from first_step fs
	cross join second_step ss;

-- 2) Ranking of the 5 origin stations with the highest average delay in minutes in January-April 2024
select * from rc_upload; 

with 
first_step as
(
	select 
		departure_station,
		journey_status,
		timestampdiff(MINUTE, arrival_time, actual_arrival_time) as time_diff
	from rc_upload
	where journey_status = 'Delayed'
),
second_step as 
(
	select
		departure_station,
		round(avg(time_diff), 2) as avg_time_diff
	from first_step
	group by departure_station
),
third_step as
(
	select 
		departure_station,
		avg_time_diff,
		row_number() over (order by avg_time_diff desc) as avg_time_diff_ranked
	from second_step
)
select * from third_step
where avg_time_diff_ranked <= 5;

-- 3) The percentage of delayed trips for each ticket class, broken down by month
select * from rc_upload;

with 
first_step as
(
	select 
		ticket_class,
		date_format(date_of_purchase, '%Y-%m') as per_month,
		count(*) as journey_count,
		sum(case when journey_status = 'Delayed' then 1 else 0 end) as delayed_journey
	from rc_upload
	group by ticket_class, date_format(date_of_purchase, '%Y-%m')
),
second_step as
(
	select 
		ticket_class,
		per_month,
		journey_count,
		delayed_journey,
		concat(round(100 * delayed_journey / journey_count, 2), '%') as prc_ratio
	from first_step
)
select * from second_step;

-- 4) Average delay time by delay reason, excluding on-time journeys 
select * from rc_upload; 

with 
first_step as
(
	select 
		reason_for_delay,
		round(avg(timestampdiff(minute, arrival_time, actual_arrival_time)), 2) as avg_time_diff
	from rc_upload
	where journey_status = 'Delayed'
	group by reason_for_delay
)
select * from first_step;

-- 6) Value of tickets sold by month, along with the percentage change month-on-month
select * from rc_upload; 

with 
first_step as        -- total ticket prices each month
(
	select 	
		date_format(date_of_purchase, '%Y-%m') as ticket_per_month,
		sum(price) as sum_price
	from rc_upload
	group by date_format(date_of_purchase, '%Y-%m')
),
second_step as   -- month-to-month change
(
	select 	
		ticket_per_month,
		sum_price,
		lag(sum_price) over (order by ticket_per_month) as previous_month,
		sum_price - lag(sum_price) over (order by ticket_per_month) as price_change
	from first_step 
),
third_step as   -- percentage change
(
	select 
		ticket_per_month,
		sum_price,
		previous_month,
		price_change,
		concat(round((100 * price_change / previous_month), 2), '%') as prc_rate
	from second_step 
)
select * from third_step;

-- 7) Average ticket price depending on the time of day
with 
first_step as 
(
	select 
		case 
			when time_of_purchase between '05:00:00' and '11:59:59' then 'Morning'
			when time_of_purchase between '12:00:00' and '16:59:59' then 'Midday'
			when time_of_purchase between '17:00:00' and '21:59:59' then 'Evening'
			else 'Night'
		end as time_of_day,
		round(avg(price), 2) as avg_price,
		count(*) as count_of_tickets
	from rc_upload
	group by time_of_day
)
select * from first_step
order by 
	case 
		when time_of_day = 'Morning' then 1
		when time_of_day = 'Midday' then 2
		when time_of_day = 'Evening' then 3
		else 4
	end;

-- 8) Comparison of travel punctuality on weekdays vs. weekends
select * from rc_upload;

with 
first_step as
(
	select 
		case 
			when dayofweek(date_of_journey) in (1, 7) then 'Weekend'
			else 'Weekday'
		end as day_of_week,
		journey_status
	from rc_upload
),
second_step as
(
	select 
		day_of_week,
		count(*) as journey_count,
		sum(case when journey_status = 'On Time'then 1 else 0 end) as on_time_journey,
		sum(case when journey_status = 'Delayed' then 1 else 0 end) as delayed_journey
	from first_step
	group by day_of_week
 )
select  
 	day_of_week,
 	journey_count,
 	on_time_journey,
 	delayed_journey
from second_step
order by day_of_week;

-- 9) The 3 most popular travel stories by number of tickets sold each month
select * from rc_upload;

with 
first_step as
(
	select 
		departure_station,
		arrival_destination,
		date_format(date_of_purchase, '%Y-%m') as month_of_purchase,
		count(*) as ticket_count
	from rc_upload
	group by departure_station, arrival_destination, date_format(date_of_purchase, '%Y-%m')
),
second_step as
(
	select 
		departure_station,
		arrival_destination,
		month_of_purchase,
		ticket_count,
		row_number() over(partition by month_of_purchase order by ticket_count desc) as ticket_count_ranked
	from first_step
)
select * from second_step
where ticket_count_ranked <= 3;

-- 10) Analysis of payment methods - which ones dominate online purchases and which ones are used at the gas station
select * from rc_upload;

with
first_step as
(
	select 
		purchase_type,
		payment_method,
		count(*) as payment_count
	from rc_upload
	group by purchase_type,
	payment_method 
),
second_step as
(
	select 
		purchase_type,
		payment_method,
		payment_count,
		row_number() over (partition by purchase_type order by payment_count desc) as payment_count_ranked
	from first_step
)
select * from second_step
where payment_count_ranked = 1;

-- 11) Time between ticket purchase and travel date - mean and standard deviation by ticket type
select * from rc_upload; 

with 
first_step as
(
	select 
		ticket_type,
		date_of_purchase,
		date_of_journey,
		datediff(date_of_journey, date_of_purchase) as time_diff
	from rc_upload
),
second_step as
(
	select 
		ticket_type,
		round(avg(time_diff), 2) as avg_time_diff,
		round(stddev_pop(time_diff), 2) as stddev_time_diff
	from first_step
	group by ticket_type
)
select * from second_step;

-- 12) Comparison of the average ticket price for delayed trips vs. on-time vs. canceled trips - with the difference in percentage
select * from rc_upload; 

with 
first_step as
(
	select 
		journey_status,
		round(avg(price), 2) as avg_price
	from rc_upload
	where journey_status in ('On Time', 'Delayed')
	group by journey_status
),
second_step as
(
	select 
		max(case when journey_status = 'On Time' then avg_price end) as on_time,
		max(case when journey_status = 'Delayed' then avg_price end) as delayed_journey
	from first_step
)
select 
	on_time,
	delayed_journey,
	delayed_journey - on_time as the_diff,
	concat(ROUND(100 * (delayed_journey - on_time) / on_time, 2), '%') as prc_rate
from second_step;

-- 13) Analysis of the impact of 'Railcard' discount cards on the average ticket price
select * from rc_upload; 

select 	
	railcard,
	avg(price) as avg_price
from rc_upload
group by railcard
order by avg_price;

-- 14) Average number of minutes of delay by day of the week
select * from rc_upload;

select
	dayname(date_of_journey) as day_of_week,
	round(avg(timestampdiff(minute, arrival_time, actual_arrival_time)), 2) as avg_time_diff
from rc_upload
group by dayname(date_of_journey)
order by field(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

-- 15) Number of tickets sold and delayed trips by month, with month-on-month change
select * from rc_upload; 

with 
first_step as    -- tickets sold each month
(
	select 
		DATE_FORMAT(date_of_purchase, '%Y-%m') as month_of_purchase,
		count(*) as ticket_count
	from rc_upload
	group by date_format(date_of_purchase, '%Y-%m')
),
second_step as
(
	select 
		date_format(date_of_purchase, '%Y-%m') as month_of_purchase,
		sum(case when journey_status = 'Delayed' then 1 else 0 end) as delayed_trip
	from rc_upload
	group by date_format(date_of_purchase, '%Y-%m')
),
third_step as
(
	select  
		fs.month_of_purchase,
		fs.ticket_count,
		ss.delayed_trip,
		lag(fs.ticket_count) over (order by fs.month_of_purchase) as previous_one,
		(fs.ticket_count - lag(fs.ticket_count) over (order by fs.month_of_purchase)) as the_diff,
		lag(ss.delayed_trip) over (order by fs.month_of_purchase) as previous_trip,
		(ss.delayed_trip - lag(ss.delayed_trip) over (order by fs.month_of_purchase)) as the_diff_1
	from first_step fs
	join second_step ss
	on fs.month_of_purchase = ss.month_of_purchase
)
select 
	month_of_purchase,
	ticket_count,
	the_diff,
	delayed_trip,
	the_diff_1
from third_step;


	






	

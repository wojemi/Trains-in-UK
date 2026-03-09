use railway;

select * from rc_upload; 

show columns from rc_upload;

select count(*) from rc_upload; 

select  
	min(price) as min_price,
	max(price) as max_price,
	avg(price) as avg_price
from rc_upload;

select 
	min(date_of_purchase) as min_date,
	max(date_of_purchase) as max_date
from rc_upload;

-- 1) Average ticket price broken down by type of purchase (online/at the station) in eatch months compared to the overall average:
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

-- Overal average price is equal to 23.44 GBP 
-- We can observe that in the first month of 2024 online tickets were cheaper than in December 2023. Tickets purchased at the station have doubled in price.
-- Tickets purchased via the website are characterized by the fact that their price is lower than the average ticket price.

-- 2) Ranking of top 5 stations with the highest average delay in minutes between January and April 2024:
select * from rc_upload

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

-- Manchester Picadilly station is the one with the longest delays = 58.83 minutes
-- Liverpool Lime Street is the fifth station with the longest delays = 34.85 minutes

-- 3) The percentage of delayed journeys for each ticket class, broken down by month:
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

-- In the analyzed period First Class journeys are always delayed more than Standard Class, with the exception of March 2024.
-- In December 2023, 50% of First Class journeys were delayed. but this was because there were only 2 such journeys, one of which was delayed.

-- 4) Average delay time depending on the reason for the delay, excluding punctual journeys:
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

-- The highest average delay was caused by Staff Shortages and amounted to almost 75 minutes.
-- Technical issues caused only 25-minute delays.
-- Weather conditions and signal failures are also causing huge delays.

-- 6) Value of tickets sold by month, with month-to-month percentage change:
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

-- In January 2024 total value of tickets changed by 29537.43% compared to December 2023.
-- Then in February we recorded a decrease of 24.85%. In March 2024 tickets value increas of 26.39% and in April 2024 fell again of 3.88%.

-- 7) Average ticket price depending on the time of day:
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

-- The average ticket price is the lowest on the Evening - tip for customers: it is better to but tickets online and on evenings.
-- The most expensive time of day to buy tickets is in the morning with an average ticket price of GBP 29.47.

-- 8) Comparison of travel punctuality on weekdays vs. weekends:
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

-- On weekdays there are more delayes, but the total number of trips is 60% higher.

-- 9) The 3 most popular travel routes in terms of ticket sales each month:
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

-- For example in January 2024 the most popular travel route was Manchester Piccadilly - Liverpool Lime Street - 1,258 tickets were sold.
-- It was also the month and tour when the most tickets were sold in the entire period analyzed.

-- 10) Analysis of payment methods - which ones dominate online purchases ad which ones at the station?
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

-- When it comes to online purchases, the most popular payment method is by credit card.
-- The same situation applies to tickets purchased at the station.

-- 11) Time between ticket purchase and travel date - average and standard deviation by ticket type:
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

-- Advanced tickets are purchased almost 3 days before trip.

-- 12) Comparison of the average ticket price for delayed journeys vs. punctual journeys - with the difference shown as a percentage
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

-- The average ticket price for on-time travel is GBP 20.73, while for delayed travel the price is more than twice as high, at GBP 55.33.

-- 13) The average number of minutes of delay broken down by day of the week:
select * from rc_upload;

select
	dayname(date_of_journey) as day_of_week,
	round(avg(timestampdiff(minute, arrival_time, actual_arrival_time)), 2) as avg_time_diff
from rc_upload
group by dayname(date_of_journey)
order by field(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

-- The longest average delay is on Thursdays and amounts to 3.61 minutes.
-- The smallest average delay is on Monday and amounts to 3.06 minutes.

-- 14) Number of tickets sold and delayed journeys broken down by month, with month-on-month change:
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

-- The number of tickets sold was higher in odd-numbered months of 2024.
-- The number of delayed journeys was also higher in the 0dd-numbered months of 2024.


	





	

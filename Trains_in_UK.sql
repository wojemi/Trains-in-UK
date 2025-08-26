use railway;

select * from rc_upload; 

-- 1) Średnia cena biletu z podziałem na typ zakupu (online/stacja) w każdym miesiącu, z porównaniem do średniej ogólnej
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

-- 2) Ranking 5 stacji początkowych, które mają najwyższe średnie opóźnienie w minutach w okresie styczeń-kwiecień 2024
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

-- 3) Przedstaw procent podróży opóźnionych dla każdej klasy biletu z podziałem na miesiące
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

-- 4) Średni czas opóźnienia w zależności od powodu opóźnienia, z wykluczeniem podróży punktualnych
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

-- 6) Wartość sprzedanych biletów w podziale na miesiące, wraz z procentową zmianą miesiąc do miesiąca
select * from rc_upload; 

with 
first_step as        -- suma cen biletów w każdym miesiącu
(
	select 	
		date_format(date_of_purchase, '%Y-%m') as ticket_per_month,
		sum(price) as sum_price
	from rc_upload
	group by date_format(date_of_purchase, '%Y-%m')
),
second_step as   -- zmiana miesiąc do miesiąca
(
	select 	
		ticket_per_month,
		sum_price,
		lag(sum_price) over (order by ticket_per_month) as previous_month,
		sum_price - lag(sum_price) over (order by ticket_per_month) as price_change
	from first_step 
),
third_step as   -- procentowa zmiana
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

-- 7) Średnia cena biletu w zależności od pory dnia
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

-- 8) Porównanie punktualności podróży w dni robocze vs weekendy
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


-- 9) 3 najpopularniejsze relacje podróżnicze pod względem liczby sprzedanych biletów w każdym miesiącu
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

-- 10) Analiza metod płatności - które dominują w przypadku zakupów online, a które na stacji
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

-- 11) Czas pomiędzy zakupem biletu a datą podróży - średnia i odchylenie standardowe w podziale na rodzaj biletu
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

-- 12) Porównanie średniej ceny biletu opóźnionych podróży vs punktualnych vs odwołanych - z wyznaczeniem różnicy w procentach
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

-- 13) Analiza wpływu kart zniżkowych 'Railcard' na średnią cenę biletu
select * from rc_upload; 

select 	
	railcard,
	avg(price) as avg_price
from rc_upload
group by railcard
order by avg_price;

-- 14) Średnia liczba minut opóźnienia w podziale na dni tygodnia
select * from rc_upload;

select
	dayname(date_of_journey) as day_of_week,
	round(avg(timestampdiff(minute, arrival_time, actual_arrival_time)), 2) as avg_time_diff
from rc_upload
group by dayname(date_of_journey)
order by field(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

-- 15) Liczba sprzedanych biletów oraz opóźnionych podróży w podziale miesięcznym wraz ze zmiana miesiąc do miesiąca
select * from rc_upload; 

with 
first_step as    -- sprzedane bilety w każdym miesiącu
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


	





	
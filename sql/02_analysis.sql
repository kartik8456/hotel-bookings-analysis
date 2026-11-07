-- =====================================================================
-- HOTEL BOOKINGS: ANALYSIS
-- Requires 01_cleaning.sql to have been run (hotel_data_clean and the
-- view hotel_bookings_unique must exist). These queries only read data.
-- "all rows" = hotel_data_clean, "duplicates removed" = hotel_bookings_unique
-- =====================================================================

-- Fix: helper view that stacks both versions, so every query can compare them
CREATE OR REPLACE VIEW hotel_analysis AS
SELECT 'all rows' AS version, h.* FROM hotel_data_clean h
UNION ALL
SELECT 'duplicates removed', u.* FROM hotel_bookings_unique u;

-- Verify: the helper view holds both versions (expect 120,090 and 91,658)
SELECT version, COUNT(*) AS bookings
FROM hotel_analysis
GROUP BY version;

-- Analysis: overview of the dataset, all rows vs duplicates removed
SELECT version,
       COUNT(*)                                          AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1)                AS cancel_pct,
       ROUND(AVG(adr), 2)                                AS avg_adr,
       ROUND(AVG(lead_time), 0)                          AS avg_lead_time_days,
       ROUND(AVG(stays_in_weekend_nights + stays_in_week_nights), 1) AS avg_nights
FROM hotel_analysis
GROUP BY version
ORDER BY version;


-- Analysis: cancellation rate by hotel
SELECT version, hotel,
       COUNT(*)                           AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM hotel_analysis
GROUP BY version, hotel
ORDER BY version, hotel;


-- Analysis: cancellation rate by deposit type
SELECT version, deposit_type,
       COUNT(*)                           AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM hotel_analysis
GROUP BY version, deposit_type
ORDER BY version, bookings DESC;


-- Analysis: cancellation rate by lead time bucket
SELECT version, lead_bucket,
       COUNT(*)                           AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM (
  SELECT version, is_canceled,
         CASE
           WHEN lead_time IS NULL THEN '0. unknown'
           WHEN lead_time <= 7    THEN '1. 0-7 days'
           WHEN lead_time <= 30   THEN '2. 8-30 days'
           WHEN lead_time <= 90   THEN '3. 31-90 days'
           WHEN lead_time <= 180  THEN '4. 91-180 days'
           WHEN lead_time <= 365  THEN '5. 181-365 days'
           ELSE                        '6. over 365 days'
         END AS lead_bucket
  FROM hotel_analysis
) t
GROUP BY version, lead_bucket
ORDER BY version, lead_bucket;


-- Analysis: who makes Non Refund bookings (all rows)
SELECT market_segment, hotel,
		COUNT(*) AS bookings,
		ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM hotel_data_clean
WHERE deposit_type = 'Non Refund'
GROUP BY market_segment, hotel
ORDER BY bookings DESC;


-- Analysis: bookings, average price, and cancellation rate by month and hotel (duplicates removed)
SELECT hotel,
		arrival_date_month AS month,
		COUNT(*) AS bookings,
		ROUND(AVG(adr), 2) AS avg_adr,
		ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM hotel_bookings_unique
GROUP BY hotel, arrival_date_month
ORDER BY hotel, MIN(EXTRACT(MONTH FROM TO_DATE(arrival_date_month, 'Month')));


-- Analysis: bookings, average price and cancellation rate by month and hotel, 2016 only (the only full year)
SELECT hotel,
       arrival_date_month                          AS month,
       COUNT(*)                                    AS bookings,
       ROUND(AVG(adr), 2)                          AS avg_adr,
       ROUND(100.0 * AVG(is_canceled), 1)          AS cancel_pct
FROM hotel_bookings_unique
WHERE arrival_date_year = 2016
GROUP BY hotel, arrival_date_month
ORDER BY hotel, MIN(EXTRACT(MONTH FROM TO_DATE(arrival_date_month, 'Month')));

-- Analysis: top 10 guest countries by bookings (duplicates removed)
SELECT country,
       COUNT(*)                                            AS bookings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS share_pct,
       ROUND(100.0 * AVG(is_canceled), 1)                  AS cancel_pct
FROM hotel_bookings_unique
WHERE country IS NOT NULL
GROUP BY country
ORDER BY bookings DESC
LIMIT 10;

-- Analysis: bookings, cancellation rate, price and lead time by market segment
SELECT version, market_segment,
       COUNT(*)                           AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct,
       ROUND(AVG(adr), 2)                 AS avg_adr,
       ROUND(AVG(lead_time), 0)           AS avg_lead_time
FROM hotel_analysis
GROUP BY version, market_segment
ORDER BY version, bookings DESC;

-- Analysis: estimated revenue from completed stays by hotel and year (duplicates removed)
SELECT hotel, arrival_date_year AS yr,
       COUNT(*)                                                           AS stays,
       ROUND(SUM(adr * (stays_in_weekend_nights + stays_in_week_nights))) AS est_revenue
FROM hotel_bookings_unique
WHERE reservation_status = 'Check-Out'
  AND adr IS NOT NULL
  AND arrival_date_year IS NOT NULL
GROUP BY hotel, arrival_date_year
ORDER BY hotel, arrival_date_year;



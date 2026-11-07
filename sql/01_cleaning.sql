-- =====================================================================
-- HOTEL BOOKINGS: DATA CLEANING IN POSTGRESQL
-- Raw table : hotel_data         (all columns TEXT, never edited)
-- Work table: hotel_data_clean   (all cleaning happens here)
-- Method    : Diagnose (look) -> Fix (change) -> Verify (check)
-- Run this script top to bottom, one statement at a time in pgAdmin.
-- =====================================================================


-- =====================================================================
-- PHASE 0: SETUP
-- =====================================================================

-- Fix: create the raw staging table (everything TEXT so messy values load)
DROP TABLE IF EXISTS hotel_data;
CREATE TABLE hotel_data (
    booking_id TEXT, hotel TEXT, is_canceled TEXT, lead_time TEXT,
    arrival_date_year TEXT, arrival_date_month TEXT, arrival_date_week_number TEXT,
    arrival_date_day_of_month TEXT, stays_in_weekend_nights TEXT, stays_in_week_nights TEXT,
    adults TEXT, children TEXT, babies TEXT, meal TEXT, country TEXT, market_segment TEXT,
    distribution_channel TEXT, is_repeated_guest TEXT, previous_cancellations TEXT,
    previous_bookings_not_canceled TEXT, reserved_room_type TEXT, assigned_room_type TEXT,
    booking_changes TEXT, deposit_type TEXT, agent TEXT, company TEXT, days_in_waiting_list TEXT,
    customer_type TEXT, adr TEXT, required_car_parking_spaces TEXT, total_of_special_requests TEXT,
    reservation_status TEXT, reservation_status_date TEXT
);

-- Load the CSV (run in psql, or use pgAdmin Import/Export):
-- \copy hotel_data FROM 'hotel_bookings_messy.csv' WITH (FORMAT csv, HEADER true);

-- Diagnose: row count (expect 121,590)
SELECT COUNT(*) FROM hotel_data;

-- Fix: make the working copy
DROP TABLE IF EXISTS hotel_data_clean;
CREATE TABLE hotel_data_clean AS SELECT * FROM hotel_data;


-- =====================================================================
-- PHASE 1: REMOVE EXACT DUPLICATES (same booking_id)
-- =====================================================================

-- Diagnose: how many extra copies of a booking_id (expect 1,500)
SELECT COUNT(*) AS rows_to_delete
FROM (SELECT ROW_NUMBER() OVER (PARTITION BY booking_id ORDER BY ctid) AS rn
      FROM hotel_data_clean) t
WHERE rn > 1;

-- Fix: keep the first copy of each booking_id, delete the rest
DELETE FROM hotel_data_clean
WHERE ctid IN (
    SELECT ctid
    FROM (SELECT ctid,
                 ROW_NUMBER() OVER (PARTITION BY booking_id ORDER BY ctid) AS rn
          FROM hotel_data_clean) t
    WHERE rn > 1
);

-- Verify: both numbers should be 120,090
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT booking_id) AS unique_ids
FROM hotel_data_clean;


-- =====================================================================
-- PHASE 2: STANDARDIZE TEXT COLUMNS
-- Pattern: strip non-letters, lowercase, then map to one standard label.
-- Careful with the regex: '[^A-Za-z]' needs a hyphen in both ranges.
-- =====================================================================

-- Diagnose: spellings of hotel
SELECT hotel, COUNT(*) AS total FROM hotel_data_clean GROUP BY hotel ORDER BY total DESC;

-- Fix: hotel
UPDATE hotel_data_clean
SET hotel = CASE
    WHEN LOWER(TRIM(hotel)) LIKE 'city%'   THEN 'City Hotel'
    WHEN LOWER(TRIM(hotel)) LIKE 'resort%' THEN 'Resort Hotel'
    ELSE hotel
END;

-- Fix: reservation_status (standard spelling: Cancelled, with a double l)
UPDATE hotel_data_clean
SET reservation_status = CASE
    WHEN LOWER(REGEXP_REPLACE(reservation_status, '[^A-Za-z]', '', 'g')) IN ('checkout', 'checkedout') THEN 'Check-Out'
    WHEN LOWER(REGEXP_REPLACE(reservation_status, '[^A-Za-z]', '', 'g')) IN ('canceled', 'cancelled')  THEN 'Cancelled'
    WHEN LOWER(REGEXP_REPLACE(reservation_status, '[^A-Za-z]', '', 'g')) IN ('noshow')                 THEN 'No-Show'
    ELSE reservation_status
END;

-- Fix: meal (SC and Undefined both mean "no meal package", so they are merged into SC)
UPDATE hotel_data_clean
SET meal = CASE
    WHEN LOWER(REGEXP_REPLACE(meal, '[^A-Za-z]', '', 'g')) IN ('bb')              THEN 'BB'
    WHEN LOWER(REGEXP_REPLACE(meal, '[^A-Za-z]', '', 'g')) IN ('hb', 'halfboard') THEN 'HB'
    WHEN LOWER(REGEXP_REPLACE(meal, '[^A-Za-z]', '', 'g')) IN ('fb', 'fullboard') THEN 'FB'
    WHEN LOWER(REGEXP_REPLACE(meal, '[^A-Za-z]', '', 'g')) IN ('sc', 'undefined') THEN 'SC'
    ELSE meal
END;

-- Fix: deposit_type
UPDATE hotel_data_clean
SET deposit_type = CASE
    WHEN LOWER(REGEXP_REPLACE(deposit_type, '[^A-Za-z]', '', 'g')) = 'nodeposit'  THEN 'No Deposit'
    WHEN LOWER(REGEXP_REPLACE(deposit_type, '[^A-Za-z]', '', 'g')) = 'nonrefund'  THEN 'Non Refund'
    WHEN LOWER(REGEXP_REPLACE(deposit_type, '[^A-Za-z]', '', 'g')) = 'refundable' THEN 'Refundable'
    ELSE deposit_type
END;

-- Fix: market_segment
UPDATE hotel_data_clean
SET market_segment = CASE
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'onlineta'      THEN 'Online TA'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'offlinetato'   THEN 'Offline TA/TO'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'direct'       THEN 'Direct'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'groups'       THEN 'Groups'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'corporate'    THEN 'Corporate'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'complementary' THEN 'Complementary'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'aviation'     THEN 'Aviation'
    WHEN LOWER(REGEXP_REPLACE(market_segment, '[^A-Za-z]', '', 'g')) = 'undefined'    THEN 'Undefined'
    ELSE market_segment
END;

-- Fix: distribution_channel
UPDATE hotel_data_clean
SET distribution_channel = CASE
    WHEN LOWER(REGEXP_REPLACE(distribution_channel, '[^A-Za-z]', '', 'g')) = 'tato'      THEN 'TA/TO'
    WHEN LOWER(REGEXP_REPLACE(distribution_channel, '[^A-Za-z]', '', 'g')) = 'direct'    THEN 'Direct'
    WHEN LOWER(REGEXP_REPLACE(distribution_channel, '[^A-Za-z]', '', 'g')) = 'corporate' THEN 'Corporate'
    WHEN LOWER(REGEXP_REPLACE(distribution_channel, '[^A-Za-z]', '', 'g')) = 'gds'       THEN 'GDS'
    WHEN LOWER(REGEXP_REPLACE(distribution_channel, '[^A-Za-z]', '', 'g')) = 'undefined' THEN 'Undefined'
    ELSE distribution_channel
END;

-- Fix: customer_type
UPDATE hotel_data_clean
SET customer_type = CASE
    WHEN LOWER(REGEXP_REPLACE(customer_type, '[^A-Za-z]', '', 'g')) = 'transient'      THEN 'Transient'
    WHEN LOWER(REGEXP_REPLACE(customer_type, '[^A-Za-z]', '', 'g')) = 'transientparty' THEN 'Transient-Party'
    WHEN LOWER(REGEXP_REPLACE(customer_type, '[^A-Za-z]', '', 'g')) = 'contract'       THEN 'Contract'
    WHEN LOWER(REGEXP_REPLACE(customer_type, '[^A-Za-z]', '', 'g')) = 'group'          THEN 'Group'
    ELSE customer_type
END;

-- Fix: arrival_date_month (keeps digits so 7 and 07 can be mapped to July)
UPDATE hotel_data_clean
SET arrival_date_month = CASE
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('jan', 'january',   '1',  '01') THEN 'January'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('feb', 'february',  '2',  '02') THEN 'February'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('mar', 'march',     '3',  '03') THEN 'March'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('apr', 'april',     '4',  '04') THEN 'April'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('may',              '5',  '05') THEN 'May'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('jun', 'june',      '6',  '06') THEN 'June'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('jul', 'july',      '7',  '07') THEN 'July'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('aug', 'august',    '8',  '08') THEN 'August'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('sep', 'september', '9',  '09') THEN 'September'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('oct', 'october',   '10')       THEN 'October'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('nov', 'november',  '11')       THEN 'November'
    WHEN LOWER(REGEXP_REPLACE(arrival_date_month, '[^A-Za-z0-9]', '', 'g')) IN ('dec', 'december',  '12')       THEN 'December'
    ELSE arrival_date_month
END;

-- Fix: country (names and 2-letter forms to 3-letter codes, then upper case and trim)
UPDATE hotel_data_clean
SET country = CASE
    WHEN UPPER(TRIM(country)) IN ('PORTUGAL', 'PR')       THEN 'PRT'
    WHEN UPPER(TRIM(country)) IN ('UNITED KINGDOM', 'GB') THEN 'GBR'
    WHEN UPPER(TRIM(country)) IN ('FRANCE', 'FR')         THEN 'FRA'
    WHEN UPPER(TRIM(country)) IN ('SPAIN', 'ES')          THEN 'ESP'
    WHEN UPPER(TRIM(country)) IN ('GERMANY', 'DE')        THEN 'DEU'
    WHEN UPPER(TRIM(country)) IN ('ITALY', 'IT')          THEN 'ITA'
    WHEN UPPER(TRIM(country)) IN ('IRELAND', 'IR')        THEN 'IRL'
    WHEN UPPER(TRIM(country)) IN ('BELGIUM', 'BE')        THEN 'BEL'
    WHEN UPPER(TRIM(country)) IN ('BRAZIL', 'BR')         THEN 'BRA'
    WHEN UPPER(TRIM(country)) IN ('NETHERLANDS', 'NL')    THEN 'NLD'
    WHEN UPPER(TRIM(country)) IN ('UNITED STATES', 'US')  THEN 'USA'
    WHEN UPPER(TRIM(country)) IN ('SWITZERLAND', 'CH')    THEN 'CHE'
    ELSE UPPER(TRIM(country))
END;

-- Fix: merge CN into CHN (the source data uses both codes for China)
UPDATE hotel_data_clean SET country = 'CHN' WHERE country = 'CN';

-- Fix: room types (trim spaces, upper case)
UPDATE hotel_data_clean
SET reserved_room_type = UPPER(TRIM(reserved_room_type)),
    assigned_room_type = UPPER(TRIM(assigned_room_type));

-- Fix: is_canceled (Yes/No/TRUE/FALSE to 1/0, still text at this point)
UPDATE hotel_data_clean
SET is_canceled = CASE
    WHEN LOWER(TRIM(is_canceled)) IN ('1', 'yes', 'y', 'true') THEN '1'
    WHEN LOWER(TRIM(is_canceled)) IN ('0', 'no', 'n', 'false') THEN '0'
    ELSE is_canceled
END;

-- Verify: distinct values per standardized column (expect 2, 12, 2, 4, 8, 5, 3, 4, 3)
SELECT 'hotel' AS col, COUNT(DISTINCT hotel) AS n FROM hotel_data_clean
UNION ALL SELECT 'arrival_date_month',  COUNT(DISTINCT arrival_date_month)  FROM hotel_data_clean
UNION ALL SELECT 'is_canceled',         COUNT(DISTINCT is_canceled)         FROM hotel_data_clean
UNION ALL SELECT 'meal',                COUNT(DISTINCT meal)                FROM hotel_data_clean
UNION ALL SELECT 'market_segment',      COUNT(DISTINCT market_segment)      FROM hotel_data_clean
UNION ALL SELECT 'distribution_channel',COUNT(DISTINCT distribution_channel) FROM hotel_data_clean
UNION ALL SELECT 'deposit_type',        COUNT(DISTINCT deposit_type)        FROM hotel_data_clean
UNION ALL SELECT 'customer_type',       COUNT(DISTINCT customer_type)       FROM hotel_data_clean
UNION ALL SELECT 'reservation_status',  COUNT(DISTINCT reservation_status)  FROM hotel_data_clean;


-- =====================================================================
-- PHASE 3: MISSING VALUES (placeholders to real NULL)
-- Placeholders: '', NULL, N/A, NA, -, unknown, none (as text)
-- =====================================================================

-- Diagnose: count placeholders per column
SELECT
  COUNT(*) FILTER (WHERE UPPER(TRIM(country))      IN ('', 'NULL', 'N/A', 'NA', 'NONE', 'UNKNOWN', '-')) AS country_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(children))  IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS children_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(adults))    IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS adults_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(lead_time)) IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS lead_time_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(adr))       IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS adr_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(agent))     IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS agent_missing,
  COUNT(*) FILTER (WHERE LOWER(TRIM(company))   IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none')) AS company_missing
FROM hotel_data_clean;

-- Fix: country placeholders to NULL
UPDATE hotel_data_clean
SET country = NULL
WHERE UPPER(TRIM(country)) IN ('', 'NULL', 'N/A', 'NA', 'NONE', 'UNKNOWN', '-');

-- Fix: numeric column placeholders to NULL
UPDATE hotel_data_clean
SET
  children  = CASE WHEN LOWER(TRIM(children))  IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE children  END,
  adults    = CASE WHEN LOWER(TRIM(adults))    IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE adults    END,
  lead_time = CASE WHEN LOWER(TRIM(lead_time)) IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE lead_time END,
  adr       = CASE WHEN LOWER(TRIM(adr))       IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE adr       END,
  agent     = CASE WHEN LOWER(TRIM(agent))     IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE agent     END,
  company   = CASE WHEN LOWER(TRIM(company))   IN ('', 'null', 'n/a', 'na', '-', 'unknown', 'none') THEN NULL ELSE company   END;
-- Note: NULL in agent/company means "no agent / no company" in the source data.
-- They are left as NULL on purpose (not filled with 0).


-- =====================================================================
-- PHASE 4: NUMBER FORMATS AND DATA TYPES
-- =====================================================================

-- Fix: adr ($120, 99,5, 120 USD to a plain number)
UPDATE hotel_data_clean
SET adr = REPLACE(REGEXP_REPLACE(adr, '[^0-9.,-]', '', 'g'), ',', '.')
WHERE adr !~ '^-?[0-9]+(\.[0-9]+)?$';

-- Fix: lead_time ('45 days' to 45)
UPDATE hotel_data_clean
SET lead_time = REGEXP_REPLACE(lead_time, '[^0-9-]', '', 'g')
WHERE lead_time !~ '^-?[0-9]+$';

-- Fix: adults ('two' to 2, '2 adults' to 2)
UPDATE hotel_data_clean
SET adults = CASE
    WHEN LOWER(TRIM(adults)) = 'one'   THEN '1'
    WHEN LOWER(TRIM(adults)) = 'two'   THEN '2'
    WHEN LOWER(TRIM(adults)) = 'three' THEN '3'
    ELSE REGEXP_REPLACE(adults, '[^0-9-]', '', 'g')
END
WHERE adults !~ '^-?[0-9]+$';

-- Fix: agent ('240.0' to 240)
UPDATE hotel_data_clean
SET agent = REGEXP_REPLACE(agent, '\.0$', '')
WHERE agent !~ '^[0-9]+$';

-- Diagnose: any non-numeric value left? (expect no rows)
SELECT key AS column_name, COUNT(*) AS non_numeric_values
FROM hotel_data_clean t, jsonb_each_text(to_jsonb(t))
WHERE key IN ('is_canceled','lead_time','arrival_date_year','arrival_date_week_number',
              'arrival_date_day_of_month','stays_in_weekend_nights','stays_in_week_nights',
              'adults','children','babies','is_repeated_guest','previous_cancellations',
              'previous_bookings_not_canceled','booking_changes','agent','company',
              'days_in_waiting_list','adr','required_car_parking_spaces',
              'total_of_special_requests')
  AND value !~ '^-?[0-9]+(\.[0-9]+)?$'
GROUP BY key;

-- Fix: convert columns from TEXT to real number types (all-or-nothing)
ALTER TABLE hotel_data_clean
  ALTER COLUMN is_canceled                    TYPE SMALLINT USING is_canceled::SMALLINT,
  ALTER COLUMN lead_time                      TYPE INTEGER  USING lead_time::INTEGER,
  ALTER COLUMN arrival_date_year              TYPE INTEGER  USING arrival_date_year::INTEGER,
  ALTER COLUMN arrival_date_week_number       TYPE INTEGER  USING arrival_date_week_number::INTEGER,
  ALTER COLUMN arrival_date_day_of_month      TYPE INTEGER  USING arrival_date_day_of_month::INTEGER,
  ALTER COLUMN stays_in_weekend_nights        TYPE INTEGER  USING stays_in_weekend_nights::INTEGER,
  ALTER COLUMN stays_in_week_nights           TYPE INTEGER  USING stays_in_week_nights::INTEGER,
  ALTER COLUMN adults                         TYPE INTEGER  USING adults::INTEGER,
  ALTER COLUMN children                       TYPE INTEGER  USING children::NUMERIC::INTEGER,
  ALTER COLUMN babies                         TYPE INTEGER  USING babies::INTEGER,
  ALTER COLUMN is_repeated_guest              TYPE SMALLINT USING is_repeated_guest::SMALLINT,
  ALTER COLUMN previous_cancellations         TYPE INTEGER  USING previous_cancellations::INTEGER,
  ALTER COLUMN previous_bookings_not_canceled TYPE INTEGER  USING previous_bookings_not_canceled::INTEGER,
  ALTER COLUMN booking_changes                TYPE INTEGER  USING booking_changes::INTEGER,
  ALTER COLUMN agent                          TYPE INTEGER  USING agent::INTEGER,
  ALTER COLUMN company                        TYPE INTEGER  USING company::INTEGER,
  ALTER COLUMN days_in_waiting_list           TYPE INTEGER  USING days_in_waiting_list::INTEGER,
  ALTER COLUMN adr                            TYPE NUMERIC(10,2) USING adr::NUMERIC(10,2),
  ALTER COLUMN required_car_parking_spaces    TYPE INTEGER  USING required_car_parking_spaces::INTEGER,
  ALTER COLUMN total_of_special_requests      TYPE INTEGER  USING total_of_special_requests::INTEGER;

-- Verify: column types
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'hotel_data_clean'
ORDER BY ordinal_position;


-- =====================================================================
-- PHASE 5: DATES (reservation_status_date)
-- The column mixes many formats. Day/month order is decided from the
-- digits where one number is above 12; otherwise DD-MM-YYYY is assumed.
-- Two-digit years are read as 2000-2069.
-- =====================================================================

-- Diagnose: count date formats
SELECT
  CASE
    WHEN reservation_status_date ~ '^\d{4}-\d{2}-\d{2}$'       THEN 'YYYY-MM-DD (correct)'
    WHEN reservation_status_date ~ '^\d{2}-\d{2}-\d{4}$'       THEN 'NN-NN-YYYY (mixed order)'
    WHEN reservation_status_date ~ '^\d{2}/\d{2}/\d{4}$'       THEN 'DD/MM/YYYY'
    WHEN reservation_status_date ~ '^\d{2}-[A-Za-z]{3}-\d{4}$' THEN 'DD-Mon-YYYY'
    WHEN reservation_status_date ~ '^\d{2}-[A-Za-z]{3}-\d{2}$' THEN 'DD-Mon-YY'
    WHEN reservation_status_date ~ '^[A-Za-z]+ \d{2}, \d{4}$'  THEN 'Month DD, YYYY'
    WHEN reservation_status_date ~ '^\d{4}/\d{2}/\d{2}$'       THEN 'YYYY/MM/DD'
    WHEN reservation_status_date ~ '^\d{2}\.\d{2}\.\d{2}$'     THEN 'DD.MM.YY'
    ELSE 'other / missing / invalid'
  END AS format_type,
  COUNT(*) AS total
FROM hotel_data_clean
GROUP BY format_type
ORDER BY total DESC;

-- Fix: set placeholder and invalid dates to NULL
UPDATE hotel_data_clean
SET reservation_status_date = NULL
WHERE TRIM(reservation_status_date) = ''
   OR UPPER(TRIM(reservation_status_date)) IN ('NULL', 'N/A', 'NA', 'NOT AVAILABLE', '-')
   OR reservation_status_date LIKE '0000%'
   OR (reservation_status_date ~ '^\d{4}-\d{2}-\d{2}$'
       AND reservation_status_date !~ '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$');

-- Fix: convert every format to YYYY-MM-DD
UPDATE hotel_data_clean
SET reservation_status_date = TO_CHAR(
  CASE
    WHEN reservation_status_date ~ '^\d{2}-\d{2}-\d{4}$' THEN
      CASE WHEN SPLIT_PART(reservation_status_date, '-', 2)::INT > 12
           THEN TO_DATE(reservation_status_date, 'MM-DD-YYYY')
           ELSE TO_DATE(reservation_status_date, 'DD-MM-YYYY')
      END
    WHEN reservation_status_date ~ '^\d{2}/\d{2}/\d{4}$'       THEN TO_DATE(reservation_status_date, 'DD/MM/YYYY')
    WHEN reservation_status_date ~ '^\d{2}-[A-Za-z]{3}-\d{4}$' THEN TO_DATE(reservation_status_date, 'DD-Mon-YYYY')
    WHEN reservation_status_date ~ '^\d{2}-[A-Za-z]{3}-\d{2}$' THEN TO_DATE(reservation_status_date, 'DD-Mon-YY')
    WHEN reservation_status_date ~ '^[A-Za-z]+ \d{2}, \d{4}$'  THEN TO_DATE(reservation_status_date, 'Month DD, YYYY')
    WHEN reservation_status_date ~ '^\d{4}/\d{2}/\d{2}$'       THEN TO_DATE(reservation_status_date, 'YYYY/MM/DD')
    WHEN reservation_status_date ~ '^\d{2}\.\d{2}\.\d{2}$'     THEN TO_DATE(reservation_status_date, 'DD.MM.YY')
  END, 'YYYY-MM-DD')
WHERE reservation_status_date IS NOT NULL
  AND reservation_status_date !~ '^\d{4}-\d{2}-\d{2}$';

-- Verify: nothing left in a non-standard format (expect no rows)
SELECT reservation_status_date, COUNT(*) AS total
FROM hotel_data_clean
WHERE reservation_status_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY reservation_status_date;

-- Fix: change reservation_status_date to DATE type
ALTER TABLE hotel_data_clean
  ALTER COLUMN reservation_status_date TYPE DATE
  USING reservation_status_date::DATE;

-- Diagnose: dates after the end of the dataset (2017-09-14) must be misread
SELECT COUNT(*) AS after_dataset_end
FROM hotel_data_clean
WHERE reservation_status_date > DATE '2017-09-14';

-- Fix: swap day and month for dates after the dataset end
UPDATE hotel_data_clean
SET reservation_status_date = MAKE_DATE(
        EXTRACT(YEAR  FROM reservation_status_date)::INT,
        EXTRACT(DAY   FROM reservation_status_date)::INT,
        EXTRACT(MONTH FROM reservation_status_date)::INT)
WHERE reservation_status_date > DATE '2017-09-14'
  AND EXTRACT(DAY FROM reservation_status_date) <= 12;

-- Verify: date range (expect 2014-10-17 to 2017-09-14)
SELECT MIN(reservation_status_date)::TEXT AS earliest,
       MAX(reservation_status_date)::TEXT AS latest
FROM hotel_data_clean;


-- =====================================================================
-- PHASE 6: OUTLIERS AND IMPOSSIBLE VALUES (set to NULL, never guessed)
-- Impossible values are fixed. Unusual but possible values are kept
-- (adr = 0 is a free stay; children up to 10 exist in the source).
-- =====================================================================

-- Diagnose: min and max of each numeric column
SELECT 'lead_time' AS col, MIN(lead_time) AS min_v, MAX(lead_time) AS max_v FROM hotel_data_clean
UNION ALL SELECT 'adr', MIN(adr), MAX(adr) FROM hotel_data_clean
UNION ALL SELECT 'adults', MIN(adults), MAX(adults) FROM hotel_data_clean
UNION ALL SELECT 'children', MIN(children), MAX(children) FROM hotel_data_clean
UNION ALL SELECT 'babies', MIN(babies), MAX(babies) FROM hotel_data_clean
UNION ALL SELECT 'arrival_date_year', MIN(arrival_date_year), MAX(arrival_date_year) FROM hotel_data_clean
UNION ALL SELECT 'arrival_date_week_number', MIN(arrival_date_week_number), MAX(arrival_date_week_number) FROM hotel_data_clean
UNION ALL SELECT 'arrival_date_day_of_month', MIN(arrival_date_day_of_month), MAX(arrival_date_day_of_month) FROM hotel_data_clean
UNION ALL SELECT 'stays_in_week_nights', MIN(stays_in_week_nights), MAX(stays_in_week_nights) FROM hotel_data_clean
UNION ALL SELECT 'stays_in_weekend_nights', MIN(stays_in_weekend_nights), MAX(stays_in_weekend_nights) FROM hotel_data_clean;

-- Diagnose: how many rows each rule will change
SELECT
  COUNT(*) FILTER (WHERE lead_time < 0)                       AS lead_time_negative,
  COUNT(*) FILTER (WHERE lead_time > 800)                     AS lead_time_too_big,
  COUNT(*) FILTER (WHERE adr < 0)                             AS adr_negative,
  COUNT(*) FILTER (WHERE adr > 1000)                          AS adr_too_big,
  COUNT(*) FILTER (WHERE adults < 0)                          AS adults_negative,
  COUNT(*) FILTER (WHERE adults = 0 AND COALESCE(children,0) = 0 AND COALESCE(babies,0) = 0) AS adults_empty_booking,
  COUNT(*) FILTER (WHERE arrival_date_year NOT IN (2015,2016,2017)) AS bad_year,
  COUNT(*) FILTER (WHERE arrival_date_day_of_month < 1
                      OR arrival_date_day_of_month > 31
                      OR (arrival_date_month IN ('April','June','September','November') AND arrival_date_day_of_month > 30)
                      OR (arrival_date_month = 'February' AND arrival_date_day_of_month > 29)) AS bad_day,
  COUNT(*) FILTER (WHERE stays_in_week_nights < 0
                      OR stays_in_week_nights > 60)           AS bad_week_nights
FROM hotel_data_clean;

-- Fix: lead_time (negative, or above 800 days; real values stop near 740)
UPDATE hotel_data_clean SET lead_time = NULL
WHERE lead_time < 0 OR lead_time > 800;

-- Fix: adr (negative, or above 1000; adr = 0 is kept)
UPDATE hotel_data_clean SET adr = NULL
WHERE adr < 0 OR adr > 1000;

-- Fix: adults (negative, empty bookings, or above 10; the values 20 and 50
-- appeared in every segment in proportion to its size, which points to errors)
UPDATE hotel_data_clean SET adults = NULL
WHERE adults < 0
   OR (adults = 0 AND COALESCE(children,0) = 0 AND COALESCE(babies,0) = 0)
   OR adults > 10;

-- Fix: arrival_date_year (the data covers 2015 to 2017 only)
UPDATE hotel_data_clean SET arrival_date_year = NULL
WHERE arrival_date_year NOT IN (2015, 2016, 2017);

-- Fix: arrival_date_day_of_month (must exist in that month)
UPDATE hotel_data_clean SET arrival_date_day_of_month = NULL
WHERE arrival_date_day_of_month < 1
   OR arrival_date_day_of_month > 31
   OR (arrival_date_month IN ('April','June','September','November') AND arrival_date_day_of_month > 30)
   OR (arrival_date_month = 'February' AND arrival_date_day_of_month > 29);

-- Fix: stays_in_week_nights (negative, or above 60)
UPDATE hotel_data_clean SET stays_in_week_nights = NULL
WHERE stays_in_week_nights < 0 OR stays_in_week_nights > 60;


-- =====================================================================
-- PHASE 7: CONTRADICTIONS (is_canceled vs reservation_status)
-- In the source data the two columns agree on every row, so
-- reservation_status (the final recorded outcome) is treated as correct.
-- =====================================================================

-- Diagnose: find contradictions between is_canceled and reservation_status
SELECT is_canceled, reservation_status, COUNT(*) AS total
FROM hotel_data_clean
GROUP BY is_canceled, reservation_status
ORDER BY is_canceled, reservation_status;

-- Fix: set is_canceled from reservation_status (449 rows)
UPDATE hotel_data_clean
SET is_canceled = CASE
    WHEN reservation_status = 'Check-Out' THEN 0
    ELSE 1
END
WHERE (reservation_status = 'Check-Out'               AND is_canceled <> 0)
   OR (reservation_status IN ('Cancelled', 'No-Show') AND is_canceled <> 1);


-- =====================================================================
-- PHASE 8: REPAIR SWAPPED DAY/MONTH DATES USING ARRIVAL DATE
-- Check-Out: status date = arrival date + weekend nights + week nights
-- No-Show  : status date = arrival date
-- Cancelled bookings have no exact rule and are not repaired here.
-- =====================================================================

-- Diagnose: check status dates against arrival date + nights (find swapped day/month)
WITH c AS (
  SELECT reservation_status AS status,
         reservation_status_date AS d,
         MAKE_DATE(arrival_date_year,
                   EXTRACT(MONTH FROM TO_DATE(arrival_date_month, 'Month'))::INT,
                   arrival_date_day_of_month)
         + CASE WHEN reservation_status = 'Check-Out'
                THEN stays_in_weekend_nights + stays_in_week_nights
                ELSE 0 END AS expected
  FROM hotel_data_clean
  WHERE reservation_status IN ('Check-Out', 'No-Show')
)
SELECT status,
       CASE
         WHEN d IS NULL OR expected IS NULL THEN 'cannot check'
         WHEN d = expected                  THEN 'matches'
         WHEN EXTRACT(DAY FROM d) <= 12
          AND MAKE_DATE(EXTRACT(YEAR FROM d)::INT,
                        EXTRACT(DAY  FROM d)::INT,
                        EXTRACT(MONTH FROM d)::INT) = expected THEN 'swapped (fixable)'
         ELSE 'other mismatch'
       END AS result,
       COUNT(*) AS total
FROM c
GROUP BY 1, 2
ORDER BY 1, 2;

-- Fix: swap day/month where the swapped date matches arrival date + nights (1,066 rows)
UPDATE hotel_data_clean h
SET reservation_status_date = c.swapped
FROM (
  SELECT booking_id,
         reservation_status_date AS d,
         MAKE_DATE(EXTRACT(YEAR  FROM reservation_status_date)::INT,
                   EXTRACT(DAY   FROM reservation_status_date)::INT,
                   EXTRACT(MONTH FROM reservation_status_date)::INT) AS swapped,
         MAKE_DATE(arrival_date_year,
                   EXTRACT(MONTH FROM TO_DATE(arrival_date_month, 'Month'))::INT,
                   arrival_date_day_of_month)
         + CASE WHEN reservation_status = 'Check-Out'
                THEN stays_in_weekend_nights + stays_in_week_nights
                ELSE 0 END AS expected
  FROM hotel_data_clean
  WHERE reservation_status IN ('Check-Out', 'No-Show')
    AND EXTRACT(DAY FROM reservation_status_date) <= 12
) c
WHERE h.booking_id = c.booking_id
  AND c.d <> c.expected
  AND c.swapped = c.expected;

-- Verify: swapped dates remaining (expect 0)
WITH c AS (
  SELECT reservation_status_date AS d,
         MAKE_DATE(arrival_date_year,
                   EXTRACT(MONTH FROM TO_DATE(arrival_date_month, 'Month'))::INT,
                   arrival_date_day_of_month)
         + CASE WHEN reservation_status = 'Check-Out'
                THEN stays_in_weekend_nights + stays_in_week_nights
                ELSE 0 END AS expected
  FROM hotel_data_clean
  WHERE reservation_status IN ('Check-Out', 'No-Show')
)
SELECT COUNT(*) AS swapped_remaining
FROM c
WHERE d <> expected
  AND EXTRACT(DAY FROM d) <= 12
  AND MAKE_DATE(EXTRACT(YEAR  FROM d)::INT,
                EXTRACT(DAY   FROM d)::INT,
                EXTRACT(MONTH FROM d)::INT) = expected;


-- =====================================================================
-- PHASE 9: CONTENT DUPLICATES (identical except booking_id)
-- Flagged, not deleted: identical rows may be separate rooms in a block
-- booking (mostly cancelled Groups / Offline TA/TO bookings in City Hotel).
-- =====================================================================

-- Diagnose: count rows identical in every column except booking_id (expect 28,432)
SELECT COUNT(*) AS content_duplicates
FROM (
  SELECT ROW_NUMBER() OVER (
           PARTITION BY (to_jsonb(t) - 'booking_id')
           ORDER BY booking_id) AS rn
  FROM hotel_data_clean t
) x
WHERE rn > 1;

-- Diagnose: describe the 10 biggest groups of identical bookings
SELECT COUNT(*)                  AS copies,
       MIN(hotel)                AS hotel,
       MIN(arrival_date_year)    AS yr,
       MIN(arrival_date_month)   AS month,
       MIN(arrival_date_day_of_month) AS day,
       MIN(stays_in_week_nights) AS week_nights,
       MIN(adults)               AS adults,
       MIN(country)              AS country,
       MIN(market_segment)       AS segment,
       MIN(agent)                AS agent,
       MIN(reservation_status)   AS status,
       MIN(adr)                  AS adr
FROM hotel_data_clean t
GROUP BY (to_jsonb(t) - 'booking_id')
ORDER BY copies DESC
LIMIT 10;

-- Fix: add is_duplicate column (FALSE by default)
ALTER TABLE hotel_data_clean ADD COLUMN is_duplicate BOOLEAN DEFAULT FALSE;

-- Fix: mark every repeated copy as duplicate (keep the first booking_id in each group)
UPDATE hotel_data_clean h
SET is_duplicate = TRUE
FROM (
  SELECT booking_id,
         ROW_NUMBER() OVER (
           PARTITION BY (to_jsonb(t) - 'booking_id' - 'is_duplicate')
           ORDER BY booking_id) AS rn
  FROM hotel_data_clean t
) d
WHERE h.booking_id = d.booking_id
  AND d.rn > 1;

-- Fix: create a view without flagged duplicates, for analysis
CREATE OR REPLACE VIEW hotel_bookings_unique AS
SELECT * FROM hotel_data_clean WHERE is_duplicate = FALSE;

-- Verify: flagged vs unique rows (expect 28,432 TRUE and 91,658 FALSE)
SELECT is_duplicate, COUNT(*) AS total
FROM hotel_data_clean
GROUP BY is_duplicate;

-- Diagnose: cancellation rate with and without flagged duplicates
SELECT 'all rows' AS version, COUNT(*) AS bookings,
       ROUND(100.0 * AVG(is_canceled), 1) AS cancel_pct
FROM hotel_data_clean
UNION ALL
SELECT 'duplicates removed', COUNT(*),
       ROUND(100.0 * AVG(is_canceled), 1)
FROM hotel_bookings_unique;


-- =====================================================================
-- PHASE 10: FINAL VALIDATION (before vs after)
-- =====================================================================

-- Verify: NULL count and percentage per column in the cleaned table
SELECT key AS column_name,
       COUNT(*) FILTER (WHERE value IS NULL)                              AS null_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE value IS NULL) / COUNT(*), 1) AS null_pct
FROM hotel_data_clean t, jsonb_each_text(to_jsonb(t))
GROUP BY key
ORDER BY null_count DESC;

-- Verify: distinct values per categorical column, raw vs cleaned
SELECT 'hotel' AS column_name,
       (SELECT COUNT(DISTINCT hotel) FROM hotel_data) AS before_clean,
       (SELECT COUNT(DISTINCT hotel) FROM hotel_data_clean) AS after_clean
UNION ALL SELECT 'arrival_date_month',  (SELECT COUNT(DISTINCT arrival_date_month) FROM hotel_data),  (SELECT COUNT(DISTINCT arrival_date_month) FROM hotel_data_clean)
UNION ALL SELECT 'is_canceled',         (SELECT COUNT(DISTINCT is_canceled) FROM hotel_data),         (SELECT COUNT(DISTINCT is_canceled) FROM hotel_data_clean)
UNION ALL SELECT 'meal',                (SELECT COUNT(DISTINCT meal) FROM hotel_data),                (SELECT COUNT(DISTINCT meal) FROM hotel_data_clean)
UNION ALL SELECT 'country',             (SELECT COUNT(DISTINCT country) FROM hotel_data),             (SELECT COUNT(DISTINCT country) FROM hotel_data_clean)
UNION ALL SELECT 'market_segment',      (SELECT COUNT(DISTINCT market_segment) FROM hotel_data),      (SELECT COUNT(DISTINCT market_segment) FROM hotel_data_clean)
UNION ALL SELECT 'distribution_channel',(SELECT COUNT(DISTINCT distribution_channel) FROM hotel_data),(SELECT COUNT(DISTINCT distribution_channel) FROM hotel_data_clean)
UNION ALL SELECT 'deposit_type',        (SELECT COUNT(DISTINCT deposit_type) FROM hotel_data),        (SELECT COUNT(DISTINCT deposit_type) FROM hotel_data_clean)
UNION ALL SELECT 'customer_type',       (SELECT COUNT(DISTINCT customer_type) FROM hotel_data),       (SELECT COUNT(DISTINCT customer_type) FROM hotel_data_clean)
UNION ALL SELECT 'reservation_status',  (SELECT COUNT(DISTINCT reservation_status) FROM hotel_data),  (SELECT COUNT(DISTINCT reservation_status) FROM hotel_data_clean)
UNION ALL SELECT 'reserved_room_type',  (SELECT COUNT(DISTINCT reserved_room_type) FROM hotel_data),  (SELECT COUNT(DISTINCT reserved_room_type) FROM hotel_data_clean)
UNION ALL SELECT 'assigned_room_type',  (SELECT COUNT(DISTINCT assigned_room_type) FROM hotel_data),  (SELECT COUNT(DISTINCT assigned_room_type) FROM hotel_data_clean);

-- Diagnose: 3-letter country codes in the raw table that no longer exist in the cleaned table
SELECT DISTINCT UPPER(TRIM(r.country)) AS missing_code
FROM hotel_data r
WHERE UPPER(TRIM(r.country)) ~ '^[A-Z]{3}$'
  AND UPPER(TRIM(r.country)) NOT IN (
        SELECT country FROM hotel_data_clean WHERE country IS NOT NULL);

-- Verify: row counts at each stage
SELECT 'raw (hotel_data)' AS stage, COUNT(*) AS total_rows FROM hotel_data
UNION ALL SELECT 'cleaned (hotel_data_clean)',     COUNT(*) FROM hotel_data_clean
UNION ALL SELECT 'flagged duplicates',             COUNT(*) FROM hotel_data_clean WHERE is_duplicate
UNION ALL SELECT 'unique (hotel_bookings_unique)', COUNT(*) FROM hotel_bookings_unique;

-- VIEW 1 : vehicles that can be rented right now ----------------------
CREATE OR REPLACE VIEW v_available_vehicles AS
SELECT v.vehicle_id, v.registration_number, v.brand, v.model,
       c.vehicle_type, c.daily_rate
FROM vehicles v
JOIN vehicle_categories c ON v.category_id = c.category_id
WHERE v.status = 'Available';

-- VIEW 2 : total money collected per vehicle (all payment types) ------
CREATE OR REPLACE VIEW v_vehicle_income AS
SELECT v.vehicle_id, v.registration_number, v.brand, v.model,
       COALESCE(SUM(p.amount), 0) AS total_income
FROM vehicles v
LEFT JOIN rental_bookings b ON b.vehicle_id    = v.vehicle_id
LEFT JOIN rental_agreements a ON a.booking_id = b.booking_id
LEFT JOIN payments          p ON p.agreement_id = a.agreement_id
GROUP BY v.vehicle_id, v.registration_number, v.brand, v.model;

-- ---------------------------------------------------------------------
-- REPORT 1 : Available vehicles
-- Logic    : status = 'Available'
-- Expected : 9 rows with the sample data
-- ---------------------------------------------------------------------
SELECT * FROM v_available_vehicles ORDER BY vehicle_type, daily_rate;

-- ---------------------------------------------------------------------
-- REPORT 2 : Customer rental history (bookings + agreements)
-- Expected : one row per booking; customers with no booking are omitted
-- ---------------------------------------------------------------------
SELECT c.customer_id, c.full_name,
       b.booking_id, v.registration_number,
       b.start_date, b.end_date, b.booking_status,
       a.total_amount
FROM customers c
JOIN rental_bookings b        ON b.customer_id = c.customer_id
JOIN vehicles v               ON v.vehicle_id = b.vehicle_id
LEFT JOIN rental_agreements a ON a.booking_id = b.booking_id
ORDER BY c.customer_id, b.start_date;

-- ---------------------------------------------------------------------
-- REPORT 3 : Overdue rentals (no return record and end_date < today)
-- Expected : 1 row (Priya Sharma, TS09CD2002, 2 days overdue)
-- ---------------------------------------------------------------------
SELECT c.full_name, v.registration_number, b.end_date,
       DATEDIFF(CURDATE(), b.end_date) AS days_overdue
FROM rental_bookings b
JOIN customers c          ON b.customer_id = c.customer_id
JOIN vehicles v           ON b.vehicle_id   = v.vehicle_id
JOIN rental_agreements a ON a.booking_id    = b.booking_id
LEFT JOIN vehicle_returns r ON r.agreement_id = a.agreement_id
WHERE r.return_id IS NULL
  AND b.end_date < CURDATE();

-- ---------------------------------------------------------------------
-- REPORT 4 : Vehicle-wise income (SUM of payments by vehicle)
-- ---------------------------------------------------------------------
SELECT * FROM v_vehicle_income ORDER BY total_income DESC;

-- ---------------------------------------------------------------------
-- REPORT 5 : Monthly revenue (SUM of payments by month)
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(payment_date, '%Y-%m') AS revenue_month,
       COUNT(*)                           AS payments_received,
       SUM(amount)                        AS revenue
FROM payments
GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
ORDER BY revenue_month;
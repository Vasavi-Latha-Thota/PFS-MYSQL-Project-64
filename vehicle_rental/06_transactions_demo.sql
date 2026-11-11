-- ---------------------------------------------------------------------
-- 1. TRANSACTION with COMMIT : book vehicle 2 for customer 4
-- ---------------------------------------------------------------------
SELECT vehicle_id, status FROM vehicles WHERE vehicle_id = 2;   -- Available

START TRANSACTION;
  INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date, booking_status)
  VALUES (4, 2, CURDATE() + INTERVAL 1 DAY, CURDATE() + INTERVAL 3 DAY, 'Active');
  UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = 2;
COMMIT;

SELECT vehicle_id, status FROM vehicles WHERE vehicle_id = 2;   -- Rented (kept)

-- ---------------------------------------------------------------------
-- 2. TRANSACTION with ROLLBACK : booking is undone
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS bookings_before FROM rental_bookings;

START TRANSACTION;
  INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date, booking_status)
  VALUES (5, 12, CURDATE() + INTERVAL 1 DAY, CURDATE() + INTERVAL 2 DAY, 'Active');
  UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = 12;
  SELECT COUNT(*) AS bookings_inside_transaction FROM rental_bookings;
ROLLBACK;

SELECT COUNT(*) AS bookings_after_rollback FROM rental_bookings;   -- same as before
SELECT vehicle_id, status FROM vehicles WHERE vehicle_id = 12;     -- still Available

-- ---------------------------------------------------------------------
-- 3. Stored procedures that only read data
-- ---------------------------------------------------------------------
CALL sp_customer_history(1);      -- Arjun Reddy : 2 rows
CALL sp_monthly_revenue(2026);    -- one row per month with payments

-- ---------------------------------------------------------------------
-- 4. Full workflow with procedures + trigger
--    (a) book a Sedan (vehicle 3) for 3 days that ended 2 days ago
--    (b) return it today with a dent and an empty tank
-- ---------------------------------------------------------------------
CALL sp_book_vehicle(8, 3, CURDATE() - INTERVAL 4 DAY, CURDATE() - INTERVAL 2 DAY,
                     3000.00, 'Card', @booking_id, @agreement_id);
SELECT @booking_id AS new_booking, @agreement_id AS new_agreement;
SELECT vehicle_id, status FROM vehicles WHERE vehicle_id = 3;        -- Rented

-- 2 days late x 300 = 600, + damage 500 + fuel 250 = 1350
CALL sp_return_vehicle(@agreement_id, CURDATE(), 'Minor Damage',
                       500.00, 250.00, 'Card', @total_penalty);
SELECT @total_penalty AS total_penalty;                              -- 1350.00

-- Trigger effect : vehicle Available again, booking Completed
SELECT vehicle_id, status FROM vehicles WHERE vehicle_id = 3;        -- Available
SELECT booking_id, booking_status FROM rental_bookings WHERE booking_id = @booking_id;
SELECT penalty_type, amount FROM penalties
WHERE return_id = (SELECT return_id FROM vehicle_returns WHERE agreement_id = @agreement_id);
SELECT payment_type, amount FROM payments WHERE agreement_id = @agreement_id; -- Advance 3300, Final 4650

-- ---------------------------------------------------------------------
-- 5. Business rule : a vehicle that is not Available cannot be booked
--    (this CALL is expected to fail with "Vehicle is not available")
-- ---------------------------------------------------------------------
-- CALL sp_book_vehicle(1, 4, CURDATE(), CURDATE() + INTERVAL 1 DAY,
--                      1000, 'Cash', @b, @a);

-- ---------------------------------------------------------------------
-- 6. INDEX and EXPLAIN on a large copy of the bookings table
--    (the real tables are too small for the optimizer to care)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS bookings_big;
CREATE TABLE bookings_big (
  booking_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  start_date DATE NOT NULL,
  end_date    DATE NOT NULL
) ENGINE=InnoDB;

INSERT INTO bookings_big (customer_id, vehicle_id, start_date, end_date)
SELECT (n.i MOD 500) + 1, (n.i MOD 12) + 1,
       '2026-01-01' + INTERVAL (n.i MOD 300) DAY,
       '2026-01-03' + INTERVAL (n.i MOD 300) DAY
FROM (SELECT a.d + b.d*10 + c.d*100 + e.d*1000 + f.d*10000 AS i
      FROM (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
           (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
           (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c,
           (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) e,
           (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) f) n;

ANALYZE TABLE bookings_big;
SELECT COUNT(*) AS rows_in_bookings_big FROM bookings_big;     -- 100000

-- BEFORE the index : full table scan (type = ALL, rows ~ 100000)
EXPLAIN SELECT * FROM bookings_big WHERE customer_id = 7;

CREATE INDEX idx_big_customer ON bookings_big (customer_id);
ANALYZE TABLE bookings_big;

-- AFTER the index : index lookup (type = ref, rows ~ 200)
EXPLAIN SELECT * FROM bookings_big WHERE customer_id = 7;

DROP TABLE bookings_big;

-- ---------------------------------------------------------------------
-- 7. CLEAN-UP : restore the original sample data
--    (deletes in child -> parent order because of the foreign keys)
-- ---------------------------------------------------------------------
DELETE FROM penalties WHERE return_id > 11;
DELETE FROM payments   WHERE payment_id > 24;
DELETE FROM vehicle_returns WHERE return_id > 11;
DELETE FROM rental_agreements WHERE agreement_id > 13;
DELETE FROM rental_bookings   WHERE booking_id > 15;
UPDATE vehicles SET status = 'Available' WHERE vehicle_id IN (2, 3, 12);
SELECT (SELECT COUNT(*) FROM rental_bookings)   AS bookings,    -- 15
       (SELECT COUNT(*) FROM payments)          AS payments,    -- 24
       (SELECT COUNT(*) FROM vehicle_returns)   AS returns_cnt, -- 11
       (SELECT COUNT(*) FROM v_available_vehicles) AS available_vehicles;   -- 9
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP TEMPORARY TABLE IF EXISTS test_results;
CREATE TEMPORARY TABLE test_results (
   seq         INT AUTO_INCREMENT PRIMARY KEY,
   test_id     VARCHAR(10),
   module      VARCHAR(20),
   description VARCHAR(160),
   expected    VARCHAR(100),
   actual      VARCHAR(100),
   result      VARCHAR(4),
   detail      VARCHAR(160)
);

DELIMITER $$

-- Compare an expected value with an actual value ----------------------
DROP PROCEDURE IF EXISTS t_assert$$
CREATE PROCEDURE t_assert(IN p_id VARCHAR(10), IN p_module VARCHAR(20),
                          IN p_desc VARCHAR(160), IN p_expected VARCHAR(100),
                          IN p_actual VARCHAR(100))
BEGIN
  INSERT INTO test_results (test_id, module, description, expected, actual, result)
  VALUES (p_id, p_module, p_desc, p_expected, COALESCE(p_actual, 'NULL'),
          IF(p_expected <=> COALESCE(p_actual, 'NULL'), 'PASS', 'FAIL'));
END$$

-- The statement MUST raise an error (optionally containing some text) -
DROP PROCEDURE IF EXISTS t_expect_error$$
CREATE PROCEDURE t_expect_error(IN p_id VARCHAR(10), IN p_module VARCHAR(20),
                                 IN p_desc VARCHAR(160), IN p_sql TEXT,
                                 IN p_msg_like VARCHAR(100))
BEGIN
  DECLARE v_err INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    SET v_err = 1;
  END;
  SET @t_sql = p_sql;
  PREPARE t_stmt FROM @t_sql;
  EXECUTE t_stmt;
  DEALLOCATE PREPARE t_stmt;
  INSERT INTO test_results (test_id, module, description, expected, actual, result, detail)
  VALUES (p_id, p_module, p_desc, 'Rejected with error',
          IF(v_err = 1, 'Rejected with error', 'Accepted (no error)'),
          IF(v_err = 1 AND (p_msg_like = '' OR v_msg LIKE CONCAT('%', p_msg_like, '%')),
             'PASS', 'FAIL'),
          LEFT(v_msg, 160));
END$$

DELIMITER ;

-- =====================================================================
-- MODULE 1 : STRUCTURE
-- =====================================================================
SET @a = (SELECT COUNT(*) FROM information_schema.tables
          WHERE table_schema = 'vehicle_rental_db' AND table_type = 'BASE TABLE');
CALL t_assert('TC-01', 'Structure', 'Database has 10 tables', '10', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.views
          WHERE table_schema = 'vehicle_rental_db'
            AND table_name IN ('v_available_vehicles', 'v_vehicle_income'));
CALL t_assert('TC-02', 'Structure', 'Both views exist', '2', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.triggers
          WHERE trigger_schema = 'vehicle_rental_db'
            AND trigger_name = 'trg_return_vehicle_available');
CALL t_assert('TC-03', 'Structure', 'Trigger trg_return_vehicle_available exists', '1', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.routines
          WHERE routine_schema = 'vehicle_rental_db' AND routine_name LIKE 'sp\_%');
CALL t_assert('TC-04', 'Structure', 'Four stored procedures exist (sp_*)', '4', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.statistics
          WHERE table_schema = 'vehicle_rental_db' AND index_name = 'idx_booking_customer');
CALL t_assert('TC-05', 'Structure', 'Index idx_booking_customer exists', '1', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.tables t
          WHERE t.table_schema = 'vehicle_rental_db' AND t.table_type = 'BASE TABLE'
            AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints c
                            WHERE c.table_schema = t.table_schema
                              AND c.table_name = t.table_name
                              AND c.constraint_type = 'PRIMARY KEY'));
CALL t_assert('TC-06', 'Structure', 'Every table has a PRIMARY KEY (tables without one)', '0', @a);

SET @a = (SELECT COUNT(*) FROM information_schema.table_constraints
          WHERE constraint_schema = 'vehicle_rental_db' AND constraint_type = 'FOREIGN KEY');
CALL t_assert('TC-07', 'Structure', 'Ten FOREIGN KEY constraints are defined', '10', @a);

-- =====================================================================
-- MODULE 2 : CONSTRAINTS (every one of these must be rejected)
-- =====================================================================
CALL t_expect_error('TC-10', 'Constraints', 'Duplicate customer phone is rejected',
  "INSERT INTO customers (full_name, phone, email, license_number, city) VALUES ('Dup Phone','9000000001','dup1@example.com','LIC-DUP-1','Hyderabad')",
  'Duplicate');
CALL t_expect_error('TC-11', 'Constraints', 'Duplicate customer email is rejected',
  "INSERT INTO customers (full_name, phone, email, license_number, city) VALUES ('Dup Email','9000000091','arjun.reddy@example.com','LIC-DUP-2','Hyderabad')",
  'Duplicate');
CALL t_expect_error('TC-12', 'Constraints', 'Duplicate driving licence number is rejected',
  "INSERT INTO customers (full_name, phone, email, license_number, city) VALUES ('Dup Licence','9000000092','dup3@example.com','TS09-2015-0001','Hyderabad')",
  'Duplicate');
CALL t_expect_error('TC-13', 'Constraints', 'Duplicate vehicle registration number is rejected',
  "INSERT INTO vehicles (registration_number, brand, model, `year`, category_id, owner_id) VALUES ('TS09AB1001','X','Y',2024,1,1)",
  'Duplicate');
CALL t_expect_error('TC-14', 'Constraints', 'Booking with end_date before start_date is rejected (CHECK)',
  "INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date) VALUES (1, 1, '2027-02-10', '2027-02-05')",
  '');
CALL t_expect_error('TC-15', 'Constraints', 'Category with daily_rate = 0 is rejected (CHECK)',
  "INSERT INTO vehicle_categories (category_name, vehicle_type, daily_rate, late_fee_per_day) VALUES ('Free Ride','Car',0,0)",
  '');
CALL t_expect_error('TC-16', 'Constraints', 'Payment with amount = 0 is rejected (CHECK)',
  "INSERT INTO payments (agreement_id, amount, payment_mode, payment_type) VALUES (1, 0, 'Cash', 'Advance')",
  '');
CALL t_expect_error('TC-17', 'Constraints', 'Maintenance with negative cost is rejected (CHECK)',
  "INSERT INTO maintenance_records (vehicle_id, maintenance_date, description, cost) VALUES (1, '2026-05-01', 'Bad cost', -10)",
  '');
CALL t_expect_error('TC-18', 'Constraints', 'Booking for a non-existent customer is rejected (FK)',
  "INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date) VALUES (9999, 1, '2027-02-01', '2027-02-02')",
  'foreign key');
CALL t_expect_error('TC-19', 'Constraints', 'Booking for a non-existent vehicle is rejected (FK)',
  "INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date) VALUES (1, 9999, '2027-02-01', '2027-02-02')",
  'foreign key');
CALL t_expect_error('TC-20', 'Constraints', 'Second agreement for the same booking is rejected (UNIQUE)',
  "INSERT INTO rental_agreements (booking_id, agreed_daily_rate, security_deposit, total_amount) VALUES (1, 1500, 0, 1500)",
  'Duplicate');
CALL t_expect_error('TC-21', 'Constraints', 'Second return for the same agreement is rejected (UNIQUE)',
  "INSERT INTO vehicle_returns (agreement_id, return_date) VALUES (1, '2026-01-09')",
  'Duplicate');
CALL t_expect_error('TC-22', 'Constraints', 'Invalid vehicle status value is rejected (ENUM)',
  "INSERT INTO vehicles (registration_number, brand, model, `year`, category_id, owner_id, status) VALUES ('TEST-ENUM','X','Y',2024,1,1,'Broken')",
  '');
CALL t_expect_error('TC-23', 'Constraints', 'Deleting a customer who has bookings is rejected (FK RESTRICT)',
  "DELETE FROM customers WHERE customer_id = 1",
  'foreign key');
CALL t_expect_error('TC-24', 'Constraints', 'Customer with NULL full_name is rejected (NOT NULL)',
  "INSERT INTO customers (full_name, phone, email, license_number, city) VALUES (NULL,'9000000093','nn@example.com','LIC-NN-1','Hyderabad')",
  '');
CALL t_expect_error('TC-25', 'Constraints', 'Deleting a category that has vehicles is rejected (FK RESTRICT)',
  "DELETE FROM vehicle_categories WHERE category_id = 1",
  'foreign key');
CALL t_expect_error('TC-26', 'Constraints', 'Penalty with negative amount is rejected (CHECK)',
  "INSERT INTO penalties (return_id, penalty_type, amount) VALUES (1, 'Fuel', -50)",
  '');
CALL t_expect_error('TC-27', 'Constraints', 'Return with negative days_late is rejected (CHECK)',
  "INSERT INTO vehicle_returns (agreement_id, return_date, days_late) VALUES (12, CURDATE(), -1)",
  '');

-- =====================================================================
-- MODULE 3 : DEFAULTS and ON DELETE behaviour
-- =====================================================================
INSERT INTO vehicles (registration_number, brand, model, `year`, category_id, owner_id)
VALUES ('TEST-DEF-01', 'Test', 'Default', 2024, 1, 1);
SET @a = (SELECT status FROM vehicles WHERE registration_number = 'TEST-DEF-01');
CALL t_assert('TC-30', 'Defaults', 'New vehicle gets status = Available by default', 'Available', @a);
DELETE FROM vehicles WHERE registration_number = 'TEST-DEF-01';

INSERT INTO customers (full_name, phone, email, license_number, city)
VALUES ('Default Date', '9000000094', 'default.date@example.com', 'LIC-DEF-1', 'Hyderabad');
SET @a = (SELECT registered_date = CURDATE() FROM customers WHERE phone = '9000000094');
CALL t_assert('TC-31', 'Defaults', 'New customer gets registered_date = today by default', '1', @a);

SET @a = (SELECT column_default FROM information_schema.columns
          WHERE table_schema = 'vehicle_rental_db' AND table_name = 'vehicle_returns'
            AND column_name = 'days_late');
CALL t_assert('TC-32', 'Defaults', 'vehicle_returns.days_late defaults to 0', '0', @a);

-- self-reference: deleting the referrer must only blank referred_by
INSERT INTO customers (full_name, phone, email, license_number, city, referred_by)
VALUES ('Referred Person', '9000000095', 'referred.person@example.com', 'LIC-REF-1', 'Hyderabad',
        (SELECT customer_id FROM (SELECT customer_id FROM customers WHERE phone = '9000000094') x));
DELETE FROM customers WHERE phone = '9000000094';
SET @a = (SELECT referred_by FROM customers WHERE phone = '9000000095');
CALL t_assert('TC-33', 'Defaults', 'Deleting a referrer sets referred_by to NULL (ON DELETE SET NULL)', 'NULL', @a);
DELETE FROM customers WHERE phone = '9000000095';

-- =====================================================================
-- MODULE 4 : QUERIES, VIEWS AND REPORTS (against the sample data)
-- =====================================================================
SET @a = (SELECT COUNT(*) FROM v_available_vehicles);
CALL t_assert('TC-40', 'Reports', 'Available-vehicles view returns 9 vehicles', '9', @a);

SET @a = (SELECT MIN(c.daily_rate) FROM vehicles v JOIN vehicle_categories c ON v.category_id = c.category_id
          WHERE v.status = 'Available' AND c.vehicle_type = 'Car');
CALL t_assert('TC-41', 'Reports', 'Cheapest available car costs 1500.00 per day', '1500.00', @a);

SET @a = (SELECT DATEDIFF(end_date, start_date) + 1 FROM rental_bookings WHERE booking_id = 1);
CALL t_assert('TC-42', 'Reports', 'Booking 1 (5 Jan - 8 Jan) is 4 rental days', '4', @a);

SET @a = (SELECT COUNT(*) FROM (SELECT city FROM customers GROUP BY city HAVING COUNT(*) > 2) t);
CALL t_assert('TC-43', 'Reports', 'Two cities have more than 2 customers', '2', @a);

SET @a = (SELECT COUNT(*) FROM vehicles WHERE vehicle_id NOT IN (SELECT vehicle_id FROM rental_bookings));
CALL t_assert('TC-44', 'Reports', 'Three vehicles have never been booked', '3', @a);

SET @a = (SELECT MAX(daily_rate) FROM vehicle_categories
          WHERE daily_rate < (SELECT MAX(daily_rate) FROM vehicle_categories));
CALL t_assert('TC-45', 'Reports', 'Second-highest daily rate is 4500.00', '4500.00', @a);

SET @a = (SELECT r.full_name FROM customers c LEFT JOIN customers r ON c.referred_by = r.customer_id
          WHERE c.full_name = 'Priya Sharma');
CALL t_assert('TC-46', 'Reports', 'SELF JOIN: Priya Sharma was referred by Arjun Reddy', 'Arjun Reddy', @a);

SET @a = (SELECT c.category_name FROM vehicles v RIGHT JOIN vehicle_categories c ON v.category_id = c.category_id
          WHERE v.vehicle_id IS NULL);
CALL t_assert('TC-47', 'Reports', 'RIGHT JOIN: the category without vehicles is Mini Van', 'Mini Van', @a);

SET @a = (SELECT COUNT(*) FROM rental_bookings b
          JOIN rental_agreements a ON a.booking_id = b.booking_id
          LEFT JOIN vehicle_returns r ON r.agreement_id = a.agreement_id
          WHERE r.return_id IS NULL AND b.end_date < CURDATE());
CALL t_assert('TC-48', 'Reports', 'Overdue report lists exactly 1 rental', '1', @a);

SET @a = (SELECT DATEDIFF(CURDATE(), b.end_date) FROM rental_bookings b
          JOIN vehicles v ON v.vehicle_id = b.vehicle_id
          JOIN rental_agreements a ON a.booking_id = b.booking_id
          LEFT JOIN vehicle_returns r ON r.agreement_id = a.agreement_id
          WHERE r.return_id IS NULL AND b.end_date < CURDATE() AND v.registration_number = 'TS09CD2002');
CALL t_assert('TC-49', 'Reports', 'The overdue vehicle TS09CD2002 is 2 days overdue', '2', @a);

SET @a = (SELECT total_income FROM v_vehicle_income WHERE vehicle_id = 3);
CALL t_assert('TC-50', 'Reports', 'Vehicle-wise income for vehicle 3 (Honda City) = 20400.00', '20400.00', @a);

SET @a = (SELECT total_income FROM v_vehicle_income WHERE vehicle_id = 7);
CALL t_assert('TC-51', 'Reports', 'Vehicle that was never rented earns 0.00', '0.00', @a);

SET @a = (SELECT SUM(amount) FROM payments WHERE DATE_FORMAT(payment_date, '%Y-%m') = '2026-01');
CALL t_assert('TC-52', 'Reports', 'Monthly revenue for 2026-01 = 14700.00', '14700.00', @a);

SET @a = (SELECT SUM(amount) FROM payments);
CALL t_assert('TC-53', 'Reports', 'Total of all payments = 108330.00', '108330.00', @a);

SET @a = (SELECT COUNT(*) FROM penalties p
          JOIN vehicle_returns r    ON r.return_id = p.return_id
          JOIN rental_agreements a ON a.agreement_id = r.agreement_id
          JOIN rental_bookings b    ON b.booking_id = a.booking_id
          JOIN vehicles v           ON v.vehicle_id = b.vehicle_id
          JOIN vehicle_categories c ON c.category_id = v.category_id
          WHERE p.penalty_type = 'Late Return' AND p.amount <> r.days_late * c.late_fee_per_day);
CALL t_assert('TC-54', 'Penalty', 'Late-return penalty = days_late x late_fee_per_day (mismatches)', '0', @a);

SET @a = (SELECT SUM(amount) FROM penalties WHERE return_id = 2);
CALL t_assert('TC-55', 'Penalty', 'Return 2 total penalty = 600 late + 1500 damage = 2100.00', '2100.00', @a);

SET @a = (SELECT COUNT(*) FROM rental_agreements a
           JOIN vehicle_returns r ON r.agreement_id = a.agreement_id
           WHERE (SELECT SUM(amount) FROM payments WHERE agreement_id = a.agreement_id)
              <> a.total_amount + COALESCE((SELECT SUM(amount) FROM penalties WHERE return_id = r.return_id), 0));
CALL t_assert('TC-56', 'Integrity', 'Returned agreements: payments = total + penalties (mismatches)', '0', @a);

SET @a = (SELECT COUNT(*) FROM vehicle_returns r
          JOIN rental_agreements a ON a.agreement_id = r.agreement_id
          JOIN rental_bookings b   ON b.booking_id = a.booking_id
          WHERE r.days_late <> GREATEST(DATEDIFF(r.return_date, b.end_date), 0));
CALL t_assert('TC-57', 'Integrity', 'days_late matches return_date vs end_date (mismatches)', '0', @a);

SET @a = (SELECT COUNT(*) FROM vehicles WHERE status = 'Rented');
SET @b = (SELECT COUNT(*) FROM rental_bookings b
          JOIN rental_agreements a ON a.booking_id = b.booking_id
          LEFT JOIN vehicle_returns r ON r.agreement_id = a.agreement_id
          WHERE r.return_id IS NULL AND b.booking_status = 'Active');
CALL t_assert('TC-58', 'Integrity', 'Number of Rented vehicles = number of open Active rentals', @b, @a);

SET @a = (SELECT COUNT(*) FROM rental_agreements a
          JOIN rental_bookings b ON b.booking_id = a.booking_id
          WHERE a.total_amount <> a.agreed_daily_rate * (DATEDIFF(b.end_date, b.start_date) + 1));
CALL t_assert('TC-59', 'Integrity', 'Agreement total = daily rate x rental days (mismatches)', '0', @a);

-- =====================================================================
-- MODULE 5 : PROCEDURES, TRIGGER AND TRANSACTIONS
-- =====================================================================

-- ---- sp_book_vehicle : success -------------------------------------
CALL sp_book_vehicle(4, 2, CURDATE() - INTERVAL 2 DAY, CURDATE(), 2000.00, 'UPI', @bk1, @ag1);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 2);
CALL t_assert('TC-60', 'Procedures', 'sp_book_vehicle sets the vehicle to Rented', 'Rented', @a);
SET @a = (SELECT total_amount FROM rental_agreements WHERE agreement_id = @ag1);
CALL t_assert('TC-61', 'Procedures', 'sp_book_vehicle agreement total = 1500 x 3 days = 4500.00', '4500.00', @a);
SET @a = (SELECT amount FROM payments WHERE agreement_id = @ag1 AND payment_type = 'Advance');
CALL t_assert('TC-62', 'Procedures', 'sp_book_vehicle records a 50% advance payment (2250.00)', '2250.00', @a);
SET @a = (SELECT booking_status FROM rental_bookings WHERE booking_id = @bk1);
CALL t_assert('TC-63', 'Procedures', 'sp_book_vehicle creates the booking with status Active', 'Active', @a);

-- ---- sp_book_vehicle : business-rule failures ----------------------
SET @c0 = (SELECT COUNT(*) FROM rental_bookings);
SET @p0 = (SELECT COUNT(*) FROM payments);
CALL t_expect_error('TC-64', 'Procedures', 'Booking a Rented vehicle is rejected',
  "CALL sp_book_vehicle(1, 4, CURDATE(), CURDATE() + INTERVAL 1 DAY, 1000, 'Cash', @x1, @x2)",
  'not available');
CALL t_expect_error('TC-65', 'Procedures', 'Booking a vehicle under Maintenance is rejected',
  "CALL sp_book_vehicle(1, 9, CURDATE(), CURDATE() + INTERVAL 1 DAY, 1000, 'Cash', @x1, @x2)",
  'not available');
CALL t_expect_error('TC-66', 'Procedures', 'Booking with end date before start date is rejected',
  "CALL sp_book_vehicle(1, 7, CURDATE() + INTERVAL 5 DAY, CURDATE() + INTERVAL 2 DAY, 1000, 'Cash', @x1, @x2)",
  'End date');
CALL t_expect_error('TC-67', 'Procedures', 'Booking for a non-existent customer is rejected',
  "CALL sp_book_vehicle(9999, 7, CURDATE(), CURDATE() + INTERVAL 1 DAY, 1000, 'Cash', @x1, @x2)",
  'Customer does not exist');
CALL t_expect_error('TC-68', 'Procedures', 'Booking a non-existent vehicle is rejected',
  "CALL sp_book_vehicle(1, 9999, CURDATE(), CURDATE() + INTERVAL 1 DAY, 1000, 'Cash', @x1, @x2)",
  'Vehicle does not exist');
CALL t_expect_error('TC-69', 'Procedures', 'Invalid payment mode rolls the whole booking back',
  "CALL sp_book_vehicle(1, 7, CURDATE(), CURDATE() + INTERVAL 1 DAY, 1000, 'Cheque', @x1, @x2)",
  '');
SET @a = (SELECT COUNT(*) FROM rental_bookings) - @c0;
CALL t_assert('TC-70', 'Procedures', 'Rejected bookings leave no new booking rows', '0', @a);
SET @a = (SELECT COUNT(*) FROM payments) - @p0;
CALL t_assert('TC-71', 'Procedures', 'Rejected bookings leave no new payment rows', '0', @a);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 7);
CALL t_assert('TC-72', 'Procedures', 'Vehicle 7 is still Available after the failed bookings', 'Available', @a);

-- ---- sp_return_vehicle : on time -----------------------------------
CALL sp_return_vehicle(@ag1, CURDATE(), 'Good', 0, 0, 'UPI', @pen1);
SET @a = @pen1;
CALL t_assert('TC-73', 'Procedures', 'On-time return has total penalty 0.00', '0.00', @a);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 2);
CALL t_assert('TC-74', 'Trigger', 'Trigger sets the vehicle back to Available after a return', 'Available', @a);
SET @a = (SELECT booking_status FROM rental_bookings WHERE booking_id = @bk1);
CALL t_assert('TC-75', 'Trigger', 'Trigger marks the booking Completed after a return', 'Completed', @a);
SET @a = (SELECT amount FROM payments WHERE agreement_id = @ag1 AND payment_type = 'Final');
CALL t_assert('TC-76', 'Procedures', 'Final payment on an on-time return = unpaid balance 2250.00', '2250.00', @a);
SET @a = (SELECT COUNT(*) FROM penalties p JOIN vehicle_returns r ON r.return_id = p.return_id
           WHERE r.agreement_id = @ag1);
CALL t_assert('TC-77', 'Procedures', 'On-time return creates no penalty rows', '0', @a);

-- ---- sp_return_vehicle : late + damage + fuel ----------------------
CALL sp_book_vehicle(8, 3, CURDATE() - INTERVAL 4 DAY, CURDATE() - INTERVAL 2 DAY, 3000.00, 'Card', @bk2, @ag2);
CALL sp_return_vehicle(@ag2, CURDATE(), 'Minor Damage', 500.00, 250.00, 'Card', @pen2);
SET @a = (SELECT days_late FROM vehicle_returns WHERE agreement_id = @ag2);
CALL t_assert('TC-78', 'Penalty', 'Returned 2 days after end date: days_late = 2', '2', @a);
SET @a = (SELECT amount FROM penalties p JOIN vehicle_returns r ON r.return_id = p.return_id
          WHERE r.agreement_id = @ag2 AND p.penalty_type = 'Late Return');
CALL t_assert('TC-79', 'Penalty', 'Late penalty = 2 days x 300 = 600.00', '600.00', @a);
CALL t_assert('TC-80', 'Penalty', 'Total penalty = 600 late + 500 damage + 250 fuel = 1350.00', '1350.00', @pen2);
SET @a = (SELECT COUNT(*) FROM penalties p JOIN vehicle_returns r ON r.return_id = p.return_id
          WHERE r.agreement_id = @ag2);
CALL t_assert('TC-81', 'Penalty', 'Three penalty rows created (Late, Damage, Fuel)', '3', @a);
SET @a = (SELECT amount FROM payments WHERE agreement_id = @ag2 AND payment_type = 'Final');
CALL t_assert('TC-82', 'Penalty', 'Final payment = balance 3300 + penalties 1350 = 4650.00', '4650.00', @a);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 3);
CALL t_assert('TC-83', 'Trigger', 'Vehicle 3 is Available again after the late return', 'Available', @a);

-- ---- sp_return_vehicle : failures ----------------------------------
CALL t_expect_error('TC-84', 'Procedures', 'Returning the same agreement twice is rejected',
  CONCAT('CALL sp_return_vehicle(', @ag2, ', CURDATE(), ''Good'', 0, 0, ''Cash'', @x1)'),
  'already returned');
CALL t_expect_error('TC-85', 'Procedures', 'Returning a non-existent agreement is rejected',
  "CALL sp_return_vehicle(9999, CURDATE(), 'Good', 0, 0, 'Cash', @x1)",
  'Agreement does not exist');
CALL t_expect_error('TC-86', 'Procedures', 'Return date before the rental start date is rejected',
  "CALL sp_return_vehicle(12, CURDATE() - INTERVAL 30 DAY, 'Good', 0, 0, 'Cash', @x1)",
  'before the start date');

-- ---- Trigger tested directly (not through the procedure) -----------
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 4);
CALL t_assert('TC-87', 'Trigger', 'Before the return, vehicle 4 is Rented', 'Rented', @a);
INSERT INTO vehicle_returns (agreement_id, return_date, vehicle_condition, days_late)
VALUES (12, CURDATE(), 'Good', 2);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 4);
CALL t_assert('TC-88', 'Trigger', 'Direct INSERT into vehicle_returns makes vehicle 4 Available', 'Available', @a);
-- restore vehicle 4 and booking 13 to their original state
DELETE FROM vehicle_returns WHERE agreement_id = 12;
UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = 4;
UPDATE rental_bookings SET booking_status = 'Active' WHERE booking_id = 13;

-- ---- Transactions --------------------------------------------------
SET @c0 = (SELECT COUNT(*) FROM rental_bookings);
START TRANSACTION;
  INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date, booking_status)
  VALUES (5, 12, CURDATE(), CURDATE() + INTERVAL 1 DAY, 'Active');
  UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = 12;
ROLLBACK;
SET @a = (SELECT COUNT(*) FROM rental_bookings) - @c0;
CALL t_assert('TC-89', 'Transaction', 'ROLLBACK undoes the inserted booking', '0', @a);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 12);
CALL t_assert('TC-90', 'Transaction', 'ROLLBACK undoes the status change (vehicle 12 Available)', 'Available', @a);

START TRANSACTION;
  INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date, booking_status)
  VALUES (5, 12, CURDATE(), CURDATE() + INTERVAL 1 DAY, 'Active');
  UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = 12;
COMMIT;
SET @a = (SELECT COUNT(*) FROM rental_bookings) - @c0;
CALL t_assert('TC-91', 'Transaction', 'COMMIT keeps the inserted booking', '1', @a);
SET @a = (SELECT status FROM vehicles WHERE vehicle_id = 12);
CALL t_assert('TC-92', 'Transaction', 'COMMIT keeps the status change (vehicle 12 Rented)', 'Rented', @a);
-- clean up the committed demo booking
DELETE FROM rental_bookings WHERE customer_id = 5 AND vehicle_id = 12;
UPDATE vehicles SET status = 'Available' WHERE vehicle_id = 12;

-- ---- Restore the original sample data (remove rows made by the tests)
DELETE FROM penalties         WHERE return_id    > 11;
DELETE FROM payments          WHERE payment_id   > 24;
DELETE FROM vehicle_returns   WHERE return_id    > 11;
DELETE FROM rental_agreements WHERE agreement_id > 13;
DELETE FROM rental_bookings   WHERE booking_id   > 15;
UPDATE vehicles SET status = 'Available' WHERE vehicle_id IN (2, 3, 12);

SET @a = (SELECT COUNT(*) FROM v_available_vehicles);
CALL t_assert('TC-93', 'Integrity', 'After clean-up the Available count is back to 9', '9', @a);
SET @a = (SELECT CONCAT((SELECT COUNT(*) FROM rental_bookings), '/',
                        (SELECT COUNT(*) FROM rental_agreements), '/',
                        (SELECT COUNT(*) FROM payments), '/',
                        (SELECT COUNT(*) FROM vehicle_returns), '/',
                        (SELECT COUNT(*) FROM penalties)));
CALL t_assert('TC-94', 'Integrity', 'Row counts restored (bookings/agreements/payments/returns/penalties)', '15/13/24/11/7', @a);

-- =====================================================================
-- RESULTS
-- =====================================================================
SELECT test_id, module, description, expected, actual, result FROM test_results ORDER BY seq;

SELECT COUNT(*) AS total_tests,
       SUM(result = 'PASS') AS passed,
       SUM(result = 'FAIL') AS failed
FROM test_results;

-- Manual / visual checks (stored procedures that return result sets):
--   CALL sp_customer_history(1);   -- expect 2 rows (Arjun Reddy, bookings 1 and 6)
--   CALL sp_monthly_revenue(2026); -- expect Jan 14700, Feb 19930, Mar 5850 ...

DROP PROCEDURE IF EXISTS t_assert;
DROP PROCEDURE IF EXISTS t_expect_error;
DROP TEMPORARY TABLE IF EXISTS test_results;
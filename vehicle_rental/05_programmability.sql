CREATE INDEX idx_booking_customer ON rental_bookings (customer_id);

DELIMITER $$

-- TRIGGER : when a return is recorded the vehicle becomes Available
--            again and the booking is marked Completed.
DROP TRIGGER IF EXISTS trg_return_vehicle_available$$
CREATE TRIGGER trg_return_vehicle_available
AFTER INSERT ON vehicle_returns
FOR EACH ROW
BEGIN
   UPDATE vehicles v
   JOIN rental_bookings b   ON b.vehicle_id = v.vehicle_id
   JOIN rental_agreements a ON a.booking_id = b.booking_id
   SET v.status = 'Available'
   WHERE a.agreement_id = NEW.agreement_id;

  UPDATE rental_bookings b
  JOIN rental_agreements a ON a.booking_id = b.booking_id
  SET b.booking_status = 'Completed'
  WHERE a.agreement_id = NEW.agreement_id;
END$$

-- PROCEDURE : full rental history of one customer ---------------------
DROP PROCEDURE IF EXISTS sp_customer_history$$
CREATE PROCEDURE sp_customer_history(IN p_customer_id INT)
BEGIN
  SELECT c.full_name, b.booking_id, v.registration_number,
         v.brand, v.model, b.start_date, b.end_date, b.booking_status,
         a.total_amount,
         COALESCE((SELECT SUM(p.amount) FROM payments p
                   WHERE p.agreement_id = a.agreement_id), 0) AS amount_paid
  FROM customers c
  JOIN rental_bookings b        ON b.customer_id = c.customer_id
  JOIN vehicles v               ON v.vehicle_id = b.vehicle_id
  LEFT JOIN rental_agreements a ON a.booking_id = b.booking_id
  WHERE c.customer_id = p_customer_id
  ORDER BY b.start_date;
END$$

-- PROCEDURE : revenue per month for a year ----------------------------
DROP PROCEDURE IF EXISTS sp_monthly_revenue$$
CREATE PROCEDURE sp_monthly_revenue(IN p_year INT)
BEGIN
  SELECT DATE_FORMAT(payment_date, '%Y-%m') AS revenue_month,
         COUNT(*)    AS payments_received,
         SUM(amount) AS revenue
  FROM payments
  WHERE YEAR(payment_date) = p_year
  GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
  ORDER BY revenue_month;
END$$

-- PROCEDURE : booking workflow (steps 3-5 of "How the System Works")
--    * vehicle must be Available
--    * creates booking (Active), agreement, 50% advance payment
--    * sets vehicle status to Rented
--    * all-or-nothing: any error rolls everything back
DROP PROCEDURE IF EXISTS sp_book_vehicle$$
CREATE PROCEDURE sp_book_vehicle(
   IN p_customer_id       INT,
   IN p_vehicle_id        INT,
   IN p_start_date        DATE,
   IN p_end_date          DATE,
   IN p_security_deposit DECIMAL(10,2),
   IN p_payment_mode      VARCHAR(20),
  OUT p_booking_id       INT,
  OUT p_agreement_id     INT)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_rate   DECIMAL(10,2);
  DECLARE v_days   INT;
  DECLARE v_total DECIMAL(12,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_end_date < p_start_date THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date cannot be before start date';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer does not exist';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = p_vehicle_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not exist';
  END IF;

  SELECT v.status, c.daily_rate INTO v_status, v_rate
  FROM vehicles v JOIN vehicle_categories c ON c.category_id = v.category_id
  WHERE v.vehicle_id = p_vehicle_id
  FOR UPDATE;

  IF v_status <> 'Available' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not available for booking';
  END IF;

  SET v_days = DATEDIFF(p_end_date, p_start_date) + 1;
  SET v_total = v_days * v_rate;

  START TRANSACTION;
    INSERT INTO rental_bookings (customer_id, vehicle_id, start_date, end_date, booking_status)
    VALUES (p_customer_id, p_vehicle_id, p_start_date, p_end_date, 'Active');
    SET p_booking_id = LAST_INSERT_ID();

    INSERT INTO rental_agreements (booking_id, agreed_daily_rate, security_deposit, total_amount)
    VALUES (p_booking_id, v_rate, p_security_deposit, v_total);
    SET p_agreement_id = LAST_INSERT_ID();

    INSERT INTO payments (agreement_id, amount, payment_mode, payment_type, payment_date)
    VALUES (p_agreement_id, ROUND(v_total / 2, 2), p_payment_mode, 'Advance', CURDATE());

    UPDATE vehicles SET status = 'Rented' WHERE vehicle_id = p_vehicle_id;
  COMMIT;
END$$

-- PROCEDURE : return workflow (steps 6-8)
--    * days_late = days after end_date (never negative)
--    * penalties: days_late x late_fee_per_day, plus damage / fuel charges
--    * final payment = unpaid balance + all penalties
--    * vehicle is set back to Available by trg_return_vehicle_available
DROP PROCEDURE IF EXISTS sp_return_vehicle$$
CREATE PROCEDURE sp_return_vehicle(
   IN p_agreement_id INT,
   IN p_return_date    DATE,
   IN p_condition      VARCHAR(20),
   IN p_damage_charge DECIMAL(10,2),
   IN p_fuel_charge    DECIMAL(10,2),
   IN p_payment_mode VARCHAR(20),
   OUT p_total_penalty DECIMAL(12,2))
BEGIN
   DECLARE v_end_date DATE;
   DECLARE v_start     DATE;
   DECLARE v_total     DECIMAL(12,2);
   DECLARE v_late_fee DECIMAL(10,2);
   DECLARE v_days_late INT;
   DECLARE v_paid      DECIMAL(12,2);
   DECLARE v_return_id INT;
   DECLARE v_final     DECIMAL(12,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF NOT EXISTS (SELECT 1 FROM rental_agreements WHERE agreement_id = p_agreement_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agreement does not exist';
  END IF;

  SELECT b.start_date, b.end_date, a.total_amount, c.late_fee_per_day
    INTO v_start, v_end_date, v_total, v_late_fee
  FROM rental_agreements a
  JOIN rental_bookings b    ON b.booking_id = a.booking_id
  JOIN vehicles v           ON v.vehicle_id = b.vehicle_id
  JOIN vehicle_categories c ON c.category_id = v.category_id
  WHERE a.agreement_id = p_agreement_id;

  IF EXISTS (SELECT 1 FROM vehicle_returns WHERE agreement_id = p_agreement_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle already returned for this agreement';
  END IF;
  IF p_return_date < v_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return date cannot be before the start date';
  END IF;

  SET v_days_late = GREATEST(DATEDIFF(p_return_date, v_end_date), 0);

  START TRANSACTION;
    INSERT INTO vehicle_returns (agreement_id, return_date, vehicle_condition, days_late)
    VALUES (p_agreement_id, p_return_date, p_condition, v_days_late);
    SET v_return_id = LAST_INSERT_ID();

    IF v_days_late > 0 AND v_late_fee > 0 THEN
      INSERT INTO penalties (return_id, penalty_type, amount, remarks)
      VALUES (v_return_id, 'Late Return', v_days_late * v_late_fee,
              CONCAT(v_days_late, ' days x ', v_late_fee));
    END IF;
    IF p_damage_charge > 0 THEN
      INSERT INTO penalties (return_id, penalty_type, amount, remarks)
      VALUES (v_return_id, 'Damage', p_damage_charge, 'Damage charge');
    END IF;
    IF p_fuel_charge > 0 THEN
      INSERT INTO penalties (return_id, penalty_type, amount, remarks)
      VALUES (v_return_id, 'Fuel', p_fuel_charge, 'Fuel charge');
    END IF;

    SELECT COALESCE(SUM(amount), 0) INTO p_total_penalty
    FROM penalties WHERE return_id = v_return_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_paid
    FROM payments WHERE agreement_id = p_agreement_id;

    SET v_final = (v_total - v_paid) + p_total_penalty;
    IF v_final > 0 THEN
      INSERT INTO payments (agreement_id, amount, payment_mode, payment_type, payment_date)
      VALUES (p_agreement_id, v_final, p_payment_mode, 'Final', p_return_date);
    END IF;
  COMMIT;
END$$

DELIMITER ;
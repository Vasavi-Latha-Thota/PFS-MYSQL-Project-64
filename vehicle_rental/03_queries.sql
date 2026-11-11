USE vehicle_rental_db;

INSERT INTO vehicle_categories (category_id, category_name, vehicle_type, daily_rate, late_fee_per_day) VALUES
(1, 'Hatchback',    'Car', 1500.00, 200.00),
(2, 'Sedan',        'Car', 2200.00, 300.00),
(3, 'SUV',          'Car', 3500.00, 500.00),
(4, 'Luxury Sedan', 'Car', 6000.00, 800.00),
(5, 'Scooter',      'Bike', 500.00, 80.00),
(6, 'Sports Bike', 'Bike', 900.00, 150.00),
(7, 'Mini Van',     'Car', 4500.00, 600.00);    -- no vehicles yet (RIGHT JOIN demo)

INSERT INTO vehicle_owners (owner_id, owner_name, phone, email, city) VALUES
(1, 'Ravi Traders', '9811100001', 'ravi.traders@example.com', 'Hyderabad'),
(2, 'Sai Motors',    '9811100002', 'sai.motors@example.com',    'Hyderabad'),
(3, 'Anita Rao',     '9811100003', 'anita.rao@example.com',     'Bengaluru'),
(4, 'Deccan Fleet', '9811100004', 'deccan.fleet@example.com', 'Warangal');

INSERT INTO customers (customer_id, full_name, phone, email, license_number, city, registered_date, referred_by) VALUES
(1, 'Arjun Reddy',      '9000000001', 'arjun.reddy@example.com', 'TS09-2015-0001', 'Hyderabad', '2025-01-10', NULL),
(2, 'Priya Sharma',     '9000000002', 'priya.sharma@example.com', 'TS09-2016-0002', 'Hyderabad', '2025-02-05', 1),
(3, 'Karthik Rao',      '9000000003', 'karthik.rao@example.com', 'KA01-2014-0003', 'Bengaluru', '2025-03-12', 1),
(4, 'Sneha Patel',      '9000000004', 'sneha.patel@example.com', 'TS09-2018-0004', 'Hyderabad', '2025-04-01', 2),
(5, 'Mohammed Irfan', '9000000005', 'irfan.m@example.com',        'TS10-2013-0005', 'Hyderabad', '2025-05-15', NULL),
(6, 'Divya Nair',       '9000000006', 'divya.nair@example.com',   'KA03-2017-0006', 'Bengaluru', '2025-06-20', 3),
(7, 'Rahul Verma',      '9000000007', 'rahul.verma@example.com', 'TS04-2012-0007', 'Warangal', '2025-07-02', 5),
(8, 'Lakshmi Devi',     '9000000008', 'lakshmi.devi@example.com', 'TS09-2019-0008', 'Hyderabad', '2025-08-11', 2),
(9, 'Vikram Singh',     '9000000009', 'vikram.singh@example.com', 'KA05-2011-0009', 'Bengaluru', '2025-09-09', NULL),
(10, 'Anil Kumar',      '9000000010', 'anil.kumar@example.com',   'TS04-2016-0010', 'Warangal', '2026-01-15', 7),
(11, 'Pooja Iyer',      '9000000011', 'pooja.iyer@example.com',   'TN07-2018-0011', 'Chennai',   '2026-02-20', NULL),
(12, 'Sana Khan',       '9000000012', 'sana.khan@example.com',    'TS09-2020-0012', 'Hyderabad', '2026-03-03', 5);

-- Vehicle status already reflects today's position:
--   Rented      : 4 (overdue rental) and 6 (current rental)
--   Maintenance : 9
INSERT INTO vehicles (vehicle_id, registration_number, brand, model, `year`, category_id, owner_id, status) VALUES
(1, 'TS09AB1001', 'Maruti',          'Swift',            2022, 1, 1, 'Available'),
(2, 'TS09AB1002', 'Hyundai',         'i20',              2023, 1, 1, 'Available'),
(3, 'TS09CD2001', 'Honda',           'City',             2022, 2, 2, 'Available'),
(4, 'TS09CD2002', 'Hyundai',         'Verna',            2021, 2, 2, 'Rented'),
(5, 'TS10EF3001', 'Toyota',          'Fortuner',         2023, 3, 2, 'Available'),
(6, 'KA01GH4001', 'Mahindra',        'XUV700',           2024, 3, 3, 'Rented'),
(7, 'KA01GH4002', 'BMW',             '5 Series',         2023, 4, 3, 'Available'),
(8, 'TS09JK5001', 'Honda',           'Activa',           2023, 5, 1, 'Available'),
(9, 'TS09JK5002', 'TVS',             'Jupiter',          2022, 5, 4, 'Maintenance'),
(10, 'TS09LM6001', 'Royal Enfield', 'Classic 350',       2023, 6, 4, 'Available'),
(11, 'TS09LM6002', 'Yamaha',         'R15',              2024, 6, 4, 'Available'),
(12, 'TS09AB1003', 'Tata',           'Tiago',            2023, 1, 4, 'Available');

INSERT INTO rental_bookings (booking_id, customer_id, vehicle_id, start_date, end_date, booking_status) VALUES
(1, 1, 1, '2026-01-05', '2026-01-08', 'Completed'),
(2, 2, 3, '2026-01-20', '2026-01-22', 'Completed'),
(3, 3, 5, '2026-02-10', '2026-02-14', 'Completed'),
(4, 4, 8, '2026-02-15', '2026-02-16', 'Completed'),
(5, 5, 10, '2026-03-01', '2026-03-03', 'Completed'),
(6, 1, 2, '2026-03-10', '2026-03-12', 'Completed'),
(7, 6, 3, '2026-04-05', '2026-04-09', 'Completed'),
(8, 7, 11, '2026-05-02', '2026-05-04', 'Completed'),
(9, 8, 1, '2026-06-15', '2026-06-17', 'Completed'),
(10, 9, 6, '2026-07-01', '2026-07-06', 'Completed'),
(11, 12, 5, '2026-08-10', '2026-08-12', 'Completed'),
(12, 10, 10, '2026-09-01', '2026-09-03', 'Cancelled'),
(13, 2, 4, CURDATE() - INTERVAL 6 DAY, CURDATE() - INTERVAL 2 DAY, 'Active'),   -- OVERDUE
(14, 11, 6, CURDATE() - INTERVAL 1 DAY, CURDATE() + INTERVAL 3 DAY, 'Active'),  -- current
(15, 3, 3, CURDATE() + INTERVAL 10 DAY, CURDATE() + INTERVAL 12 DAY, 'Booked'); -- future

-- total_amount = agreed_daily_rate x number of rental days
INSERT INTO rental_agreements (agreement_id, booking_id, agreed_daily_rate, security_deposit, total_amount) VALUES
(1, 1, 1500.00, 2000.00, 6000.00),      -- 4 days
(2, 2, 2200.00, 3000.00, 6600.00),      -- 3 days
(3, 3, 3500.00, 5000.00, 17500.00),     -- 5 days
(4, 4,    500.00, 500.00, 1000.00),     -- 2 days
(5, 5,    900.00, 1000.00, 2700.00),    -- 3 days
(6, 6, 1500.00, 2000.00, 4500.00),      -- 3 days
(7, 7, 2200.00, 3000.00, 11000.00),     -- 5 days
(8, 8,    900.00, 1000.00, 2700.00),    -- 3 days
(9, 9, 1500.00, 2000.00, 4500.00),      -- 3 days
(10, 10, 3500.00, 6000.00, 21000.00),   -- 6 days
(11, 11, 3500.00, 5000.00, 10500.00),   -- 3 days
(12, 13, 2200.00, 3000.00, 11000.00),   -- 5 days (overdue)
(13, 14, 3500.00, 6000.00, 17500.00);   -- 5 days (current)

-- Advance = 50% of total; Final = balance + any penalties
INSERT INTO payments (agreement_id, amount, payment_mode, payment_type, payment_date) VALUES
(1,   3000.00, 'UPI', 'Advance', '2026-01-04'),
(1,   3000.00, 'Cash', 'Final',   '2026-01-08'),
(2,   3300.00, 'Card', 'Advance', '2026-01-19'),
(2,   5400.00, 'Card', 'Final',   '2026-01-24'),   -- 3300 balance + 2100 penalties
(3,   8750.00, 'UPI', 'Advance', '2026-02-09'),
(3,   8750.00, 'UPI', 'Final',    '2026-02-14'),
(4,    500.00, 'Cash', 'Advance', '2026-02-14'),
(4,    580.00, 'Cash', 'Final',   '2026-02-17'),   -- 500 balance + 80 penalty
(5,   1350.00, 'UPI', 'Advance', '2026-02-28'),
(5,   1350.00, 'UPI', 'Final',    '2026-03-03'),
(6,   2250.00, 'Card', 'Advance', '2026-03-09'),
(6,   2250.00, 'Card', 'Final',   '2026-03-12'),
(7,   5500.00, 'UPI', 'Advance', '2026-04-04'),
(7,   6200.00, 'UPI', 'Final',    '2026-04-10'),   -- 5500 balance + 700 penalties
(8,   1350.00, 'Cash', 'Advance', '2026-05-01'),
(8,   1350.00, 'Cash', 'Final',   '2026-05-04'),
(9,   2250.00, 'Card', 'Advance', '2026-06-14'),
(9,   5450.00, 'Card', 'Final',   '2026-06-18'),   -- 2250 balance + 3200 penalties
(10, 10500.00, 'UPI', 'Advance', '2026-06-30'),
(10, 10500.00, 'UPI', 'Final',    '2026-07-06'),
(11, 5250.00, 'Card', 'Advance', '2026-08-09'),
(11, 5250.00, 'Card', 'Final',    '2026-08-12'),
(12, 5500.00, 'Cash', 'Advance', CURDATE() - INTERVAL 7 DAY),
(13, 8750.00, 'UPI', 'Advance', CURDATE() - INTERVAL 2 DAY);

INSERT INTO vehicle_returns (return_id, agreement_id, return_date, vehicle_condition, days_late) VALUES
(1, 1, '2026-01-08', 'Good',           0),
(2, 2, '2026-01-24', 'Minor Damage', 2),
(3, 3, '2026-02-14', 'Good',           0),
(4, 4, '2026-02-17', 'Good',           1),
(5, 5, '2026-03-03', 'Good',           0),
(6, 6, '2026-03-12', 'Good',           0),
(7, 7, '2026-04-10', 'Good',           1),
(8, 8, '2026-05-04', 'Good',           0),
(9, 9, '2026-06-18', 'Major Damage', 1),
(10, 10, '2026-07-06', 'Good',         0),
(11, 11, '2026-08-12', 'Good',         0);

-- Penalty rule: days_late x late_fee_per_day, plus damage / fuel charges
INSERT INTO penalties (return_id, penalty_type, amount, remarks) VALUES
(2, 'Late Return', 600.00, '2 days x 300'),
(2, 'Damage',      1500.00, 'Front bumper scratch repair'),
(4, 'Late Return',   80.00, '1 day x 80'),
(7, 'Late Return', 300.00, '1 day x 300'),
(7, 'Fuel',         400.00, 'Returned with empty tank'),
(9, 'Late Return', 200.00, '1 day x 200'),
(9, 'Damage',      3000.00, 'Rear door dent and broken mirror');

INSERT INTO maintenance_records (vehicle_id, maintenance_date, description, cost) VALUES
(4, '2026-03-15', 'Brake pad replacement',       3200.00),
(1, '2026-04-02', 'Routine service',            1800.00),
(6, '2026-05-20', 'Tyre replacement (set of 4)', 8000.00),
(10, '2026-06-01', 'Chain and sprocket change', 1500.00),
(9, '2026-10-20', 'Engine service',             2500.00),
(9, '2026-10-28', 'Clutch repair',              1200.00);
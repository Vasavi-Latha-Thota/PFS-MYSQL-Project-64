CREATE DATABASE vehicle_rental_db

USE vehicle_rental_db;

-- 1. vehicle_categories : groups vehicles and holds the rates ----------
CREATE TABLE vehicle_categories (
  category_id      INT             NOT NULL AUTO_INCREMENT,
  category_name    VARCHAR(50)     NOT NULL,
  vehicle_type     ENUM('Car','Bike') NOT NULL,
  daily_rate       DECIMAL(10,2) NOT NULL,
  late_fee_per_day DECIMAL(10,2) NOT NULL DEFAULT 0,
  CONSTRAINT pk_category       PRIMARY KEY (category_id),
  CONSTRAINT uq_category_name UNIQUE (category_name),
  CONSTRAINT ck_category_rate CHECK (daily_rate > 0),
  CONSTRAINT ck_category_late CHECK (late_fee_per_day >= 0)
) ENGINE=InnoDB;

-- 2. vehicle_owners : who owns each vehicle ---------------------------
CREATE TABLE vehicle_owners (
  owner_id   INT          NOT NULL AUTO_INCREMENT,
  owner_name VARCHAR(100) NOT NULL,
  phone      VARCHAR(15) NOT NULL,
  email      VARCHAR(100) NOT NULL,
  city       VARCHAR(50) NOT NULL,
  CONSTRAINT pk_owner       PRIMARY KEY (owner_id),
  CONSTRAINT uq_owner_phone UNIQUE (phone),
  CONSTRAINT uq_owner_email UNIQUE (email)
) ENGINE=InnoDB;

-- 3. customers : renters, with a self-referencing "referred_by" -------
CREATE TABLE customers (
  customer_id     INT          NOT NULL AUTO_INCREMENT,
  full_name       VARCHAR(100) NOT NULL,
  phone           VARCHAR(15) NOT NULL,
  email           VARCHAR(100) NOT NULL,
  license_number VARCHAR(30) NOT NULL,
  city            VARCHAR(50) NOT NULL,
  registered_date DATE         NOT NULL DEFAULT (CURRENT_DATE),
  referred_by     INT          NULL,
  CONSTRAINT pk_customer         PRIMARY KEY (customer_id),
  CONSTRAINT uq_customer_phone   UNIQUE (phone),
  CONSTRAINT uq_customer_email   UNIQUE (email),
  CONSTRAINT uq_customer_licence UNIQUE (license_number),
  CONSTRAINT fk_customer_referrer FOREIGN KEY (referred_by)
    REFERENCES customers (customer_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 4. vehicles : each car or bike --------------------------------------
CREATE TABLE vehicles (
  vehicle_id          INT         NOT NULL AUTO_INCREMENT,
  registration_number VARCHAR(20) NOT NULL,
  brand               VARCHAR(50) NOT NULL,
  model               VARCHAR(50) NOT NULL,
  `year`              SMALLINT    NOT NULL,
  category_id         INT         NOT NULL,
  owner_id            INT         NOT NULL,
  status ENUM('Available','Rented','Maintenance') NOT NULL DEFAULT 'Available',
  CONSTRAINT pk_vehicle      PRIMARY KEY (vehicle_id),
  CONSTRAINT uq_vehicle_reg UNIQUE (registration_number),
  CONSTRAINT fk_vehicle_category FOREIGN KEY (category_id)
    REFERENCES vehicle_categories (category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_vehicle_owner FOREIGN KEY (owner_id)
    REFERENCES vehicle_owners (owner_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5. rental_bookings : customer request for dates ---------------------
CREATE TABLE rental_bookings (
  booking_id     INT NOT NULL AUTO_INCREMENT,
  customer_id    INT NOT NULL,
  vehicle_id     INT NOT NULL,
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  booking_status ENUM('Booked','Active','Completed','Cancelled')
                 NOT NULL DEFAULT 'Booked',
  CONSTRAINT pk_booking PRIMARY KEY (booking_id),
  CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_booking_vehicle FOREIGN KEY (vehicle_id)
    REFERENCES vehicles (vehicle_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_booking_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB;

-- 6. rental_agreements : final rental terms (one per booking) ---------
CREATE TABLE rental_agreements (
  agreement_id      INT           NOT NULL AUTO_INCREMENT,
  booking_id        INT           NOT NULL,
  agreed_daily_rate DECIMAL(10,2) NOT NULL,
  security_deposit DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_amount      DECIMAL(12,2) NOT NULL,
  CONSTRAINT pk_agreement PRIMARY KEY (agreement_id),
  CONSTRAINT uq_agreement_booking UNIQUE (booking_id),
  CONSTRAINT fk_agreement_booking FOREIGN KEY (booking_id)
    REFERENCES rental_bookings (booking_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_agreement_rate    CHECK (agreed_daily_rate > 0),
  CONSTRAINT ck_agreement_deposit CHECK (security_deposit >= 0),
  CONSTRAINT ck_agreement_total   CHECK (total_amount > 0)
) ENGINE=InnoDB;

-- 7. payments : every payment made ------------------------------------
CREATE TABLE payments (
  payment_id   INT           NOT NULL AUTO_INCREMENT,
  agreement_id INT           NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  payment_mode ENUM('Cash','Card','UPI','Bank Transfer') NOT NULL,
  payment_type ENUM('Advance','Final','Penalty') NOT NULL,
  payment_date DATE          NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT pk_payment PRIMARY KEY (payment_id),
  CONSTRAINT fk_payment_agreement FOREIGN KEY (agreement_id)
    REFERENCES rental_agreements (agreement_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_payment_amount CHECK (amount > 0)
) ENGINE=InnoDB;

-- 8. vehicle_returns : return date and condition (one per agreement) --
CREATE TABLE vehicle_returns (
  return_id         INT NOT NULL AUTO_INCREMENT,
  agreement_id      INT NOT NULL,
  return_date       DATE NOT NULL,
  vehicle_condition ENUM('Good','Minor Damage','Major Damage')
                    NOT NULL DEFAULT 'Good',
  days_late         INT NOT NULL DEFAULT 0,
  CONSTRAINT pk_return PRIMARY KEY (return_id),
  CONSTRAINT uq_return_agreement UNIQUE (agreement_id),
  CONSTRAINT fk_return_agreement FOREIGN KEY (agreement_id)
    REFERENCES rental_agreements (agreement_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_return_late CHECK (days_late >= 0)
) ENGINE=InnoDB;

-- 9. maintenance_records : service and repair cost --------------------
CREATE TABLE maintenance_records (
  maintenance_id   INT           NOT NULL AUTO_INCREMENT,
  vehicle_id       INT           NOT NULL,
  maintenance_date DATE          NOT NULL,
  description      VARCHAR(255) NOT NULL,
  cost             DECIMAL(10,2) NOT NULL,
  CONSTRAINT pk_maintenance PRIMARY KEY (maintenance_id),
  CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id)
    REFERENCES vehicles (vehicle_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_maintenance_cost CHECK (cost >= 0)
) ENGINE=InnoDB;

-- 10. penalties : fines raised on return ------------------------------
CREATE TABLE penalties (
  penalty_id   INT           NOT NULL AUTO_INCREMENT,
  return_id    INT           NOT NULL,
  penalty_type ENUM('Late Return','Damage','Fuel') NOT NULL,
  amount       DECIMAL(10,2) NOT NULL,
  remarks      VARCHAR(255) NULL,
  CONSTRAINT pk_penalty PRIMARY KEY (penalty_id),
  CONSTRAINT fk_penalty_return FOREIGN KEY (return_id)
    REFERENCES vehicle_returns (return_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_penalty_amount CHECK (amount > 0)
) ENGINE=InnoDB;
-- ====================================================
--  Queueless Database Schema — MySQL
-- ====================================================

CREATE DATABASE IF NOT EXISTS queueless_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE queueless_db;

-- -------------------------------------------------------
-- Users
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id          VARCHAR(36) PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(150) NOT NULL UNIQUE,
  password    VARCHAR(255) NOT NULL,
  phone       VARCHAR(30),
  notifications_enabled TINYINT(1) NOT NULL DEFAULT 1,
  role        ENUM('customer', 'businessOwner') NOT NULL DEFAULT 'customer',
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------
-- Businesses
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS businesses (
  id                     VARCHAR(36) PRIMARY KEY,
  owner_id               VARCHAR(36) NOT NULL,
  name                   VARCHAR(150) NOT NULL,
  description            TEXT,
  category               ENUM('bakery','barber','restaurant','clinic','bank','repair','beauty','dentist','gym','pharmacy','grocery','government','cafe','vet','other') NOT NULL DEFAULT 'other',
  service_type           ENUM('queue','appointment','both') NOT NULL DEFAULT 'both',
  address                VARCHAR(255),
  phone                  VARCHAR(30),
  image_url              VARCHAR(512),
  latitude               DECIMAL(10,7),
  longitude              DECIMAL(10,7),
  is_active              TINYINT(1) DEFAULT 1,
  approval_status        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'approved',
  rating                 DECIMAL(3,2) DEFAULT 0.00,
  rating_count           INT DEFAULT 0,
  total_customers_served INT DEFAULT 0,
  created_at             DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Products / Services
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id           VARCHAR(36) PRIMARY KEY,
  business_id  VARCHAR(36) NOT NULL,
  name         VARCHAR(150) NOT NULL,
  description  TEXT,
  price        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  duration_minutes INT NOT NULL DEFAULT 0,
  stock        INT DEFAULT 0,
  is_available TINYINT(1) DEFAULT 1,
  is_off_sale  TINYINT(1) DEFAULT 0,
  image_url    VARCHAR(512),
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Queues
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS queues (
  id              VARCHAR(36) PRIMARY KEY,
  business_id     VARCHAR(36) NOT NULL UNIQUE,
  waiting_count   INT DEFAULT 0,
  serving_count   INT DEFAULT 0,
  is_open         TINYINT(1) DEFAULT 1,
  updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Queue Entries (individual customer queue joins)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS queue_entries (
  id              VARCHAR(36) PRIMARY KEY,
  business_id     VARCHAR(36) NOT NULL,
  customer_id     VARCHAR(36) NOT NULL,
  customer_name   VARCHAR(100),
  product_name    VARCHAR(150),
  item_count      INT NOT NULL DEFAULT 1,
  product_duration_minutes INT NOT NULL DEFAULT 0,
  total_price     DECIMAL(10,2) DEFAULT 0.00,
  payment_method  ENUM('later','now') NOT NULL DEFAULT 'later',
  discount_code   VARCHAR(50),
  discount_amount DECIMAL(10,2) DEFAULT 0.00,
  position        INT,
  status          ENUM('waiting','serving','done','cancelled') DEFAULT 'waiting',
  joined_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  arrival_confirmed_at DATETIME,
  arrival_distance_meters INT,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Time Slots
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS time_slots (
  id            VARCHAR(36) PRIMARY KEY,
  business_id   VARCHAR(36) NOT NULL,
  start_time    DATETIME NOT NULL,
  end_time      DATETIME NOT NULL,
  is_booked     TINYINT(1) DEFAULT 0,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Appointments
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
  id              VARCHAR(36) PRIMARY KEY,
  business_id     VARCHAR(36) NOT NULL,
  business_name   VARCHAR(150),
  customer_id     VARCHAR(36) NOT NULL,
  customer_name   VARCHAR(100),
  slot_id         VARCHAR(36),
  date_time       DATETIME NOT NULL,
  service_name    VARCHAR(150),
  notes           TEXT,
  status          ENUM('pending','confirmed','completed','cancelled') DEFAULT 'pending',
  discount_code   VARCHAR(50),
  discount_amount DECIMAL(10,2) DEFAULT 0.00,
  final_price     DECIMAL(10,2),
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (slot_id) REFERENCES time_slots(id) ON DELETE SET NULL
);

-- -------------------------------------------------------
-- Discounts / Coupons
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS discounts (
  id              VARCHAR(36) PRIMARY KEY,
  business_id     VARCHAR(36) NOT NULL,
  code            VARCHAR(50) NOT NULL,
  type            ENUM('percentage','fixed') NOT NULL DEFAULT 'percentage',
  value           DECIMAL(10,2) NOT NULL,
  max_usage_count INT NOT NULL DEFAULT 1,
  used_count      INT DEFAULT 0,
  is_active       TINYINT(1) DEFAULT 1,
  expires_at      DATETIME,
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_code_per_business (business_id, code),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Ratings
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS ratings (
  id           VARCHAR(36) PRIMARY KEY,
  business_id  VARCHAR(36) NOT NULL,
  customer_id  VARCHAR(36) NOT NULL,
  rating       TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment      TEXT,
  products_purchased TEXT,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_rating (business_id, customer_id),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Notifications
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id           VARCHAR(36) PRIMARY KEY,
  recipient_id VARCHAR(36) NOT NULL,
  title        VARCHAR(180) NOT NULL,
  body         TEXT NOT NULL,
  type         VARCHAR(48) NOT NULL DEFAULT 'general',
  entity_type  VARCHAR(48),
  entity_id    VARCHAR(36),
  metadata     JSON,
  is_read      TINYINT(1) NOT NULL DEFAULT 0,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
);

-- -------------------------------------------------------
-- Seed data — Demo businesses
-- -------------------------------------------------------
INSERT IGNORE INTO users (id, name, email, password, phone, role) VALUES
  ('owner1', 'Hafize Hanım', 'hafize@test.com', '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6', '+905001234001', 'businessOwner'),
  ('owner2', 'Mahmut Bey', 'mahmut@test.com', '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6', '+905001234002', 'businessOwner'),
  ('owner3', 'Usta Ahmet', 'ahmet@test.com', '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6', '+905001234003', 'businessOwner'),
  ('owner4', 'Dr. Fatma', 'fatma@test.com', '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6', '+905001234004', 'businessOwner'),
  ('cust1', 'Test Musteri', 'customer@test.com', '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6', '+905009999001', 'customer');

-- Note: password hash above = '123456'

INSERT IGNORE INTO businesses (id, owner_id, name, description, category, service_type, address, latitude, longitude, is_active, approval_status, rating, total_customers_served) VALUES
  ('b1', 'owner1', 'Hafize Fırın', 'İzmir''in en tatlı pastanesi. Taze kek, baklava ve churros.', 'bakery', 'queue', 'Bostanlı, İzmir', 38.4558140, 27.1028360, 1, 'approved', 4.8, 1250),
  ('b2', 'owner2', 'Mahmut Berber', 'Adana''nın uzman saç kesimi ve sakal tıraşı.', 'barber', 'appointment', 'Seyhan, Adana', 36.9914270, 35.3255420, 1, 'approved', 4.9, 850),
  ('b3', 'owner3', 'Usta Tamirci', 'İstanbul''un expert araba tamir atölyesi.', 'repair', 'queue', 'Maslak, İstanbul', 41.1122810, 29.0203170, 1, 'approved', 4.6, 420),
  ('b4', 'owner4', 'Pati Veteriner', 'Antalya''da özel hayvan bakımı ve sağlık hizmetleri.', 'vet', 'appointment', 'Muratpaşa, Antalya', 36.8848040, 30.7040440, 1, 'approved', 4.7, 500);

INSERT IGNORE INTO queues (id, business_id, waiting_count, is_open) VALUES
  ('q1', 'b1', 3, 1),
  ('q3', 'b3', 1, 1);

INSERT IGNORE INTO products (id, business_id, name, description, price, duration_minutes, stock, is_available) VALUES
  ('p1', 'b1', 'Çikolatalı Pasta', 'Ev yapımı çikolatalı pasta.', 45.00, 4, 10, 1),
  ('p2', 'b1', 'Baklava (1kg)', 'Antep fıstıklı baklava.', 120.00, 5, 5, 1),
  ('s1', 'b2', 'Saç Kesimi', 'Kişiye özel saç kesimi.', 150.00, 45, 0, 1),
  ('s2', 'b2', 'Saç Yıkama', 'Özel şampuan ile saç yıkama.', 80.00, 20, 0, 1),
  ('s3', 'b2', 'Sakal Tıraşı', 'Profesyonel sakal şekillendirme.', 100.00, 25, 0, 1),
  ('s4', 'b4', 'Genel Muayene', 'Evcil hayvan genel sağlık muayenesi.', 200.00, 30, 0, 1),
  ('s5', 'b4', 'Aşılama', 'Yıllık aşı takibi.', 350.00, 20, 0, 1);

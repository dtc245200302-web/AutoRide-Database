-- =====================================================
-- AUTORIDE OPTIMIZED DATABASE
-- Tác giả: <Tên bạn>
-- Mô tả: Khắc phục các Data Gaps trong Legacy Schema
-- =====================================================

DROP DATABASE IF EXISTS autoride_db;
CREATE DATABASE autoride_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE autoride_db;

-- =====================================================
-- Bảng Cars
-- =====================================================
CREATE TABLE Cars (
    car_id        INT AUTO_INCREMENT PRIMARY KEY,
    model_name    VARCHAR(100) NOT NULL,
    license_plate VARCHAR(20)  UNIQUE NOT NULL
);

-- =====================================================
-- Bảng Rentals (đã nâng cấp)
-- =====================================================
CREATE TABLE Rentals (
    rental_id          INT AUTO_INCREMENT PRIMARY KEY,
    car_id             INT NOT NULL,
    customer_name      VARCHAR(100) NOT NULL,
    rent_date          DATETIME     NOT NULL,
    return_date        DATETIME     NULL,  -- ngày dự kiến trả
    actual_return_date DATETIME     NULL,  -- ngày trả thực tế

    -- FIX GAP #3: ENUM khóa chặt vòng đời hợp đồng
    status ENUM('BOOKED','ACTIVE','COMPLETED','CANCELLED')
           NOT NULL DEFAULT 'BOOKED',

    -- FIX GAP #1: Các cột tài chính dùng DECIMAL(12,2) tránh sai số FLOAT
    security_deposit DECIMAL(12,2) NOT NULL DEFAULT 0
                     CHECK (security_deposit >= 0),
    late_fee         DECIMAL(12,2) NOT NULL DEFAULT 0
                     CHECK (late_fee >= 0),
    damage_fee       DECIMAL(12,2) NOT NULL DEFAULT 0
                     CHECK (damage_fee >= 0),

    CONSTRAINT fk_rentals_cars
        FOREIGN KEY (car_id) REFERENCES Cars(car_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- =====================================================
-- Bảng Inspections (FIX GAP #2)
-- =====================================================
CREATE TABLE Inspections (
    inspection_id      INT AUTO_INCREMENT PRIMARY KEY,
    rental_id          INT NOT NULL,
    inspection_date    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    damage_description TEXT,
    inspector_name     VARCHAR(100) NOT NULL,

    CONSTRAINT fk_inspections_rentals
        FOREIGN KEY (rental_id) REFERENCES Rentals(rental_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- =====================================================
-- DML: Mô phỏng kịch bản thực tế (Bước 4)
-- =====================================================

-- 1. Thêm xe
INSERT INTO Cars (model_name, license_plate) VALUES
('Toyota Vios', '51A-12345'),
('Honda City',  '51A-67890');

-- 2. Khách Nguyễn Văn A đặt xe, đóng cọc 10.000.000
INSERT INTO Rentals
    (car_id, customer_name, rent_date, return_date, status, security_deposit)
VALUES
    (1, 'Nguyen Van A',
     '2026-09-20 08:00:00',
     '2026-09-23 08:00:00',
     'ACTIVE',
     10000000.00);

-- 3. Khách trả xe, nhân viên kiểm tra phát hiện vỡ đèn pha
INSERT INTO Inspections (rental_id, damage_description, inspector_name)
VALUES
    (1, N'Vỡ đèn pha trái', 'Trần Văn B');

-- 4. Cập nhật hợp đồng: COMPLETED, ghi nhận phí
UPDATE Rentals
SET status             = 'COMPLETED',
    actual_return_date = '2026-09-23 10:00:00',
    late_fee           = 0.00,
    damage_fee         = 2000000.00
WHERE rental_id = 1;

-- 5. SELECT tính tiền hoàn lại cho khách
SELECT
    r.rental_id,
    r.customer_name,
    r.security_deposit,
    r.late_fee,
    r.damage_fee,
    (r.security_deposit - r.late_fee - r.damage_fee) AS refund_amount,
    r.status
FROM Rentals r
WHERE r.rental_id = 1;

-- Kết quả kỳ vọng:
-- security_deposit = 10,000,000
-- late_fee         = 0
-- damage_fee       = 2,000,000
-- refund_amount    = 8,000,000  ✅
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
# Phân tích: Tại sao cột `damage_fee` là bắt buộc?

Trong Activity Diagram của quy trình "Thuê và Trả xe" tại AutoRide, có một nhánh rẽ nghiệp vụ quan trọng: **nếu xe bị trầy xước hoặc hư hỏng, hệ thống phải tính Phí sửa chữa (Damage Fee)**. Đây là một phần không thể thiếu để đảm bảo bài toán tài chính của công ty.

Nếu bảng `Rentals` không có cột `damage_fee`:
- **Không thể lưu vết giao dịch tài chính**: Nhân viên buộc phải trả lại toàn bộ tiền cọc cho khách, dù xe hư. Công ty mất tiền sửa chữa mà không có căn cứ để thu hồi.
- **Không thể tính tiền hoàn lại chính xác**: Công thức `Refund = Deposit - Late_fee - Damage_fee` không thực thi được, dẫn đến sai lệch kế toán.
- **Mất tính toàn vẹn dữ liệu**: Ghi chú tay ra sổ giấy là dữ liệu phi cấu trúc, không truy vấn được, không báo cáo được, không audit được.
- **Vi phạm nguyên tắc Normalization**: Mọi khoản tiền phát sinh trong quy trình đều phải được mô hình hóa thành cột riêng biệt với kiểu `DECIMAL` (không dùng `FLOAT` để tránh sai số làm tròn).

Tóm lại, `damage_fee` không chỉ là một cột — nó là **bằng chứng pháp lý và tài chính** cho mọi giao dịch có hư hỏng xe. Thiếu nó, hệ thống không thể vận hành đúng quy trình nghiệp vụ.
# Nhật ký tương tác với AI (Prompt Log)

## Câu hỏi 1: Chọn kiểu dữ liệu cho cột tài chính
**Prompt:** "Trong MySQL, nên dùng kiểu dữ liệu nào để lưu tiền tệ (tiền cọc, phí phạt)? Tại sao không nên dùng FLOAT?"

**Trả lời nhận được:**
- Dùng `DECIMAL(M, D)`, ví dụ `DECIMAL(12,2)` — lưu chính xác số thập phân.
- `FLOAT`/`DOUBLE` dùng biểu diễn nhị phân → sinh sai số làm tròn (0.1 + 0.2 ≠ 0.3).
- Với tiền VND, `DECIMAL(12,2)` cho phép tối đa ~9.9 tỷ, đủ cho hầu hết giao dịch.

**Áp dụng:** Dùng `DECIMAL(12,2)` cho `security_deposit`, `late_fee`, `damage_fee`.

---

## Câu hỏi 2: Quan hệ 1-1 vs 1-N cho bảng Inspections
**Prompt:** "Bảng Inspections nên có quan hệ 1-1 hay 1-N với Rentals? Khi nào chọn cái nào?"

**Trả lời nhận được:**
- **1-1**: Mỗi hợp đồng chỉ có đúng 1 biên bản kiểm tra.
- **1-N**: Mỗi hợp đồng có thể có nhiều biên bản (kiểm tra trước giao xe + kiểm tra khi nhận lại, hoặc nhiều lần phát hiện hư hỏng).
- AutoRide cần lưu cả biên bản **giao xe** và **nhận xe**, nên chọn **1-N**.

**Áp dụng:** Tạo FK `rental_id` trong `Inspections`, không có UNIQUE constraint.

---

## Câu hỏi 3: Cách chặn INSERT vào Inspections khi status = BOOKED
**Prompt:** "Làm sao để Database tự chặn insert vào bảng Inspections nếu hợp đồng đang ở trạng thái BOOKED?"

**Trả lời nhận được:**
- MySQL không hỗ trợ CHECK constraint tham chiếu bảng khác trực tiếp.
- Giải pháp: dùng **TRIGGER BEFORE INSERT** kiểm tra status của rental tương ứng.

**Áp dụng:** Viết trigger mẫu (xem bên dưới).

```sql
DELIMITER //
CREATE TRIGGER trg_inspection_check_status
BEFORE INSERT ON Inspections
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT status INTO v_status FROM Rentals WHERE rental_id = NEW.rental_id;
    IF v_status = 'BOOKED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể tạo biên bản kiểm tra khi hợp đồng chưa ACTIVE.';
    END IF;
END//
DELIMITER ;

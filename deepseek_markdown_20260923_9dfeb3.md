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
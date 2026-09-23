# Phân tích: Tại sao cột `damage_fee` là bắt buộc?

Trong Activity Diagram của quy trình "Thuê và Trả xe" tại AutoRide, có một nhánh rẽ nghiệp vụ quan trọng: **nếu xe bị trầy xước hoặc hư hỏng, hệ thống phải tính Phí sửa chữa (Damage Fee)**. Đây là một phần không thể thiếu để đảm bảo bài toán tài chính của công ty.

Nếu bảng `Rentals` không có cột `damage_fee`:
- **Không thể lưu vết giao dịch tài chính**: Nhân viên buộc phải trả lại toàn bộ tiền cọc cho khách, dù xe hư. Công ty mất tiền sửa chữa mà không có căn cứ để thu hồi.
- **Không thể tính tiền hoàn lại chính xác**: Công thức `Refund = Deposit - Late_fee - Damage_fee` không thực thi được, dẫn đến sai lệch kế toán.
- **Mất tính toàn vẹn dữ liệu**: Ghi chú tay ra sổ giấy là dữ liệu phi cấu trúc, không truy vấn được, không báo cáo được, không audit được.
- **Vi phạm nguyên tắc Normalization**: Mọi khoản tiền phát sinh trong quy trình đều phải được mô hình hóa thành cột riêng biệt với kiểu `DECIMAL` (không dùng `FLOAT` để tránh sai số làm tròn).

Tóm lại, `damage_fee` không chỉ là một cột — nó là **bằng chứng pháp lý và tài chính** cho mọi giao dịch có hư hỏng xe. Thiếu nó, hệ thống không thể vận hành đúng quy trình nghiệp vụ.
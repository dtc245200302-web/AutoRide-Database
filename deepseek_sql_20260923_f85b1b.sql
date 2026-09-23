-- Bước 1: Chọn CSDL
USE QuanLySinhVien;

-- Bước 2: Thêm Class
INSERT INTO Class VALUES (1, 'A1', '2008-12-20', 1);
INSERT INTO Class VALUES (2, 'A2', '2008-12-22', 1);
INSERT INTO Class VALUES (3, 'B3', CURRENT_DATE, 0);

-- Bước 3: Thêm Student
INSERT INTO Student (StudentName, Address, Phone, Status, ClassID)
VALUES ('Hung', 'Ha Noi', '0912113113', 1, 1);

INSERT INTO Student (StudentName, Address, Status, ClassID)
VALUES ('Hoa', 'Hai phong', 1, 1);

INSERT INTO Student (StudentName, Address, Phone, Status, ClassID)
VALUES ('Manh', 'HCM', '0123123123', 0, 2);

-- Bước 4: Thêm Subject (nhiều dòng 1 lệnh)
INSERT INTO Subject VALUES
 (1, 'CF', 5, 1),
 (2, 'C', 6, 1),
 (3, 'HDJ', 5, 1),
 (4, 'RDBMS', 10, 1);

-- Bước 5: Thêm Mark
INSERT INTO Mark (SubID, StudentID, Mark, ExamTimes)
VALUES (1, 1, 8, 1),
       (1, 2, 10, 2),
       (2, 1, 12, 1);
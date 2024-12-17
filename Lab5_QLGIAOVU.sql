--9. Lớp trưởng của một lớp phải là học viên của lớp đó.

CREATE TRIGGER trg_CheckClassLeader
ON LOP
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM LOP L
        JOIN HOCVIEN H ON L.TRGLOP = H.MAHV
        WHERE L.MALOP <> H.MALOP
    )
    BEGIN
        RAISERROR ('Lớp trưởng của một lớp phải là học viên của lớp đó.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--10. Trưởng khoa phải là giáo viên thuộc khoa và có học vị “TS” hoặc “PTS”.

CREATE TRIGGER trg_CheckDean
ON KHOA
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM KHOA K
        JOIN GIAOVIEN G ON K.TRGKHOA = G.MAGV
        WHERE K.MAKHOA <> G.MAKHOA OR G.HOCVI NOT IN ('TS', 'PTS')
    )
    BEGIN
        RAISERROR ('Trưởng khoa phải là giáo viên thuộc khoa và có học vị "TS" hoặc "PTS".', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

--15. Học viên chỉ được thi một môn học nào đó khi lớp của học viên đã học xong môn học này.

CREATE TRIGGER trg_CheckClassCompletion
ON KETQUATHI
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM KETQUATHI KQ
        JOIN HOCVIEN HV ON KQ.MAHV = HV.MAHV
        JOIN GIANGDAY GD ON HV.MALOP = GD.MALOP AND KQ.MAMH = GD.MAMH
        WHERE KQ.NGTHI < GD.DENNGAY
    )
    BEGIN
        RAISERROR ('Học viên chỉ được thi một môn học khi lớp của học viên đã học xong môn học này.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;



--16. Mỗi học kỳ của một năm học, một lớp chỉ được học tối đa 3 môn.

CREATE TRIGGER trg_CheckMaxCoursesPerSemester
ON GIANGDAY
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT L.MALOP, GD.HOCKY, GD.NAM, COUNT(GD.MAMH) AS TotalCourses
        FROM GIANGDAY GD
        JOIN LOP L ON GD.MALOP = L.MALOP
        GROUP BY L.MALOP, GD.HOCKY, GD.NAM
        HAVING COUNT(GD.MAMH) > 3
    )
    BEGIN
        RAISERROR ('Mỗi học kỳ của một năm học, một lớp chỉ được học tối đa 3 môn.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--17. Sỉ số của một lớp bằng với số lượng học viên thuộc lớp đó.

CREATE TRIGGER trg_CheckClassSize
ON HOCVIEN
AFTER INSERT, DELETE
AS
BEGIN
    UPDATE LOP
    SET SISO = (
        SELECT COUNT(*)
        FROM HOCVIEN HV
        WHERE HV.MALOP = LOP.MALOP
    )
END;


--18. Trong quan hệ DIEUKIEN giá trị của thuộc tính MAMH và MAMH_TRUOC trong cùng 
--một bộ không được giống nhau (“A”,”A”) và cũng không tồn tại hai bộ (“A”,”B”) và 
--(“B”,”A”).

CREATE TRIGGER trg_CheckDieuKien
ON DIEUKIEN
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE MAMH = MAMH_TRUOC
    )
    BEGIN
        RAISERROR ('Giá trị của MAMH và MAMH_TRUOC trong cùng một bộ không được giống nhau.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM DIEUKIEN DK1
        JOIN inserted DK2 ON DK1.MAMH = DK2.MAMH_TRUOC AND DK1.MAMH_TRUOC = DK2.MAMH
    )
    BEGIN
        RAISERROR ('Không tồn tại hai bộ có giá trị đảo ngược nhau.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;



--19. Các giáo viên có cùng học vị, học hàm, hệ số lương thì mức lương bằng nhau.

CREATE TRIGGER trg_CheckEqualSalary
ON GIAOVIEN
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM GIAOVIEN G1
        JOIN GIAOVIEN G2 ON G1.HOCVI = G2.HOCVI AND G1.HOCHAM = G2.HOCHAM AND G1.HESO = G2.HESO
        WHERE G1.MUCLUONG <> G2.MUCLUONG
    )
    BEGIN
        RAISERROR ('Các giáo viên có cùng học vị, học hàm, hệ số lương thì mức lương phải bằng nhau.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--20. Học viên chỉ được thi lại (lần thi >1) khi điểm của lần thi trước đó dưới 5.

CREATE TRIGGER trg_CheckRetakeExam
ON KETQUATHI
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM KETQUATHI K1
        JOIN inserted K2
        ON K1.MAHV = K2.MAHV AND K1.MAMH = K2.MAMH AND K2.LANTHI > 1
        WHERE K1.LANTHI = K2.LANTHI - 1 AND K1.DIEM >= 5
    )
    BEGIN
        RAISERROR ('Học viên chỉ được thi lại khi điểm của lần thi trước đó dưới 5.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;



--21. Ngày thi của lần thi sau phải lớn hơn ngày thi của lần thi trước (cùng học viên, cùng môn 
--học).

CREATE TRIGGER trg_CheckExamDate
ON KETQUATHI
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM KETQUATHI K1
        JOIN KETQUATHI K2
        ON K1.MAHV = K2.MAHV AND K1.MAMH = K2.MAMH
        WHERE K1.LANTHI < K2.LANTHI AND K1.NGTHI >= K2.NGTHI
    )
    BEGIN
        RAISERROR ('Ngày thi của lần thi sau phải lớn hơn ngày thi của lần thi trước.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--22. Khi phân công giảng dạy một môn học, phải xét đến thứ tự trước sau giữa các môn học (sau 
--khi học xong những môn học phải học trước mới được học những môn liền sau).

CREATE TRIGGER trg_CheckCourseOrder
ON GIANGDAY
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM GIANGDAY GD
        JOIN DIEUKIEN DK
        ON GD.MAMH = DK.MAMH
        WHERE NOT EXISTS (
            SELECT 1
            FROM KETQUATHI KQ
            WHERE KQ.MAHV = GD.MALOP
            AND KQ.MAMH = DK.MAMH_TRUOC
            AND KQ.KQUA = 'Đạt'
        )
    )
    BEGIN
        RAISERROR ('Phải học xong những môn học trước mới được học những môn liền sau.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


--23. Giáo viên chỉ được phân công dạy những môn thuộc khoa giáo viên đó phụ trách.

CREATE TRIGGER trg_CheckTeacherDepartment
ON GIANGDAY
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM GIANGDAY GD
        JOIN GIAOVIEN GV ON GD.MAGV = GV.MAGV
        JOIN MONHOC MH ON GD.MAMH = MH.MAMH
        WHERE GV.MAKHOA <> MH.MAKHOA
    )
    BEGIN
        RAISERROR ('Giáo viên chỉ được phân công dạy những môn thuộc khoa giáo viên đó phụ trách.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
-- Câu hỏi và ví dụ về Triggers (101-110)

-- 101. Tạo một trigger để tự động cập nhật trường NgayCapNhat trong bảng ChuyenGia mỗi khi có sự thay đổi thông tin.

ALTER TABLE ChuyenGia
ADD NgayCapNhat DATE;
CREATE TRIGGER trg_UpdateNgayCapNhat
ON ChuyenGia
AFTER INSERT, UPDATE
AS
BEGIN
    -- Cập nhật trường NgayCapNhat mỗi khi có sự thay đổi
    UPDATE ChuyenGia
    SET NgayCapNhat = GETDATE()
    FROM ChuyenGia CG
    JOIN inserted I ON CG.MaChuyenGia = I.MaChuyenGia;
END;


-- 102. Tạo một trigger để ghi log mỗi khi có sự thay đổi trong bảng DuAn.

CREATE TABLE DuAn_Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    MaDuAn INT,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    TrangThai NVARCHAR(50),
    ChangeType NVARCHAR(10),
    ChangeDate DATETIME DEFAULT GETDATE()
);
CREATE TRIGGER trg_DuAnLog
ON DuAn
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Log cho thao tác INSERT
    INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ChangeType)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'INSERT'
    FROM inserted;

    -- Log cho thao tác UPDATE
    INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ChangeType)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'UPDATE'
    FROM inserted;

    -- Log cho thao tác DELETE
    INSERT INTO DuAn_Log (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, ChangeType)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai, 'DELETE'
    FROM deleted;
END;


-- 103. Tạo một trigger để đảm bảo rằng một chuyên gia không thể tham gia vào quá 5 dự án cùng một lúc.

CREATE TRIGGER trg_CheckMaxProjects
ON ChuyenGia_DuAn
AFTER INSERT, UPDATE
AS
BEGIN
	IF EXISTS	(
			SELECT 1
			FROM	(
				SELECT MaChuyenGia, COUNT(*) SoDuAn
				FROM ChuyenGia_DuAn CGDA
				GROUP BY MaChuyenGia
				HAVING COUNT(*) > 5
					) SubQuery
				)
	BEGIN
		RAISERROR ('Một chuyên gia không thể tham gia vào quá 5 dự án cùng một lúc.',16,1)
		ROLLBACK TRANSACTION;
	END
END;

-- 104. Tạo một trigger để tự động cập nhật số lượng nhân viên trong bảng CongTy mỗi khi có sự thay đổi trong bảng ChuyenGia.

CREATE TRIGGER trg_UpdateSLNV
ON ChuyenGia
AFTER INSERT, UPDATE, DELETE
AS 
BEGIN
		UPDATE CongTy
		SET SoNhanVien =	(
					SELECT COUNT(*)
					FROM ChuyenGia CG
					JOIN ChuyenGia_DuAn CGDA ON CGDA.MaChuyenGia = CG.MaChuyenGia
					JOIN DuAn DA ON DA.MaDuAn = CGDA.MaDuAn
					JOIN CongTy CT ON CT.MaCongTy = DA.MaCongTy
							)
END;

-- 105. Tạo một trigger để ngăn chặn việc xóa các dự án đã hoàn thành.

CREATE TRIGGER trg_PreventDeleteCompletedProjects
ON DuAn
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM deleted
        WHERE TrangThai = 'Hoàn thành'
    )
    BEGIN
        RAISERROR ('Không thể xóa các dự án đã hoàn thành.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    DELETE FROM DuAn
    WHERE MaDuAn IN (SELECT MaDuAn FROM deleted);
END;


-- 106. Tạo một trigger để tự động cập nhật cấp độ kỹ năng của chuyên gia khi họ tham gia vào một dự án mới.

CREATE TRIGGER trg_UpdateSkillLevel
ON ChuyenGia_DuAn
AFTER INSERT
AS
BEGIN
    UPDATE ChuyenGia_KyNang
    SET CapDo = CapDo + 1
    WHERE MaChuyenGia IN (SELECT MaChuyenGia FROM inserted);
END;


-- 107. Tạo một trigger để ghi log mỗi khi có sự thay đổi cấp độ kỹ năng của chuyên gia.

CREATE TABLE ChuyenGia_KyNang_Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    MaChuyenGia INT,
    MaKyNang INT,
    CapDoCu INT,
    CapDoMoi INT,
    ChangeDate DATETIME DEFAULT GETDATE()
);

CREATE TRIGGER trg_LogSkillLevelChange
ON ChuyenGia_KyNang
AFTER UPDATE
AS
BEGIN
    INSERT INTO ChuyenGia_KyNang_Log (MaChuyenGia, MaKyNang, CapDoCu, CapDoMoi)
    SELECT 
        D.MaChuyenGia, 
        D.MaKyNang, 
        D.CapDo AS CapDoCu, 
        I.CapDo AS CapDoMoi
    FROM 
        inserted I
    JOIN 
        deleted D ON I.MaChuyenGia = D.MaChuyenGia AND I.MaKyNang = D.MaKyNang
    WHERE 
        I.CapDo <> D.CapDo;
END;


-- 108. Tạo một trigger để đảm bảo rằng ngày kết thúc của dự án luôn lớn hơn ngày bắt đầu.

CREATE TRIGGER trg_CheckProjectDates
ON DuAn
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE NgayKetThuc <= NgayBatDau
    )
    BEGIN
        RAISERROR ('Ngày kết thúc của dự án phải lớn hơn ngày bắt đầu.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Thực hiện thao tác INSERT hoặc UPDATE nếu điều kiện thỏa mãn
    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        INSERT INTO DuAn (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai)
        SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai
        FROM inserted;
    END

    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        UPDATE DuAn
        SET MaDuAn = I.MaDuAn,
            TenDuAn = I.TenDuAn,
            MaCongTy = I.MaCongTy,
            NgayBatDau = I.NgayBatDau,
            NgayKetThuc = I.NgayKetThuc,
            TrangThai = I.TrangThai
        FROM inserted I
        JOIN deleted D ON I.MaDuAn = D.MaDuAn;
    END
END;



-- 109. Tạo một trigger để tự động xóa các bản ghi liên quan trong bảng ChuyenGia_KyNang khi một kỹ năng bị xóa.

CREATE TRIGGER trg_DeleteRelatedRecords
ON KyNang
AFTER DELETE
AS
BEGIN
    DELETE FROM ChuyenGia_KyNang
    WHERE MaKyNang IN (SELECT MaKyNang FROM deleted);
END;


-- 110. Tạo một trigger để đảm bảo rằng một công ty không thể có quá 10 dự án đang thực hiện cùng một lúc.

CREATE TRIGGER trg_CheckMaxProject
ON DuAn
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT MaCongTy, COUNT(*) AS SoDuAn
            FROM DuAn
            WHERE TrangThai = 'Đang thực hiện'
            GROUP BY MaCongTy
            HAVING COUNT(*) > 10
        ) AS SubQuery
    )
    BEGIN
        RAISERROR ('Một công ty không thể có quá 10 dự án đang thực hiện cùng một lúc.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


-- Câu hỏi và ví dụ về Triggers bổ sung (123-135)



-- 123. Tạo một trigger để tự động cập nhật lương của chuyên gia dựa trên cấp độ kỹ năng và số năm kinh nghiệm.

ALTER TABLE ChuyenGia
ADD MucLuong MONEY

CREATE TRIGGER trg_UpdateSalary
ON ChuyenGia_KyNang
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Giả định các hệ số lương cố định
    UPDATE ChuyenGia
    SET MucLuong = 10000 + (
        SELECT SUM(5000 * CK.CapDo)
        FROM ChuyenGia_KyNang CK
        WHERE CK.MaChuyenGia = ChuyenGia.MaChuyenGia
    ) + (1000 * NamKinhNghiem)
    WHERE MaChuyenGia IN (SELECT DISTINCT MaChuyenGia FROM inserted)
    OR MaChuyenGia IN (SELECT DISTINCT MaChuyenGia FROM deleted);
END;


-- 124. Tạo một trigger để tự động gửi thông báo khi một dự án sắp đến hạn (còn 7 ngày).

CREATE TRIGGER trg_SendNotification
ON DuAn
AFTER UPDATE
AS
BEGIN
    INSERT INTO ThongBao (MaDuAn, NoiDung)
    SELECT MaDuAn, N'Dự án ' + TenDuAn + N' sắp đến hạn trong vòng 7 ngày.'
    FROM inserted
    WHERE DATEDIFF(day, GETDATE(), NgayKetThuc) = 7;
END;


-- Tạo bảng ThongBao nếu chưa có
CREATE TABLE ThongBao (
    MaThongBao INT IDENTITY(1,1) PRIMARY KEY,
    MaDuAn INT,
    NoiDung NVARCHAR(500),
    NgayThongBao DATETIME DEFAULT GETDATE(),
    DaGui BIT DEFAULT 0
);



-- 125. Tạo một trigger để ngăn chặn việc xóa hoặc cập nhật thông tin của chuyên gia đang tham gia dự án.

CREATE TRIGGER trg_PreventDeleteOrUpdate
ON ChuyenGia
INSTEAD OF DELETE, UPDATE
AS
BEGIN
    -- Kiểm tra nếu chuyên gia đang tham gia dự án
    IF EXISTS (
        SELECT 1
        FROM deleted D
        JOIN ChuyenGia_DuAn CGDA ON D.MaChuyenGia = CGDA.MaChuyenGia
    )
    BEGIN
        RAISERROR ('Không thể xóa hoặc cập nhật thông tin của chuyên gia đang tham gia dự án.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Thực hiện thao tác UPDATE nếu không vi phạm ràng buộc
    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        UPDATE ChuyenGia
        SET HoTen = I.HoTen,
            NgaySinh = I.NgaySinh,
            GioiTinh = I.GioiTinh,
            Email = I.Email,
            SoDienThoai = I.SoDienThoai,
            ChuyenNganh = I.ChuyenNganh,
            NamKinhNghiem = I.NamKinhNghiem
        FROM inserted I
        JOIN deleted D ON I.MaChuyenGia = D.MaChuyenGia;
    END

    -- Thực hiện thao tác DELETE nếu không vi phạm ràng buộc
    IF EXISTS (SELECT * FROM deleted)
    BEGIN
        DELETE FROM ChuyenGia
        WHERE MaChuyenGia IN (SELECT MaChuyenGia FROM deleted);
    END
END;


-- 126. Tạo một trigger để tự động cập nhật số lượng chuyên gia trong mỗi chuyên ngành.

CREATE TRIGGER trg_UpdateSoLuongChuyenGia
ON ChuyenGia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Xóa các bản ghi cũ
    DELETE FROM ThongKeChuyenNganh;

    -- Thêm các bản ghi mới với số lượng chuyên gia được cập nhật
    INSERT INTO ThongKeChuyenNganh (ChuyenNganh, SoLuongChuyenGia)
    SELECT ChuyenNganh, COUNT(*)
    FROM ChuyenGia
    GROUP BY ChuyenNganh;
END;



-- Tạo bảng ThongKeChuyenNganh nếu chưa có

CREATE TABLE ThongKeChuyenNganh (
    ChuyenNganh NVARCHAR(50) PRIMARY KEY,
    SoLuongChuyenGia INT
);


-- 127. Tạo một trigger để tự động tạo bản sao lưu của dự án khi nó được đánh dấu là hoàn thành.

CREATE TRIGGER trg_BackupCompletedProject
ON DuAn
AFTER UPDATE
AS
BEGIN
    -- Sao lưu dự án khi trạng thái được cập nhật thành 'Hoàn thành'
    INSERT INTO DuAnHoanThanh (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, TrangThai
    FROM inserted
    WHERE TrangThai = 'Hoàn thành' 
    AND MaDuAn NOT IN (SELECT MaDuAn FROM DuAnHoanThanh);
END;


-- Tạo bảng DuAnHoanThanh nếu chưa có

CREATE TABLE DuAnHoanThanh (
    MaDuAn INT PRIMARY KEY,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    TrangThai NVARCHAR(50),
    FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy)
);


-- 128. Tạo một trigger để tự động cập nhật điểm đánh giá trung bình của công ty dựa trên điểm đánh giá của các dự án.

ALTER TABLE DuAn
ADD DiemDanhGia FLOAT;
ALTER TABLE CongTy
ADD DiemDanhGiaTrungBinh FLOAT

CREATE TRIGGER trg_UpdateDiemDanhGiaTrungBinh
ON DuAn
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Cập nhật điểm đánh giá trung bình của công ty mỗi khi có thay đổi trong bảng DuAn
    UPDATE CongTy
    SET DiemDanhGiaTrungBinh = (
        SELECT AVG(DiemDanhGia)
        FROM DuAn
        WHERE DuAn.MaCongTy = CongTy.MaCongTy
    )
    WHERE MaCongTy IN (
        SELECT DISTINCT MaCongTy
        FROM inserted
        UNION
        SELECT DISTINCT MaCongTy
        FROM deleted
    );
END;


-- 129. Tạo một trigger để tự động phân công chuyên gia vào dự án dựa trên kỹ năng và kinh nghiệm.

CREATE TABLE YeuCauKyNang (
    MaDuAn INT,
    MaKyNang INT,
    CapDoYeuCau INT,
    PRIMARY KEY (MaDuAn, MaKyNang),
    FOREIGN KEY (MaDuAn) REFERENCES DuAn(MaDuAn),
    FOREIGN KEY (MaKyNang) REFERENCES KyNang(MaKyNang)
);

CREATE TRIGGER trg_AssignExpertToProject
ON DuAn
AFTER INSERT
AS
BEGIN
    -- Phân công chuyên gia vào dự án mới dựa trên kỹ năng và kinh nghiệm
    INSERT INTO ChuyenGia_DuAn (MaChuyenGia, MaDuAn, VaiTro, NgayThamGia)
    SELECT CG.MaChuyenGia, I.MaDuAn, 'Phân công tự động', GETDATE()
    FROM ChuyenGia CG
    JOIN ChuyenGia_KyNang CGK ON CG.MaChuyenGia = CGK.MaChuyenGia
    JOIN YeuCauKyNang YCKN ON YCKN.MaKyNang = CGK.MaKyNang
    JOIN inserted I ON I.MaDuAn = YCKN.MaDuAn
    WHERE CGK.CapDo >= YCKN.CapDoYeuCau
    AND CG.NamKinhNghiem >= 2; -- Giả định yêu cầu tối thiểu 2 năm kinh nghiệm
END;


-- 130. Tạo một trigger để tự động cập nhật trạng thái "bận" của chuyên gia khi họ được phân công vào dự án mới.

ALTER TABLE ChuyenGia
ADD TrangThai NVARCHAR(20);

CREATE TRIGGER trg_UpdateStatusOnAssignment
ON ChuyenGia_DuAn
AFTER INSERT
AS
BEGIN
    -- Cập nhật trạng thái "bận" của chuyên gia khi họ được phân công vào dự án mới
    UPDATE ChuyenGia
    SET TrangThai = 'Bận'
    WHERE MaChuyenGia IN (SELECT MaChuyenGia FROM inserted);
END;


-- 131. Tạo một trigger để ngăn chặn việc thêm kỹ năng trùng lặp cho một chuyên gia.

CREATE TRIGGER trg_PreventDuplicateSkills
ON ChuyenGia_KyNang
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted I
        JOIN ChuyenGia_KyNang CGK ON I.MaChuyenGia = CGK.MaChuyenGia AND I.MaKyNang = CGK.MaKyNang
    )
    BEGIN
        RAISERROR ('Kỹ năng đã tồn tại cho chuyên gia này.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO ChuyenGia_KyNang (MaChuyenGia, MaKyNang, CapDo)
        SELECT MaChuyenGia, MaKyNang, CapDo
        FROM inserted;
    END
END;


-- 132. Tạo một trigger để tự động tạo báo cáo tổng kết khi một dự án kết thúc.

CREATE TABLE BaoCaoTongKet (
    MaBaoCao INT IDENTITY(1,1) PRIMARY KEY,
    MaDuAn INT,
    TenDuAn NVARCHAR(200),
    MaCongTy INT,
    NgayBatDau DATE,
    NgayKetThuc DATE,
    DiemDanhGia FLOAT,
    GhiChu NVARCHAR(1000),
    NgayBaoCao DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (MaDuAn) REFERENCES DuAn(MaDuAn),
    FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy)
);


CREATE TRIGGER trg_CreateSummaryReport
ON DuAn
AFTER UPDATE
AS
BEGIN
    -- Tạo báo cáo tổng kết khi trạng thái dự án được cập nhật thành 'Hoàn thành'
    INSERT INTO BaoCaoTongKet (MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, DiemDanhGia, GhiChu)
    SELECT MaDuAn, TenDuAn, MaCongTy, NgayBatDau, NgayKetThuc, DiemDanhGia, N'Tổng kết dự án thành công.'
    FROM inserted
    WHERE TrangThai = 'Hoàn thành';
END;


-- 133. Tạo một trigger để tự động cập nhật thứ hạng của công ty dựa trên số lượng dự án hoàn thành và điểm đánh giá.

ALTER TABLE DuAn
ADD DiemDanhGia FLOAT,
    TrangThai NVARCHAR(50);
ALTER TABLE CongTy
ADD ThuHang INT,
	SoLuongDuAnHoanThanh INT

CREATE TRIGGER trg_UpdateCompanyRank
ON DuAn
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Cập nhật số lượng dự án hoàn thành của công ty
    UPDATE CongTy
    SET SoLuongDuAnHoanThanh = (
        SELECT COUNT(*)
        FROM DuAn
        WHERE DuAn.MaCongTy = CongTy.MaCongTy AND TrangThai = 'Hoàn thành'
    );

    -- Cập nhật điểm đánh giá trung bình của công ty
    UPDATE CongTy
    SET DiemDanhGiaTrungBinh = (
        SELECT AVG(DiemDanhGia)
        FROM DuAn
        WHERE DuAn.MaCongTy = CongTy.MaCongTy
    );

    -- Cập nhật thứ hạng của công ty
    WITH RankData AS (
        SELECT MaCongTy,
               ROW_NUMBER() OVER (ORDER BY SoLuongDuAnHoanThanh DESC, DiemDanhGiaTrungBinh DESC) AS Rank
        FROM CongTy
    )
    UPDATE CongTy
    SET ThuHang = RankData.Rank
    FROM CongTy
    INNER JOIN RankData ON CongTy.MaCongTy = RankData.MaCongTy;
END;



-- 133. (tiếp tục) Tạo một trigger để tự động cập nhật thứ hạng của công ty dựa trên số lượng dự án hoàn thành và điểm đánh giá.



-- 134. Tạo một trigger để tự động gửi thông báo khi một chuyên gia được thăng cấp (dựa trên số năm kinh nghiệm).

CREATE TABLE ThongBaoThangCap (
    MaThongBao INT IDENTITY(1,1) PRIMARY KEY,
    MaChuyenGia INT,
    NoiDung NVARCHAR(500),
    NgayThongBao DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (MaChuyenGia) REFERENCES ChuyenGia(MaChuyenGia)
);

CREATE TRIGGER trg_SendPromotionNotification
ON ChuyenGia
AFTER UPDATE
AS
BEGIN
    -- Gửi thông báo khi chuyên gia được thăng cấp dựa trên số năm kinh nghiệm
    IF EXISTS (
        SELECT 1
        FROM inserted I
        WHERE I.NamKinhNghiem >= 10
        AND NOT EXISTS (
            SELECT 1
            FROM deleted D
            WHERE D.MaChuyenGia = I.MaChuyenGia
            AND D.NamKinhNghiem >= 10
        )
    )
    BEGIN
        INSERT INTO ThongBaoThangCap (MaChuyenGia, NoiDung)
        SELECT I.MaChuyenGia, N'Chúc mừng ' + I.HoTen + N' đã được thăng cấp do đạt ' + CAST(I.NamKinhNghiem AS NVARCHAR) + N' năm kinh nghiệm!'
        FROM inserted I
        WHERE I.NamKinhNghiem >= 10;
    END
END;


-- 135. Tạo một trigger để tự động cập nhật trạng thái "khẩn cấp" cho dự án khi thời gian còn lại ít hơn 10% tổng thời gian dự án.

CREATE TRIGGER trg_UpdateEmergencyStatus
ON DuAn
AFTER UPDATE
AS
BEGIN
    -- Cập nhật trạng thái "khẩn cấp" cho dự án khi thời gian còn lại ít hơn 10% tổng thời gian dự án
    UPDATE DuAn
    SET TrangThai = 'Khẩn cấp'
    WHERE DATEDIFF(day, GETDATE(), NgayKetThuc) < 0.1 * DATEDIFF(day, NgayBatDau, NgayKetThuc)
    AND TrangThai <> 'Hoàn thành';
END;


-- 136. Tạo một trigger để tự động cập nhật số lượng dự án đang thực hiện của mỗi chuyên gia.

ALTER TABLE ChuyenGia
ADD SoLuongDuAnDangThucHien INT DEFAULT 0;

CREATE TRIGGER trg_UpdateOngoingProjectsCount
ON ChuyenGia_DuAn
AFTER INSERT, DELETE
AS
BEGIN
    -- Cập nhật số lượng dự án đang thực hiện khi có thao tác Thêm (INSERT) vào bảng ChuyenGia_DuAn
    UPDATE ChuyenGia
    SET SoLuongDuAnDangThucHien = (
        SELECT COUNT(*)
        FROM ChuyenGia_DuAn
        WHERE ChuyenGia_DuAn.MaChuyenGia = ChuyenGia.MaChuyenGia
    )
    WHERE MaChuyenGia IN (SELECT MaChuyenGia FROM inserted);

    -- Cập nhật số lượng dự án đang thực hiện khi có thao tác Xóa (DELETE) từ bảng ChuyenGia_DuAn
    UPDATE ChuyenGia
    SET SoLuongDuAnDangThucHien = (
        SELECT COUNT(*)
        FROM ChuyenGia_DuAn
        WHERE ChuyenGia_DuAn.MaChuyenGia = ChuyenGia.MaChuyenGia
    )
    WHERE MaChuyenGia IN (SELECT MaChuyenGia FROM deleted);
END;


-- 137. Tạo một trigger để tự động tính toán và cập nhật tỷ lệ thành công của công ty dựa trên số dự án hoàn thành và tổng số dự án.

ALTER TABLE CongTy
ADD TyLeThanhCong FLOAT,
	TongSoDuAn INT;

CREATE TRIGGER trg_UpdateSuccessRate
ON DuAn
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Cập nhật số lượng dự án hoàn thành và tổng số dự án của mỗi công ty
    UPDATE CongTy
    SET SoLuongDuAnHoanThanh = (
        SELECT COUNT(*)
        FROM DuAn
        WHERE DuAn.MaCongTy = CongTy.MaCongTy AND TrangThai = 'Hoàn thành'
    ),
    TongSoDuAn = (
        SELECT COUNT(*)
        FROM DuAn
        WHERE DuAn.MaCongTy = CongTy.MaCongTy
    );

    -- Cập nhật tỷ lệ thành công của mỗi công ty
    UPDATE CongTy
    SET TyLeThanhCong = CASE
        WHEN TongSoDuAn > 0 THEN (SoLuongDuAnHoanThanh * 1.0 / TongSoDuAn) * 100
        ELSE 0
    END;
END;


-- 138. Tạo một trigger để tự động ghi log mỗi khi có thay đổi trong bảng lương của chuyên gia.

CREATE TABLE LuongLog (
    MaLog INT IDENTITY(1,1) PRIMARY KEY,
    MaChuyenGia INT,
    MucLuongCu FLOAT,
    MucLuongMoi FLOAT,
    ThoiGianThayDoi DATETIME DEFAULT GETDATE(),
    GhiChu NVARCHAR(500),
    FOREIGN KEY (MaChuyenGia) REFERENCES ChuyenGia(MaChuyenGia)
);

CREATE TRIGGER trg_LogSalaryChanges
ON ChuyenGia
AFTER UPDATE
AS
BEGIN
    INSERT INTO LuongLog (MaChuyenGia, MucLuongCu, MucLuongMoi, GhiChu)
    SELECT 
        D.MaChuyenGia,
        D.MucLuong AS MucLuongCu,
        I.MucLuong AS MucLuongMoi,
        N'Lương được thay đổi'
    FROM deleted D
    JOIN inserted I ON D.MaChuyenGia = I.MaChuyenGia
    WHERE D.MucLuong <> I.MucLuong;
END;


-- 139. Tạo một trigger để tự động cập nhật số lượng chuyên gia cấp cao trong mỗi công ty.

ALTER TABLE CongTy
ADD SoLuongChuyenGiaCapCao INT DEFAULT 0;
ALTER TABLE ChuyenGia
ADD MaCongTy int
FOREIGN KEY (MaCongTy) REFERENCES CongTy(MaCongTy)

CREATE TRIGGER trg_UpdateSeniorExpertsCount
ON ChuyenGia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Cập nhật số lượng chuyên gia cấp cao của mỗi công ty
    UPDATE CongTy
    SET SoLuongChuyenGiaCapCao = (
        SELECT COUNT(*)
        FROM ChuyenGia
        WHERE ChuyenGia.MaCongTy = CongTy.MaCongTy
        AND ChuyenGia.NamKinhNghiem >= 10
    );
END;



-- 140. Tạo một trigger để tự động cập nhật trạng thái "cần bổ sung nhân lực" cho dự án khi số lượng chuyên gia tham gia ít hơn yêu cầu.

ALTER TABLE DuAn
ADD SoLuongChuyenGiaYeuCau INT;

CREATE TRIGGER trg_UpdateProjectStatusForResources
ON ChuyenGia_DuAn
AFTER INSERT, DELETE
AS
BEGIN
    -- Cập nhật trạng thái "cần bổ sung nhân lực" khi số lượng chuyên gia tham gia ít hơn yêu cầu
    UPDATE DuAn
    SET TrangThai = 'Cần bổ sung nhân lực'
    WHERE DuAn.MaDuAn IN (
        SELECT MaDuAn
        FROM ChuyenGia_DuAn
        GROUP BY MaDuAn
        HAVING COUNT(MaChuyenGia) < (
            SELECT SoLuongChuyenGiaYeuCau
            FROM DuAn
            WHERE DuAn.MaDuAn = ChuyenGia_DuAn.MaDuAn
        )
    )
    AND TrangThai <> 'Hoàn thành';
END;


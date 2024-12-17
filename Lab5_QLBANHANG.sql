--11.
--Ngày mua hàng (NGHD) của một khách hàng thành viên sẽ lớn hơn hoặc bằng ngày khách hàng đó 
--đăng ký thành viên (NGDK).

CREATE TRIGGER TRG_CHECKNGDK
ON HOADON
AFTER INSERT
AS BEGIN
		IF EXISTS	(SELECT *
				FROM INSERTED, KHACHHANG KH
				WHERE INSERTED.MAKH = KH.MAKH
				AND NGDK > NGHD
					)
		BEGIN
			RAISERROR('LOI: NGAY HOA DON KHONG HOP LE!', 16, 1);
			ROLLBACK;
		END
	END

--12.
--Ngày bán hàng (NGHD) của một nhân viên phải lớn hơn hoặc bằng ngày nhân viên đó vào làm.

CREATE TRIGGER trg_CheckNgHD
ON HOADON
FOR INSERT
AS BEGIN
		IF EXISTS (SELECT *
			FROM INSERTED, NHANVIEN
			WHERE INSERTED.MANV = NHANVIEN.MANV
			AND NGHD > NGVL)
		BEGIN
			RAISERROR('LOI: NGAY HOA DON KHONG HOP LE!', 16, 1);
			ROLLBACK TRANSACTION
		END
		ELSE
		BEGIN
			PRINT 'THEM MOT HOA DON THANH CONG!'
		END
	END

--13. Trị giá của một hóa đơn là tổng thành tiền (số lượng*đơn giá) của các chi tiết thuộc hóa đơn đó.

CREATE TRIGGER trg_UpdateTRIGIA
ON CTHD
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE HOADON
    SET TRIGIA = (
        SELECT SUM(C.SL * S.GIA)
        FROM CTHD C
        JOIN SANPHAM S ON C.MASP = S.MASP
        WHERE C.SOHD = I.SOHD
    )
    FROM inserted I
    WHERE HOADON.SOHD = I.SOHD;

    UPDATE HOADON
    SET TRIGIA = (
        SELECT SUM(C.SL * S.GIA)
        FROM CTHD C
        JOIN SANPHAM S ON C.MASP = S.MASP
        WHERE C.SOHD = D.SOHD
    )
    FROM deleted D
    WHERE HOADON.SOHD = D.SOHD;

    UPDATE HOADON
    SET TRIGIA = (
        SELECT SUM(C.SL * S.GIA)
        FROM CTHD C
        JOIN SANPHAM S ON C.MASP = S.MASP
        WHERE C.SOHD = U.SOHD
    )
    FROM inserted U
    WHERE HOADON.SOHD = U.SOHD;
END;


--14. Doanh số của một khách hàng là tổng trị giá các hóa đơn mà khách hàng thành viên đó đã mua.

CREATE TRIGGER trg_UpdateDoanhSo
ON HOADON
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE KHACHHANG
    SET DOANHSO = (
        SELECT SUM(H.TRIGIA)
        FROM HOADON H
        WHERE H.MAKH = I.MAKH
    )
    FROM inserted I
    WHERE KHACHHANG.MAKH = I.MAKH;

    UPDATE KHACHHANG
    SET DOANHSO = (
        SELECT SUM(H.TRIGIA)
        FROM HOADON H
        WHERE H.MAKH = D.MAKH
    )
    FROM deleted D
    WHERE KHACHHANG.MAKH = D.MAKH;

    UPDATE KHACHHANG
    SET DOANHSO = (
        SELECT SUM(H.TRIGIA)
        FROM HOADON H
        WHERE H.MAKH = U.MAKH
    )
    FROM inserted U
    WHERE KHACHHANG.MAKH = U.MAKH;
END;



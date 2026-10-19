# Nhật ký sử dụng AI

## Câu hỏi 1: Covering Index là gì?

**Câu hỏi đã tìm hiểu:** Covering Index là gì và vì sao nó có thể làm truy vấn `SELECT` nhanh hơn?

**Nội dung ghi nhận:** Covering Index là chỉ mục chứa cả các cột dùng để tìm kiếm và các cột cần trả về trong câu `SELECT`. Khi đó, MySQL có thể lấy kết quả ngay từ index mà không cần đọc lại bản ghi đầy đủ trong bảng. Cách này giảm số lần truy cập dữ liệu, nhưng làm cho index lớn hơn và tốn nhiều chi phí bảo trì hơn.

## Câu hỏi 2: Clustered Index và Secondary Index

**Câu hỏi đã tìm hiểu:** InnoDB lưu dữ liệu trong khóa chính và chỉ mục phụ như thế nào?

**Nội dung ghi nhận:** Với InnoDB, dữ liệu của bảng được tổ chức theo Clustered Index của khóa chính. Secondary Index lưu các cột đã lập chỉ mục cùng với giá trị khóa chính. Nếu câu truy vấn không được bao phủ hoàn toàn bởi Secondary Index, MySQL phải dùng khóa chính để quay lại lấy phần dữ liệu còn thiếu trong bảng gốc.

## Câu hỏi 3: Write Penalty

**Câu hỏi đã tìm hiểu:** Vì sao thêm nhiều cột vào index làm thao tác `INSERT` chậm hơn?

**Nội dung ghi nhận:** Mỗi khi thêm một bản ghi, MySQL phải cập nhật cả bảng và các Secondary Index liên quan. Index càng rộng thì càng cần nhiều page để lưu trữ, nhiều dữ liệu phải ghi vào RAM và ổ đĩa, đồng thời có thể phát sinh page split và redo log. Đây chính là write penalty của việc tạo index quá lớn.

## Câu hỏi 4: Thiết kế Lean Index

**Câu hỏi đã tìm hiểu:** Trong bài SmartFactory nên giữ lại những cột nào trong index?

**Nội dung ghi nhận:** Câu truy vấn Dashboard lọc theo `sensor_id` và `recorded_at`, vì vậy chỉ nên tạo index trên hai cột này:

```sql
(sensor_id, recorded_at)
```

Các cột `temperature`, `humidity` và `status` chỉ là dữ liệu cần hiển thị, không cần đưa vào index nếu ưu tiên chính của hệ thống là tốc độ ghi và tiết kiệm dung lượng.

## Câu hỏi 5: Kiểm tra bằng EXPLAIN

**Câu hỏi đã tìm hiểu:** Cần nhìn vào đâu trong kết quả `EXPLAIN` sau khi thay index?

**Nội dung ghi nhận:** Cột `key` cần hiển thị `idx_lean_search` và cột `type` vẫn nên là `range` hoặc `ref`. Với index mới không còn bao phủ toàn bộ câu truy vấn, phần `Extra` không còn `Using index`; trong lần chạy thực tế của bài, MySQL hiển thị `Using index condition`. Điều này cho thấy index vẫn được dùng để lọc, sau đó dữ liệu chi tiết được lấy từ bảng gốc.

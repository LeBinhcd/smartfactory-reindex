# Báo cáo tối ưu chỉ mục cho SmartFactory

## 1. Phân tích vấn đề

Ban đầu, bảng `SensorLogs` sử dụng chỉ mục `idx_fat_covering` gồm các cột `sensor_id`, `recorded_at`, `temperature`, `humidity` và `status`. Cách làm này giúp truy vấn trên Dashboard nhanh vì MySQL có thể lấy đủ dữ liệu ngay trong cây chỉ mục mà không cần quay lại bảng gốc. Đây là trường hợp thường được gọi là **Covering Index**.

Tuy nhiên, SmartFactory là hệ thống nhận dữ liệu liên tục từ cảm biến. Mỗi bản ghi mới không chỉ được thêm vào bảng mà còn phải được thêm vào chỉ mục phụ. Vì chỉ mục cũ chứa quá nhiều cột, mỗi phần tử trong cây B-Tree trở nên lớn hơn, cần nhiều page lưu trữ hơn và tốn thêm RAM, thao tác ghi, redo log cũng như chi phí backup. Như vậy, tốc độ đọc được cải thiện nhưng tốc độ ghi và dung lượng lưu trữ bị ảnh hưởng nghiêm trọng.

Các cột `temperature`, `humidity` và `status` là dữ liệu kết quả cần trả về, không phải dữ liệu dùng để lọc trong câu truy vấn Dashboard. Vì vậy, việc đưa toàn bộ các cột này vào index là không cần thiết.

## 2. Thiết kế chỉ mục mới

Tôi thay thế chỉ mục cũ bằng:

```sql
CREATE INDEX idx_lean_search
ON SensorLogs(sensor_id, recorded_at);
```

Hai cột này đủ để MySQL tìm đúng cảm biến và giới hạn khoảng thời gian cần xem. Sau khi tìm được các dòng phù hợp, InnoDB sẽ đọc thêm `temperature`, `humidity` và `status` từ bảng gốc thông qua khóa chính.

Đổi lại, truy vấn sẽ không còn được bao phủ hoàn toàn bởi index. Tuy nhiên, với hệ thống có hàng chục nghìn bản ghi ghi vào mỗi giây, việc giảm kích thước index và giảm chi phí cập nhật khi `INSERT` là quan trọng hơn việc tiết kiệm một lần đọc bảng.

## 3. Kết quả kiểm tra

Script được chạy trên MySQL 8.0.46 với khoảng 10.000 bản ghi mẫu.

| Trạng thái | Data (MB) | Index (MB) | Tổng (MB) |
|---|---:|---:|---:|
| Có fat covering index | 0.02 | 0.00 | 0.02 |
| Có lean search index | 0.02 | 0.00 | 0.02 |

Do bảng thử nghiệm còn nhỏ và số liệu được làm tròn, `INDEX_LENGTH` chưa thể hiện sự khác biệt rõ ràng. Trên bảng thực tế có hàng triệu bản ghi, phần chênh lệch sẽ dễ quan sát hơn.

Kết quả `EXPLAIN` cho thấy:

| Trạng thái | Type | Key | Extra |
|---|---|---|---|
| Index cũ | range | `idx_fat_covering` | `Using where; Using index` |
| Index mới | range | `idx_lean_search` | `Using index condition` |

Sau tối ưu, truy vấn vẫn sử dụng index với kiểu `range`, nhưng không còn `Using index`. Điều này đúng với mục tiêu của bài vì dữ liệu nhiệt độ, độ ẩm và trạng thái đã được lấy từ bảng gốc thay vì lưu thêm trong index.

## 4. Kết luận

Covering Index không phải lúc nào cũng xấu. Với bảng nhỏ, ít thay đổi và chủ yếu phục vụ đọc, nó có thể giúp truy vấn nhanh hơn. Nhưng với bảng dữ liệu cảm biến liên tục phát sinh bản ghi, index quá lớn sẽ tạo ra write penalty, làm tăng thời gian `INSERT`, dung lượng RAM và chi phí ổ đĩa. Chỉ mục tinh gọn `(sensor_id, recorded_at)` phù hợp hơn với bài toán SmartFactory vì cân bằng được tốc độ đọc, tốc độ ghi và chi phí lưu trữ.

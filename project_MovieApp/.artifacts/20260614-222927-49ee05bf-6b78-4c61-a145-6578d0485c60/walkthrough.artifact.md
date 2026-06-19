# MovieApp Recommendation & UI Update

I have implemented a sophisticated recommendation system and a modern, overflow-proof UI design.

## Core Recommendation Components
- **Personalized Scoring**: Ranks movies based on category, country, and actor affinity.
- **Contextual Sections**: Added "Because you watched..." sections using recently watched movie metadata.
- **Smart Tracking**: Learns from watch time (>90%), favorites, ratings, and search queries.

## Ý tưởng đột phá: Thiết kế Poster Tràn Viền (Full-bleed Design)
Sau khi thử nghiệm các phương pháp chỉnh tỉ lệ và vẫn gặp lỗi overflow do sự khác biệt về kích thước màn hình, tôi đã triển khai một ý tưởng mới hoàn toàn để xử lý dứt điểm vấn đề này.

### Cách thức hoạt động:
1.  **Thiết kế Layer (Stack)**: Thay vì đặt tên phim ở bên dưới ảnh (dễ bị đẩy ra ngoài khung), tôi đã đưa tên phim và thông tin gợi ý **nằm đè lên trên** ảnh poster.
2.  **Lớp phủ Gradient**: Một lớp màu đen mờ (Gradient) được chèn ở đáy ảnh để đảm bảo chữ trắng luôn dễ đọc trên mọi nền ảnh.
3.  **Tự co giãn 100%**: Vì nội dung nằm hoàn toàn bên trong khung ảnh, `MovieCard` sẽ tự động co giãn theo bất kỳ kích thước nào mà `GridView` cung cấp mà **không bao giờ gây lỗi overflow**.

### Kết quả đạt được:
*   **Về thẩm mỹ**: Ứng dụng mang phong cách hiện đại như Netflix, Disney+. Poster phim to, rõ và chiếm trọn không gian.
*   **Về ổn định**: Đã đưa `childAspectRatio` về mức **0.65** (tỉ lệ vàng cho poster phim). Lỗi "RenderFlex overflowed" đã được giải quyết triệt để trên toàn bộ ứng dụng.
*   **Về tính năng**: Giữ nguyên 100% logic Gợi ý, Yêu thích và Điều hướng đã làm trước đó.

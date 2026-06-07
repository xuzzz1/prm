# Movie Reviews Implementation Plan

Implement a simple movie review system using Firebase Realtime Database. Each logged-in user can submit one review (rating + comment) per movie, which can be updated later.

## Proposed Changes

### [Models]

#### [review.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/models/review.dart) [NEW]
- Define the `Review` class with fields: `userId`, `userName`, `userEmail`, `rating`, `comment`, and `timestamp`.
- Include `fromJson` and `toJson` methods for Firebase integration.

---

### [Providers]

#### [review_provider.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/providers/review_provider.dart) [NEW]
- Implement `ReviewProvider` extending `ChangeNotifier`.
- Method `fetchReviews(String movieSlug)`: Listen to realtime updates from `reviews/{movieSlug}`.
- Method `addOrUpdateReview(String movieSlug, double rating, String comment, User user)`: Save data to `reviews/{movieSlug}/{user.uid}`.
- Properties to store current movie reviews and loading state.

#### [main.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/main.dart)
- Register `ReviewProvider` in the `MultiProvider` block.

---

### [Screens]

#### [movie_detail_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/movie_detail_screen.dart)
- Update the "Đánh giá" tab to display the list of reviews.
- Add a "Viết đánh giá" button (or "Chỉnh sửa" if already reviewed).
- Show a dialog/bottom sheet with `RatingBar` and a `TextField` for submitting reviews.
- Update the tab label to show the total number of reviews (e.g., "Đánh giá (12)").

## Verification Plan

### Manual Verification
1. Open a movie detail screen.
2. Navigate to the "Đánh giá" tab.
3. Verify reviews are loaded (initially empty).
4. Log in as a user.
5. Click "Viết đánh giá", select stars, enter text, and submit.
6. Verify the review appears in the list and in Firebase Console.
7. Click "Chỉnh sửa", change the rating/text, and verify it updates instead of duplicating.
8. Log in as a different user and submit another review; verify both appear.

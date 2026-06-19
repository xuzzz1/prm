# Admin Features Implementation Plan

This plan outlines the implementation of core admin functionalities: Home Banner Management, Category Management, and Movie Addition via Slug.

## Proposed Changes

### Admin Service & Provider

#### [NEW] [admin_service.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/services/admin_service.dart)
- Handle Firebase Realtime Database operations for admin tasks.
- Methods: `addBanner(String slug)`, `removeBanner(String slug)`, `addCategory(String name)`, `deleteCategory(String id)`.

#### [NEW] [admin_provider.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/providers/admin_provider.dart)
- State management for admin features.
- Keep track of banner movies, categories, and loading states.

### UI Components

#### [admin_home_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/admin/admin_home_screen.dart)
- Update the "Phim" tab to include:
    - **Banner Management**: Add/Remove movie slugs for the home slider.
    - **Quick Add**: Input field for slug to fetch and save movie info.
- Implement the "Người dùng" tab (basic list).
- Implement the "Thể loại" management (can be part of the "Phim" tab or a new tab).

---

## Verification Plan

### Manual Verification
- Add a movie slug to the "Banner" list and verify it appears on the User Home Screen.
- Add a new category and verify it appears in the Category screen for users.
- Use the "Quick Add" feature with a valid slug from `phimapi.com` and verify the movie is added to the system.

# Movie Reviews Walkthrough

Implemented a complete movie review system integrated with Firebase Realtime Database.

## Changes Made

### Models
- Created [review.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/models/review.dart) to structure review data.

### Providers
- Created [review_provider.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/providers/review_provider.dart) to handle Realtime Database operations.
- Registered the provider in [main.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/main.dart).

### Screens
- Updated [movie_detail_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/movie_detail_screen.dart):
    - Added realtime review list display.
    - Implemented a "Write Review" / "Edit Review" button logic.
    - Created a modal bottom sheet for submitting ratings and comments using `flutter_rating_bar`.
    - Integrated `intl` for date formatting.

### Dependencies
- Added `intl: ^0.19.0` to [pubspec.yaml](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/pubspec.yaml).

## Verification Results
- Reviewed code for accuracy and resolved minor syntax issues.
- Added dependency `intl` to fix build errors related to date formatting.
- Ensured UI responsiveness and proper tab label updates.

# Fix RenderFlex Overflow in Recommendation System

The "RenderFlex overflowed by 24 pixels on the bottom" error likely occurs because the addition of recommendation content (like `matchReason` in `MovieCard` or longer movie titles in section headers) has exceeded the fixed height constraints in horizontal lists or the fixed aspect ratio in `GridView`s.

## User Review Required
- I will increase the height of movie carousels from 230 to 260.
- I will adjust the `childAspectRatio` in `GridView`s to provide more vertical space for movie titles and metadata.

## Proposed Changes

### UI Layout & Styling

#### [home_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/home_screen.dart)
- Increase the height of `SizedBox` containers for all horizontal movie lists from `230` to `260` to accommodate varied content and the new recommendation reasons.
- Add `maxLines: 1` and `overflow: TextOverflow.ellipsis` to the movie title in `_buildSectionTitle` to prevent long titles from pushing content down excessively.

#### [movie_card.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/widgets/movie_card.dart)
- Reduce the hardcoded `imageHeight` from `145` to `140` (or make it more flexible) to ensure the card fits within standard `GridView` cell heights on smaller devices.

#### [favorite_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/favorite_screen.dart)
- Update `childAspectRatio` from `0.6` to `0.55` to give each card more vertical breathing room.

#### [movie_detail_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/movie_detail_screen.dart)
- Update `childAspectRatio` in `_buildRelatedTab` from `0.6` to `0.55`.

#### [search_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/user/search_screen.dart)
- Update `childAspectRatio` in `_buildSearchResults` from `0.6` to `0.55`.

## Verification Plan

### Manual Verification
- Run the app and navigate to the Home screen. Check all horizontal carousels for overflow stripes.
- Navigate to the "Yêu thích" tab and verify the grid items don't overflow.
- Search for a movie and verify the search results grid.
- Open a movie detail page, go to the "Liên quan" tab, and verify the grid items.
- Test on different screen sizes (or by resizing the window if using Flutter web/desktop) to ensure responsiveness.

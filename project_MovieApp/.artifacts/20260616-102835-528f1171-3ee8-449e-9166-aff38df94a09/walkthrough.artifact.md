# Walkthrough - Admin Role Implementation

I have implemented the Admin role and navigation functionality.

## Changes Made

### Auth Provider
- Updated [auth_provider.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/providers/auth_provider.dart) to:
    - Handle user roles from Firebase Realtime Database.
    - Automatically recognize `admin@gmail.com` as an admin.
    - Support "admin" shorthand in the login field, which maps to `admin@gmail.com`.
    - Save default 'user' role to Database upon registration.

### Admin Home Screen
- Created [admin_home_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/admin/admin_home_screen.dart) providing a dashboard for administrative tasks.

### Login Screen
- Updated [login_screen.dart](file:///C:/Users/Admin/Desktop/prm/prm_git/project_MovieApp/lib/screens/auth/login_screen.dart) to navigate users based on their role:
    - `admin` -> `AdminHomeScreen`
    - `user` -> `HomeScreen`

## How to use Admin Account
1. Open the Login screen.
2. Enter `admin` in the Email field.
3. Enter `123456` (or your chosen password) in the Password field.
4. Click **ĐĂNG NHẬP**.

> [!NOTE]
> Make sure you have already created a Firebase account with email `admin@gmail.com` and password `123456` in your Firebase Console for this to work.

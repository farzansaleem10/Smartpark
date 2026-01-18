# Smart Parking Flutter App

Flutter mobile application for Smart Parking Management System.

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Update API base URL in `lib/services/api_service.dart`:
   ```dart
   // For Android Emulator:
   static const String baseUrl = 'http://10.0.2.2:5000/api';
   
   // For iOS Simulator:
   static const String baseUrl = 'http://localhost:5000/api';
   
   // For Physical Device:
   // Use your computer's IP address
   static const String baseUrl = 'http://192.168.x.x:5000/api';
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                  # Data models
│   ├── user.dart
│   ├── parking.dart
│   └── booking.dart
├── screens/                 # UI Screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── parking/
│   │   ├── parking_list_screen.dart
│   │   └── parking_details_screen.dart
│   ├── bookings/
│   │   ├── booking_screen.dart
│   │   ├── booking_confirmation_screen.dart
│   │   ├── booking_history_screen.dart
│   │   └── qr_code_screen.dart
│   ├── owner/
│   │   ├── owner_dashboard_screen.dart
│   │   ├── add_parking_screen.dart
│   │   └── edit_parking_screen.dart
│   └── admin/
│       └── admin_dashboard_screen.dart
├── services/               # API Services
│   ├── api_service.dart
│   └── auth_service.dart
└── widgets/               # Reusable widgets
```

## Features

### User Features
- Login/Register with role selection
- Search parking by location
- View nearby parking spaces
- View parking details
- Book parking slots
- View QR code for check-in
- Booking history

### Owner Features
- Add parking spaces
- Edit parking details
- View owned parking spaces
- Owner dashboard

### Admin Features
- Verify parking spaces
- View all parkings
- Admin dashboard

## Dependencies

- `http` - API calls
- `provider` - State management
- `shared_preferences` - Local storage
- `qr_flutter` - QR code generation
- `geolocator` - Location services
- `intl` - Date formatting
- `google_fonts` - Typography

## UI Design

- Material 3 Design
- Consistent color theme
- Rounded cards and buttons
- Responsive layout
- Loading and error states

## Screens

1. **Splash Screen** - Initial loading
2. **Login Screen** - User authentication
3. **Register Screen** - New user registration
4. **Home Screen** - List of parking spaces
5. **Parking Details** - Detailed parking information
6. **Booking Screen** - Create booking
7. **Booking Confirmation** - Booking success
8. **QR Code Screen** - Digital check-in
9. **Booking History** - Past bookings
10. **Owner Dashboard** - Manage parkings
11. **Admin Dashboard** - Verify parkings

## State Management

Using Provider for:
- Authentication state
- User data
- API responses

## API Integration

All API calls are handled through `ApiService` class:
- Automatic token management
- Error handling
- Response parsing

## Permissions

Required permissions:
- Location (for finding nearby parkings)
- Internet (for API calls)

## Notes

- Update API base URL based on your platform
- Ensure backend is running before testing
- For physical devices, use computer's IP address

# Smart Parking Management System

A complete full-stack Smart Parking Management System built with Flutter (frontend) and Node.js/Express (backend) with MongoDB database.

## 🏗️ Architecture

- **Frontend**: Flutter (Dart) - Material 3 Design
- **Backend**: Node.js with Express
- **Database**: MongoDB
- **Communication**: REST APIs using HTTP and JSON

## 📁 Project Structure

```
SmartPark/
├── backend/                 # Node.js/Express Backend
│   ├── models/             # MongoDB Models
│   ├── routes/             # API Routes
│   ├── middleware/         # Authentication Middleware
│   ├── server.js          # Main server file
│   └── package.json        # Dependencies
│
└── frontend/               # Flutter Frontend
    ├── lib/
    │   ├── models/        # Data Models
    │   ├── screens/       # UI Screens
    │   ├── services/      # API Services
    │   └── widgets/        # Reusable Widgets
    └── pubspec.yaml       # Flutter Dependencies
```

## 🚀 Features

### User Features
- User registration and authentication (JWT)
- Search parking by location
- View nearby parking spaces with distance
- View parking details (price, availability, amenities)
- Book parking slots with time selection
- QR code for digital check-in
- Booking history
- Ratings and reviews

### Owner Features
- Register parking spaces
- Manage parking details (slots, price)
- View owned parking spaces
- Dashboard for parking management

### Admin Features
- Verify parking spaces
- View all parking spaces
- Manage users and bookings
- Admin dashboard

## 📋 Prerequisites

- Node.js (v14 or higher)
- MongoDB (local or cloud instance)
- Flutter SDK (v3.0 or higher)
- Dart SDK

## 🔧 Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Create `.env` file:**
   ```bash
   cp .env.example .env
   ```

4. **Configure environment variables in `.env`:**
   ```
   PORT=5000
   MONGODB_URI=mongodb://localhost:27017/smartparking
   JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
   JWT_EXPIRE=7d
   ```

5. **Start MongoDB:**
   - If using local MongoDB, make sure it's running
   - Or use MongoDB Atlas (cloud) and update `MONGODB_URI` in `.env`

6. **Start the server:**
   ```bash
   npm start
   ```
   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

   The server will run on `http://localhost:5000`

## 📱 Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Update API base URL:**
   - Open `lib/services/api_service.dart`
   - Update the `baseUrl` constant:
     ```dart
     // For Android Emulator:
     static const String baseUrl = 'http://10.0.2.2:5000/api';
     
     // For iOS Simulator:
     static const String baseUrl = 'http://localhost:5000/api';
     
     // For Physical Device:
     // Use your computer's IP address
     static const String baseUrl = 'http://192.168.x.x:5000/api';
     ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## 🗄️ Database Schema

### Users
- name, email, password, phone, role (user/owner/admin)

### Parking
- name, description, address, location (lat/lng), totalSlots, availableSlots, pricePerHour, amenities, rating

### Bookings
- user, parking, slotNumber, startTime, endTime, duration, totalPrice, status, qrCode

### Reviews
- user, parking, booking, rating, comment

## 📡 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user

### Parking
- `GET /api/parking` - Get all parking spaces (with filters)
- `GET /api/parking/:id` - Get single parking
- `POST /api/parking` - Create parking (Owner)
- `PUT /api/parking/:id` - Update parking (Owner)
- `GET /api/parking/owner/my-parkings` - Get owner's parkings
- `PUT /api/parking/:id/verify` - Verify parking (Admin)
- `GET /api/parking/:id/availability` - Check availability

### Bookings
- `POST /api/bookings` - Create booking
- `GET /api/bookings` - Get user's bookings
- `GET /api/bookings/:id` - Get single booking
- `PUT /api/bookings/:id/checkin` - Check in
- `PUT /api/bookings/:id/checkout` - Check out
- `PUT /api/bookings/:id/cancel` - Cancel booking

### Reviews
- `POST /api/reviews` - Create review
- `GET /api/reviews/parking/:parkingId` - Get parking reviews
- `GET /api/reviews` - Get user's reviews

## 🎨 UI Features

- Material 3 Design
- Consistent color theme (blue/green)
- Rounded cards and buttons
- Responsive layout
- Loading and error states
- Clean, modern interface

## 🔐 Authentication

- JWT-based authentication
- Role-based access control (user, owner, admin)
- Secure password hashing with bcrypt

## 📝 Notes

- All code is production-ready and well-commented
- No placeholders or "add later" sections
- Suitable for college projects
- Clean, readable, and maintainable code

## 🐛 Troubleshooting

### Backend Issues
- Ensure MongoDB is running
- Check `.env` file configuration
- Verify port 5000 is not in use

### Frontend Issues
- Update API base URL for your platform
- Ensure backend is running
- Check network permissions in Android/iOS

### Database Connection
- Verify MongoDB URI in `.env`
- Check MongoDB service status
- For cloud MongoDB, whitelist your IP address

## 📄 License

This project is created for educational purposes.

## 👨‍💻 Development

For development:
- Backend: Use `npm run dev` for auto-reload
- Frontend: Use `flutter run` with hot reload enabled

## 🎯 Future Enhancements

- Payment gateway integration
- Push notifications
- Real-time slot updates
- Advanced analytics
- Multi-language support

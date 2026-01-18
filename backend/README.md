# Smart Parking Backend API

Node.js/Express backend for Smart Parking Management System.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create `.env` file:
   ```
   PORT=5000
   MONGODB_URI=mongodb://localhost:27017/smartparking
   JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
   JWT_EXPIRE=7d
   ```

3. Start MongoDB (local or use MongoDB Atlas)

4. Run server:
   ```bash
   npm start
   ```
   Or for development:
   ```bash
   npm run dev
   ```

## API Documentation

### Base URL
`http://localhost:5000/api`

### Authentication Endpoints

#### Register
- **POST** `/auth/register`
- Body: `{ name, email, password, phone?, role? }`
- Returns: `{ success, data: { user, token } }`

#### Login
- **POST** `/auth/login`
- Body: `{ email, password }`
- Returns: `{ success, data: { user, token } }`

#### Get Current User
- **GET** `/auth/me`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { user } }`

### Parking Endpoints

#### Get All Parkings
- **GET** `/parking?latitude=&longitude=&radius=&city=&search=`
- Returns: `{ success, count, data: { parkings } }`

#### Get Single Parking
- **GET** `/parking/:id`
- Returns: `{ success, data: { parking } }`

#### Create Parking (Owner)
- **POST** `/parking`
- Headers: `Authorization: Bearer <token>`
- Body: `{ name, description?, address, location, totalSlots, pricePerHour, ... }`
- Returns: `{ success, data: { parking } }`

#### Update Parking (Owner)
- **PUT** `/parking/:id`
- Headers: `Authorization: Bearer <token>`
- Body: `{ name?, description?, totalSlots?, pricePerHour?, ... }`
- Returns: `{ success, data: { parking } }`

#### Get My Parkings (Owner)
- **GET** `/parking/owner/my-parkings`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, count, data: { parkings } }`

#### Verify Parking (Admin)
- **PUT** `/parking/:id/verify`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { parking } }`

#### Check Availability
- **GET** `/parking/:id/availability?startTime=&endTime=`
- Returns: `{ success, data: { totalSlots, availableSlots, bookedSlots } }`

### Booking Endpoints

#### Create Booking
- **POST** `/bookings`
- Headers: `Authorization: Bearer <token>`
- Body: `{ parking, startTime, endTime, paymentMethod? }`
- Returns: `{ success, data: { booking } }`

#### Get My Bookings
- **GET** `/bookings`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, count, data: { bookings } }`

#### Get Single Booking
- **GET** `/bookings/:id`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { booking } }`

#### Check In
- **PUT** `/bookings/:id/checkin`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { booking } }`

#### Check Out
- **PUT** `/bookings/:id/checkout`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { booking } }`

#### Cancel Booking
- **PUT** `/bookings/:id/cancel`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, data: { booking } }`

### Review Endpoints

#### Create Review
- **POST** `/reviews`
- Headers: `Authorization: Bearer <token>`
- Body: `{ parking, booking, rating, comment? }`
- Returns: `{ success, data: { review } }`

#### Get Parking Reviews
- **GET** `/reviews/parking/:parkingId`
- Returns: `{ success, count, data: { reviews } }`

#### Get My Reviews
- **GET** `/reviews`
- Headers: `Authorization: Bearer <token>`
- Returns: `{ success, count, data: { reviews } }`

## Models

### User
- `_id`, `name`, `email`, `password`, `phone`, `role`, `avatar`, `isVerified`, `createdAt`, `updatedAt`

### Parking
- `_id`, `name`, `description`, `owner`, `address`, `location`, `totalSlots`, `availableSlots`, `pricePerHour`, `images`, `amenities`, `operatingHours`, `isActive`, `isVerified`, `rating`, `createdAt`, `updatedAt`

### Booking
- `_id`, `user`, `parking`, `slotNumber`, `startTime`, `endTime`, `duration`, `totalPrice`, `status`, `qrCode`, `checkInTime`, `checkOutTime`, `paymentStatus`, `paymentMethod`, `createdAt`, `updatedAt`

### Review
- `_id`, `user`, `parking`, `booking`, `rating`, `comment`, `createdAt`, `updatedAt`

## Error Handling

All errors return:
```json
{
  "success": false,
  "message": "Error message"
}
```

## Authentication

Include JWT token in headers:
```
Authorization: Bearer <token>
```

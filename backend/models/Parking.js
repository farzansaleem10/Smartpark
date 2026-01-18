const mongoose = require('mongoose');

const parkingSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please provide parking name'],
    trim: true,
  },
  description: {
    type: String,
    trim: true,
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  address: {
    street: { type: String, required: true },
    city: { type: String, required: true },
    state: { type: String, required: true },
    zipCode: { type: String, required: true },
    country: { type: String, default: 'India' },
  },
  location: {
    latitude: {
      type: Number,
      required: true,
      min: -90,
      max: 90,
    },
    longitude: {
      type: Number,
      required: true,
      min: -180,
      max: 180,
    },
  },
  totalSlots: {
    type: Number,
    required: true,
    min: 1,
  },
  availableSlots: {
    type: Number,
    required: true,
    min: 0,
  },
  pricePerHour: {
    type: Number,
    required: true,
    min: 0,
  },
  images: [{
    type: String,
  }],
  amenities: [{
    type: String,
  }],
  operatingHours: {
    open: { type: String, default: '00:00' },
    close: { type: String, default: '23:59' },
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  isVerified: {
    type: Boolean,
    default: false,
  },
  rating: {
    average: { type: Number, default: 0, min: 0, max: 5 },
    count: { type: Number, default: 0 },
  },
}, {
  timestamps: true,
});

// Index for geospatial queries
parkingSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Parking', parkingSchema);

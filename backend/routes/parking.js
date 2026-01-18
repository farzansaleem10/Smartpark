const express = require('express');
const { body, validationResult } = require('express-validator');
const Parking = require('../models/Parking');
const Booking = require('../models/Booking');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

/**
 * @route   GET /api/parking
 * @desc    Get all parking spaces (with optional location filter)
 * @access  Public
 */
router.get('/', async (req, res) => {
  try {
    const { latitude, longitude, radius = 5000, city, search } = req.query;
    
    let query = { isActive: true };
    
    // Add city filter if provided
    if (city) {
      query['address.city'] = new RegExp(city, 'i');
    }
    
    // Add search filter if provided
    if (search) {
      query.$or = [
        { name: new RegExp(search, 'i') },
        { description: new RegExp(search, 'i') },
        { 'address.street': new RegExp(search, 'i') },
      ];
    }
    
    let parkings = await Parking.find(query).populate('owner', 'name email');
    
    // If location provided, calculate distance and filter by radius
    if (latitude && longitude) {
      const userLat = parseFloat(latitude);
      const userLng = parseFloat(longitude);
      const radiusKm = parseFloat(radius) / 1000; // Convert to km
      
      parkings = parkings
        .map(parking => {
          const distance = calculateDistance(
            userLat,
            userLng,
            parking.location.latitude,
            parking.location.longitude
          );
          return { ...parking.toObject(), distance };
        })
        .filter(parking => parking.distance <= radiusKm)
        .sort((a, b) => a.distance - b.distance);
    }
    
    res.json({
      success: true,
      count: parkings.length,
      data: { parkings },
    });
  } catch (error) {
    console.error('Get parkings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/parking/:id
 * @desc    Get single parking space
 * @access  Public
 */
router.get('/:id', async (req, res) => {
  try {
    const parking = await Parking.findById(req.params.id).populate('owner', 'name email phone');
    
    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking space not found',
      });
    }
    
    res.json({
      success: true,
      data: { parking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   POST /api/parking
 * @desc    Create new parking space (Owner only)
 * @access  Private/Owner
 */
router.post('/', authenticate, authorize('owner', 'admin'), [
  body('name').notEmpty().withMessage('Parking name is required'),
  body('address.street').notEmpty().withMessage('Street address is required'),
  body('address.city').notEmpty().withMessage('City is required'),
  body('location.latitude').isFloat().withMessage('Valid latitude is required'),
  body('location.longitude').isFloat().withMessage('Valid longitude is required'),
  body('totalSlots').isInt({ min: 1 }).withMessage('Total slots must be at least 1'),
  body('pricePerHour').isFloat({ min: 0 }).withMessage('Price per hour must be valid'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array(),
      });
    }
    
    const parkingData = {
      ...req.body,
      owner: req.user._id,
      availableSlots: req.body.totalSlots,
    };
    
    const parking = await Parking.create(parkingData);
    
    res.status(201).json({
      success: true,
      message: 'Parking space created successfully',
      data: { parking },
    });
  } catch (error) {
    console.error('Create parking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/parking/:id
 * @desc    Update parking space (Owner only)
 * @access  Private/Owner
 */
router.put('/:id', authenticate, async (req, res) => {
  try {
    const parking = await Parking.findById(req.params.id);
    
    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking space not found',
      });
    }
    
    // Check if user is owner or admin
    if (parking.owner.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this parking',
      });
    }
    
    // Don't allow updating owner
    delete req.body.owner;
    
    const updatedParking = await Parking.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    
    res.json({
      success: true,
      message: 'Parking space updated successfully',
      data: { parking: updatedParking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/parking/owner/my-parkings
 * @desc    Get all parkings owned by current user
 * @access  Private/Owner
 */
router.get('/owner/my-parkings', authenticate, authorize('owner', 'admin'), async (req, res) => {
  try {
    const parkings = await Parking.find({ owner: req.user._id });
    
    res.json({
      success: true,
      count: parkings.length,
      data: { parkings },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/parking/:id/verify
 * @desc    Verify parking space (Admin only)
 * @access  Private/Admin
 */
router.put('/:id/verify', authenticate, authorize('admin'), async (req, res) => {
  try {
    const parking = await Parking.findByIdAndUpdate(
      req.params.id,
      { isVerified: true },
      { new: true }
    );
    
    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking space not found',
      });
    }
    
    res.json({
      success: true,
      message: 'Parking space verified successfully',
      data: { parking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/parking/:id/availability
 * @desc    Check parking availability for a time slot
 * @access  Public
 */
router.get('/:id/availability', async (req, res) => {
  try {
    const { startTime, endTime } = req.query;
    
    if (!startTime || !endTime) {
      return res.status(400).json({
        success: false,
        message: 'Start time and end time are required',
      });
    }
    
    const parking = await Parking.findById(req.params.id);
    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking space not found',
      });
    }
    
    // Find overlapping bookings
    const overlappingBookings = await Booking.find({
      parking: req.params.id,
      status: { $in: ['confirmed', 'active'] },
      $or: [
        {
          startTime: { $lt: new Date(endTime) },
          endTime: { $gt: new Date(startTime) },
        },
      ],
    });
    
    const bookedSlots = overlappingBookings.length;
    const availableSlots = parking.totalSlots - bookedSlots;
    
    res.json({
      success: true,
      data: {
        totalSlots: parking.totalSlots,
        availableSlots: Math.max(0, availableSlots),
        bookedSlots,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

// Helper function to calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  return distance;
}

module.exports = router;

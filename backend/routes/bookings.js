const express = require('express');
const { body, validationResult } = require('express-validator');
const Booking = require('../models/Booking');
const Parking = require('../models/Parking');
const QRCode = require('qrcode');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/bookings
 * @desc    Create a new booking
 * @access  Private
 */
router.post('/', [
  body('parking').notEmpty().withMessage('Parking ID is required'),
  body('startTime').notEmpty().withMessage('Start time is required'),
  body('endTime').notEmpty().withMessage('End time is required'),
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
    
    const { parking: parkingId, startTime, endTime, paymentMethod } = req.body;
    
    // Get parking details
    const parking = await Parking.findById(parkingId);
    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking space not found',
      });
    }
    
    if (!parking.isVerified) {
      return res.status(400).json({
        success: false,
        message: 'Parking space is not verified yet',
      });
    }
    
    const start = new Date(startTime);
    const end = new Date(endTime);
    
    if (end <= start) {
      return res.status(400).json({
        success: false,
        message: 'End time must be after start time',
      });
    }
    
    // Check for overlapping bookings
    const overlappingBookings = await Booking.find({
      parking: parkingId,
      status: { $in: ['confirmed', 'active'] },
      $or: [
        {
          startTime: { $lt: end },
          endTime: { $gt: start },
        },
      ],
    });
    
    if (overlappingBookings.length >= parking.totalSlots) {
      return res.status(400).json({
        success: false,
        message: 'No available slots for the selected time',
      });
    }
    
    // Calculate duration and price
    const duration = (end - start) / (1000 * 60 * 60); // in hours
    const totalPrice = duration * parking.pricePerHour;
    
    // Assign slot number (simple logic - can be improved)
    const bookedSlots = overlappingBookings.map(b => b.slotNumber);
    let slotNumber = 1;
    while (bookedSlots.includes(slotNumber) && slotNumber <= parking.totalSlots) {
      slotNumber++;
    }
    
    if (slotNumber > parking.totalSlots) {
      return res.status(400).json({
        success: false,
        message: 'No available slots',
      });
    }
    
    // Generate QR code data
    const qrData = JSON.stringify({
      bookingId: `temp_${Date.now()}`,
      parkingId: parkingId,
      userId: req.user._id,
      startTime: start.toISOString(),
      endTime: end.toISOString(),
    });
    
    // Create booking
    const booking = await Booking.create({
      user: req.user._id,
      parking: parkingId,
      slotNumber,
      startTime: start,
      endTime: end,
      duration,
      totalPrice,
      paymentMethod: paymentMethod || 'cash',
      status: 'confirmed',
    });
    
    // Generate QR code
    const qrCode = await QRCode.toDataURL(JSON.stringify({
      bookingId: booking._id.toString(),
      parkingId: parkingId,
      userId: req.user._id.toString(),
      startTime: start.toISOString(),
      endTime: end.toISOString(),
    }));
    
    booking.qrCode = qrCode;
    await booking.save();
    
    // Update parking available slots
    parking.availableSlots = Math.max(0, parking.availableSlots - 1);
    await parking.save();
    
    // Populate booking details
    await booking.populate('parking', 'name address location');
    await booking.populate('user', 'name email');
    
    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      data: { booking },
    });
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/bookings
 * @desc    Get all bookings for current user
 * @access  Private
 */
router.get('/', async (req, res) => {
  try {
    const bookings = await Booking.find({ user: req.user._id })
      .populate('parking', 'name address location pricePerHour')
      .sort({ createdAt: -1 });
    
    res.json({
      success: true,
      count: bookings.length,
      data: { bookings },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/bookings/:id
 * @desc    Get single booking
 * @access  Private
 */
router.get('/:id', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('parking', 'name address location pricePerHour')
      .populate('user', 'name email');
    
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }
    
    // Check if user owns this booking or is admin
    if (booking.user._id.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized',
      });
    }
    
    res.json({
      success: true,
      data: { booking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/bookings/:id/checkin
 * @desc    Check in to parking
 * @access  Private
 */
router.put('/:id/checkin', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }
    
    if (booking.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized',
      });
    }
    
    if (booking.status !== 'confirmed') {
      return res.status(400).json({
        success: false,
        message: 'Booking is not in confirmed status',
      });
    }
    
    booking.status = 'active';
    booking.checkInTime = new Date();
    await booking.save();
    
    res.json({
      success: true,
      message: 'Checked in successfully',
      data: { booking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/bookings/:id/checkout
 * @desc    Check out from parking
 * @access  Private
 */
router.put('/:id/checkout', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }
    
    if (booking.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized',
      });
    }
    
    if (booking.status !== 'active') {
      return res.status(400).json({
        success: false,
        message: 'Booking is not active',
      });
    }
    
    booking.status = 'completed';
    booking.checkOutTime = new Date();
    booking.paymentStatus = 'paid';
    await booking.save();
    
    // Update parking available slots
    const parking = await Parking.findById(booking.parking);
    if (parking) {
      parking.availableSlots = Math.min(parking.totalSlots, parking.availableSlots + 1);
      await parking.save();
    }
    
    res.json({
      success: true,
      message: 'Checked out successfully',
      data: { booking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/bookings/:id/cancel
 * @desc    Cancel a booking
 * @access  Private
 */
router.put('/:id/cancel', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }
    
    if (booking.user.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized',
      });
    }
    
    if (['completed', 'cancelled'].includes(booking.status)) {
      return res.status(400).json({
        success: false,
        message: 'Cannot cancel this booking',
      });
    }
    
    booking.status = 'cancelled';
    await booking.save();
    
    // Update parking available slots
    const parking = await Parking.findById(booking.parking);
    if (parking) {
      parking.availableSlots = Math.min(parking.totalSlots, parking.availableSlots + 1);
      await parking.save();
    }
    
    res.json({
      success: true,
      message: 'Booking cancelled successfully',
      data: { booking },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

module.exports = router;

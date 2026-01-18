const express = require('express');
const { body, validationResult } = require('express-validator');
const Review = require('../models/Review');
const Booking = require('../models/Booking');
const Parking = require('../models/Parking');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/reviews
 * @desc    Create a review
 * @access  Private
 */
router.post('/', [
  body('parking').notEmpty().withMessage('Parking ID is required'),
  body('booking').notEmpty().withMessage('Booking ID is required'),
  body('rating').isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
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
    
    const { parking: parkingId, booking: bookingId, rating, comment } = req.body;
    
    // Verify booking belongs to user and is completed
    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }
    
    if (booking.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to review this booking',
      });
    }
    
    if (booking.status !== 'completed') {
      return res.status(400).json({
        success: false,
        message: 'Can only review completed bookings',
      });
    }
    
    // Check if review already exists
    const existingReview = await Review.findOne({ booking: bookingId });
    if (existingReview) {
      return res.status(400).json({
        success: false,
        message: 'Review already exists for this booking',
      });
    }
    
    // Create review
    const review = await Review.create({
      user: req.user._id,
      parking: parkingId,
      booking: bookingId,
      rating,
      comment,
    });
    
    // Update parking rating
    const parking = await Parking.findById(parkingId);
    if (parking) {
      const reviews = await Review.find({ parking: parkingId });
      const totalRating = reviews.reduce((sum, r) => sum + r.rating, 0);
      parking.rating.average = totalRating / reviews.length;
      parking.rating.count = reviews.length;
      await parking.save();
    }
    
    await review.populate('user', 'name');
    
    res.status(201).json({
      success: true,
      message: 'Review created successfully',
      data: { review },
    });
  } catch (error) {
    console.error('Create review error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/reviews/parking/:parkingId
 * @desc    Get all reviews for a parking
 * @access  Public
 */
router.get('/parking/:parkingId', async (req, res) => {
  try {
    const reviews = await Review.find({ parking: req.params.parkingId })
      .populate('user', 'name avatar')
      .sort({ createdAt: -1 });
    
    res.json({
      success: true,
      count: reviews.length,
      data: { reviews },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/reviews
 * @desc    Get all reviews by current user
 * @access  Private
 */
router.get('/', async (req, res) => {
  try {
    const reviews = await Review.find({ user: req.user._id })
      .populate('parking', 'name address')
      .populate('booking')
      .sort({ createdAt: -1 });
    
    res.json({
      success: true,
      count: reviews.length,
      data: { reviews },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

module.exports = router;

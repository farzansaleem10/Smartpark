const express = require('express');
const router = express.Router();
const Booking = require('../models/Booking');
const Parking = require('../models/Parking');
const { authenticate } = require('../middleware/auth');

// All routes here require authentication
router.use(authenticate);

/**
 * @route   GET /api/owner/parkings
 * @desc    Get all parkings owned by the current user
 * @access  Private/Owner
 */
router.get('/parkings', async (req, res) => {
  try {
    const parkings = await Parking.find({ owner: req.user._id }).sort({ createdAt: -1 });
    
    res.json({
      success: true,
      data: { parkings }
    });
  } catch (error) {
    console.error('Owner parkings error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * @route   GET /api/owner/earnings
 * @desc    Get earnings statistics for owner dashboard
 * @access  Private/Owner
 */
router.get('/earnings', async (req, res) => {
  try {
    // 1. Find all parking lots owned by this user
    const parkings = await Parking.find({ owner: req.user._id });
    const parkingIds = parkings.map(p => p._id);

    // 2. Fetch all valid bookings for these parkings
    const bookings = await Booking.find({
      parking: { $in: parkingIds },
      status: { $nin: ['cancelled'] } // Ignore cancelled bookings
    });

    // 3. Set up Date boundaries
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const sevenDaysAgo = new Date(startOfToday.getTime() - 6 * 24 * 60 * 60 * 1000);

    let today = 0;
    let monthly = 0;
    let yearly = 0;
    
    // Map for the chart (last 7 days)
    const dailyMap = {};
    for(let i = 6; i >= 0; i--) {
        const d = new Date(startOfToday.getTime() - i * 24 * 60 * 60 * 1000);
        const dateStr = `${d.getDate()}/${d.getMonth() + 1}`; // e.g., "15/4"
        dailyMap[dateStr] = 0;
    }

    // 4. Calculate totals
    bookings.forEach(b => {
      const date = new Date(b.createdAt);
      const price = b.totalPrice || 0;

      if (date >= startOfToday) today += price;
      if (date >= startOfMonth) monthly += price;
      if (date >= startOfYear) yearly += price;

      // Add to daily chart if within last 7 days
      if (date >= sevenDaysAgo) {
        const dayStr = `${date.getDate()}/${date.getMonth() + 1}`;
        if (dailyMap[dayStr] !== undefined) {
          dailyMap[dayStr] += price;
        }
      }
    });

    // Convert map to array for Flutter
    const dailyEarnings = Object.keys(dailyMap).map(key => ({
      date: key,
      earnings: dailyMap[key]
    }));

    res.json({
      success: true,
      data: { today, monthly, yearly, dailyEarnings }
    });
  } catch (error) {
    console.error('Owner earnings error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * @route   GET /api/owner/analytics
 * @desc    Get booking counts for owner dashboard
 * @access  Private/Owner
 */
router.get('/analytics', async (req, res) => {
  try {
    // 1. Find all parking lots owned by this user
    const parkings = await Parking.find({ owner: req.user._id });
    const parkingIds = parkings.map(p => p._id);

    // 2. Fetch all valid bookings for these parkings
    const bookings = await Booking.find({
      parking: { $in: parkingIds },
      status: { $nin: ['cancelled'] }
    });

    // 3. Set up Date boundaries
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const sevenDaysAgo = new Date(startOfToday.getTime() - 6 * 24 * 60 * 60 * 1000);

    let today = 0;
    let monthly = 0;
    let yearly = 0;

    // Map for the chart (last 7 days)
    const dailyMap = {};
    for(let i = 6; i >= 0; i--) {
        const d = new Date(startOfToday.getTime() - i * 24 * 60 * 60 * 1000);
        const dateStr = `${d.getDate()}/${d.getMonth() + 1}`;
        dailyMap[dateStr] = 0;
    }

    // 4. Calculate totals
    bookings.forEach(b => {
      const date = new Date(b.createdAt);

      if (date >= startOfToday) today += 1;
      if (date >= startOfMonth) monthly += 1;
      if (date >= startOfYear) yearly += 1;

      // Add to daily chart if within last 7 days
      if (date >= sevenDaysAgo) {
        const dayStr = `${date.getDate()}/${date.getMonth() + 1}`;
        if (dailyMap[dayStr] !== undefined) {
          dailyMap[dayStr] += 1;
        }
      }
    });

    // Convert map to array for Flutter
    const dailyBookings = Object.keys(dailyMap).map(key => ({
      date: key,
      count: dailyMap[key]
    }));

    res.json({
      success: true,
      data: { today, monthly, yearly, dailyBookings }
    });
  } catch (error) {
    console.error('Owner analytics error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
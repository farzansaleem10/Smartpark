const express = require('express');
const { body, validationResult } = require('express-validator');
const Parking = require('../models/Parking');
const Booking = require('../models/Booking');
const User = require('../models/User');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(authorize('admin'));

/**
 * @route   GET /api/admin/parking-requests
 * @desc    Get all parking registration requests
 * @access  Private/Admin
 */
router.get('/parking-requests', async (req, res) => {
  try {
    const { status } = req.query;
    let query = {};
    
    // Filter by approval status if provided
    if (status) {
      query.approvalStatus = status;
    } else {
      // Default: show pending requests
      query.approvalStatus = 'pending';
    }

    const parkings = await Parking.find(query)
      .populate('owner', 'name email phone')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: parkings.length,
      data: { parkings },
    });
  } catch (error) {
    console.error('Get parking requests error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/admin/parking-requests/:id
 * @desc    Get single parking request with documents
 * @access  Private/Admin
 */
router.get('/parking-requests/:id', async (req, res) => {
  try {
    const parking = await Parking.findById(req.params.id)
      .populate('owner', 'name email phone');

    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking request not found',
      });
    }

    res.json({
      success: true,
      data: { parking },
    });
  } catch (error) {
    console.error('Get parking request error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/admin/parking-requests/:id/approve
 * @desc    Approve parking registration
 * @access  Private/Admin
 */
router.put('/parking-requests/:id/approve', async (req, res) => {
  try {
    const parking = await Parking.findById(req.params.id);

    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking request not found',
      });
    }

    parking.approvalStatus = 'approved';
    parking.isVerified = true;
    parking.rejectionReason = '';
    await parking.save();

    res.json({
      success: true,
      message: 'Parking registration approved successfully',
      data: { parking },
    });
  } catch (error) {
    console.error('Approve parking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   PUT /api/admin/parking-requests/:id/reject
 * @desc    Reject parking registration
 * @access  Private/Admin
 */
router.put('/parking-requests/:id/reject', [
  body('reason').optional().trim(),
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

    const parking = await Parking.findById(req.params.id);

    if (!parking) {
      return res.status(404).json({
        success: false,
        message: 'Parking request not found',
      });
    }

    parking.approvalStatus = 'rejected';
    parking.isVerified = false;
    parking.rejectionReason = req.body.reason || 'Registration rejected by admin';
    await parking.save();

    res.json({
      success: true,
      message: 'Parking registration rejected successfully',
      data: { parking },
    });
  } catch (error) {
    console.error('Reject parking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/admin/analytics
 * @desc    Get dashboard analytics
 * @access  Private/Admin
 */
router.get('/analytics', async (req, res) => {
  try {
    // Get all completed bookings
    const allBookings = await Booking.find({ 
      status: { $in: ['completed', 'active'] },
      paymentStatus: { $in: ['paid', 'pending'] }
    })
      .populate({
        path: 'parking',
        select: 'owner name',
        populate: {
          path: 'owner',
          select: 'name email'
        }
      })
      .populate('user', 'name email');

    // Calculate total income from all parking locations
    const totalIncome = allBookings.reduce((sum, booking) => {
      return sum + (booking.totalPrice || 0);
    }, 0);

    // Calculate income per parking owner
    const incomePerOwner = {};
    allBookings.forEach(booking => {
      // Handle both populated and non-populated owner references
      let ownerId = null;
      let ownerName = 'Unknown';
      
      if (booking.parking) {
        if (booking.parking.owner && typeof booking.parking.owner === 'object') {
          // Owner is populated
          ownerId = booking.parking.owner._id?.toString() || booking.parking.owner.id?.toString();
          ownerName = booking.parking.owner.name || 'Unknown';
        } else if (booking.parking.owner) {
          // Owner is just an ID
          ownerId = booking.parking.owner.toString();
        }
      }
      
      if (ownerId) {
        if (!incomePerOwner[ownerId]) {
          incomePerOwner[ownerId] = {
            ownerId: ownerId,
            ownerName: ownerName,
            totalIncome: 0,
            parkingCount: 0,
            bookingsCount: 0,
          };
        }
        incomePerOwner[ownerId].totalIncome += booking.totalPrice || 0;
        incomePerOwner[ownerId].bookingsCount += 1;
      }
    });

    // Get owner details for income breakdown
    const ownerIds = Object.keys(incomePerOwner);
    let owners = [];
    if (ownerIds.length > 0) {
      owners = await User.find({ _id: { $in: ownerIds }, role: 'owner' })
        .select('name email phone');
    }

    // Enrich income per owner with owner details
    const incomeBreakdown = Object.values(incomePerOwner).map(item => {
      const owner = owners.find(o => o._id.toString() === item.ownerId);
      return {
        ...item,
        ownerName: owner?.name || item.ownerName,
        ownerEmail: owner?.email || '',
        ownerPhone: owner?.phone || '',
      };
    });

    // Count total bookings till date
    const totalBookings = await Booking.countDocuments({});

    // Count parking spaces
    const totalParkingSpaces = await Parking.countDocuments({ approvalStatus: 'approved' });

    // Count total users
    const totalUsers = await User.countDocuments({ role: 'user' });
    const totalOwners = await User.countDocuments({ role: 'owner' });

    res.json({
      success: true,
      data: {
        totalIncome,
        incomeBreakdown,
        totalBookings,
        totalParkingSpaces,
        totalUsers,
        totalOwners,
      },
    });
  } catch (error) {
    console.error('Get analytics error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/admin/users
 * @desc    Get all registered customers with booking history
 * @access  Private/Admin
 */
router.get('/users', async (req, res) => {
  try {
    const customers = await User.find({ role: 'user' })
      .select('-password')
      .sort({ createdAt: -1 });

    // Get booking history for each customer
    const usersWithBookings = await Promise.all(
      customers.map(async (customer) => {
        const bookings = await Booking.find({ user: customer._id })
          .populate('parking', 'name address location pricePerHour')
          .sort({ createdAt: -1 });

        const totalBookings = bookings.length;
        const totalSpent = bookings.reduce((sum, booking) => {
          return sum + (booking.totalPrice || 0);
        }, 0);

        return {
          ...customer.toObject(),
          bookingHistory: bookings,
          totalBookings,
          totalSpent,
        };
      })
    );

    res.json({
      success: true,
      count: usersWithBookings.length,
      data: { users: usersWithBookings },
    });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

/**
 * @route   GET /api/admin/users/:id/bookings
 * @desc    Get booking history for a specific customer
 * @access  Private/Admin
 */
router.get('/users/:id/bookings', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (!user || user.role !== 'user') {
      return res.status(404).json({
        success: false,
        message: 'Customer not found',
      });
    }

    const bookings = await Booking.find({ user: req.params.id })
      .populate('parking', 'name address location pricePerHour owner')
      .populate('user', 'name email phone')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: bookings.length,
      data: {
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          phone: user.phone,
        },
        bookings,
      },
    });
  } catch (error) {
    console.error('Get user bookings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

module.exports = router;

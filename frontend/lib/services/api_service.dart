import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:5000/api';
  // static const String baseUrl =  'http://10.0.2.2:5000/api';
  // For iOS simulator, use: http://localhost:5000/api
  // For physical device, use your computer's IP: http://192.168.x.x:5000/api

  // Get auth token from storage
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Set auth token in storage
  static Future<void> _setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Remove auth token from storage
  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // Get headers with auth token
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'An error occurred');
    }
  }

  // AUTH ENDPOINTS
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _getHeaders(includeAuth: false),
      body: json.encode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      }),
    );

    final data = _handleResponse(response);
    if (data['success'] && data['data']?['token'] != null) {
      await _setToken(data['data']['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(includeAuth: false),
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    final data = _handleResponse(response);
    if (data['success'] && data['data']?['token'] != null) {
      await _setToken(data['data']['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<void> logout() async {
    await _removeToken();
  }

  // PARKING ENDPOINTS
  static Future<Map<String, dynamic>> getParkings({
    double? latitude,
    double? longitude,
    double? radius,
    String? city,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (latitude != null) queryParams['latitude'] = latitude.toString();
    if (longitude != null) queryParams['longitude'] = longitude.toString();
    if (radius != null) queryParams['radius'] = radius.toString();
    if (city != null) queryParams['city'] = city;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/parking').replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: await _getHeaders(includeAuth: false),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getParking(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/parking/$id'),
      headers: await _getHeaders(includeAuth: false),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createParking(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/parking'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateParking(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/parking/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getMyParkings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/parking/owner/my-parkings'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> checkAvailability({
    required String parkingId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final queryParams = {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };

    final uri = Uri.parse('$baseUrl/parking/$parkingId/availability')
        .replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: await _getHeaders(includeAuth: false),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> verifyParking(String parkingId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/parking/$parkingId/verify'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  // BOOKING ENDPOINTS
  static Future<Map<String, dynamic>> createBooking({
    required String parkingId,
    required DateTime startTime,
    required DateTime endTime,
    String? paymentMethod,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: await _getHeaders(),
      body: json.encode({
        'parking': parkingId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'paymentMethod': paymentMethod ?? 'cash',
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getBookings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/bookings'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getBooking(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bookings/$id'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> checkIn(String bookingId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId/checkin'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> checkOut(String bookingId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId/checkout'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  // REVIEW ENDPOINTS
  static Future<Map<String, dynamic>> createReview({
    required String parkingId,
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reviews'),
      headers: await _getHeaders(),
      body: json.encode({
        'parking': parkingId,
        'booking': bookingId,
        'rating': rating,
        'comment': comment,
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getParkingReviews(String parkingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reviews/parking/$parkingId'),
      headers: await _getHeaders(includeAuth: false),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getMyReviews() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reviews'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }
}

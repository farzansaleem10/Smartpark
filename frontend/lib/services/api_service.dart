import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:5000/api' ;
  // static const String baseUrl =  'http://10.0.2.2:5000/api';emulator
  // For iOS simulator, use: http://localhost:5000/api
  //  static const String baseUrl = 'http://192.168.20.11:5000/api';
  
  // Get auth token from storage
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> _setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

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

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'An error occurred');
    }
  }

  // ================= AUTH =================

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
    String? email,
    String? username,
    required String password,
  }) async {
    final Map<String, dynamic> body = {
      'password': password,
    };

    if (username != null && username.isNotEmpty) {
      body['username'] = username;
    } else if (email != null && email.isNotEmpty) {
      body['email'] = email;
    } else {
      throw Exception('Email or username is required');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(includeAuth: false),
      body: json.encode(body),
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

  // ================= PARKINGS =================

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

  static Future<Map<String, dynamic>> getParkingDetails(String parkingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/parking/$parkingId/details'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteParking(String parkingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/parking/$parkingId'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createParking(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/parking');
    final request = http.MultipartRequest('POST', uri);

    // 1. Get auth headers, but REMOVE the JSON Content-Type. 
    // MultipartRequest needs to set its own special "multipart/form-data" header.
    final headers = await _getHeaders();
    headers.remove('Content-Type'); 
    request.headers.addAll(headers);

    // 2. Loop through the data and attach everything to the Multipart form
    for (var entry in data.entries) {
      if (entry.key == 'licenseDocument' && entry.value != null && entry.value.toString().isNotEmpty) {
        // ATTACH THE PHYSICAL FILE
        request.files.add(
          await http.MultipartFile.fromPath('licenseDocument', entry.value.toString()),
        );
      } else if (entry.value is Map) {
        // FLATTEN NESTED OBJECTS (like 'address' and 'location')
        // Multipart forms don't support nested JSON natively, so we convert them to 'address.street'
        final map = entry.value as Map;
        map.forEach((subKey, subValue) {
          if (subValue != null) {
            request.fields['${entry.key}.$subKey'] = subValue.toString();
          }
        });
      } else if (entry.value != null) {
        // ATTACH NORMAL TEXT FIELDS
        request.fields[entry.key] = entry.value.toString();
      }
    }

    // 3. Send the file and data to the server
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }
static Future<Map<String, dynamic>> updateParking(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/parking/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
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
  // ================= BOOKINGS =================

  static Future<Map<String, dynamic>> createBooking({
    required String parkingId,
    required DateTime startTime,
    required DateTime endTime,
    String? customerName,
    required String vehicleNumber,
    String? phoneNumber,
    required int slotNumber,
    String? paymentMethod,
  }) async {
    final Map<String, dynamic> body = {
      'parking': parkingId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'paymentMethod': paymentMethod ?? 'cash',
      'vehicleNumber': vehicleNumber,
      'slotNumber': slotNumber,
    };

    if (customerName != null) body['customerName'] = customerName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;

    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: await _getHeaders(),
      body: json.encode(body),
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

  static Future<Map<String, dynamic>> deleteBooking(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bookings/$bookingId'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getOwnerBookings(String parkingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/owner?parkingId=$parkingId'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> createManualBooking({
    required String parkingId,
    required int slotNumber,
    required String customerName,
    required String vehicleNumber,
    required String phoneNumber,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/manual'),
        headers: await _getHeaders(),
        body: json.encode({
          'parkingId': parkingId,
          'slotNumber': slotNumber,
          'customerName': customerName,
          'vehicleNumber': vehicleNumber,
          'phoneNumber': phoneNumber,
          'startTime': startTime,
          'endTime': endTime,
        }),
      );

      if (response.statusCode == 404) {
        final bookingResponse = await createBooking(
          parkingId: parkingId,
          startTime: DateTime.parse(startTime),
          endTime: DateTime.parse(endTime),
          customerName: customerName,
          vehicleNumber: vehicleNumber,
          phoneNumber: phoneNumber,
          slotNumber: slotNumber,
          paymentMethod: 'cash',
        );

        return bookingResponse;
      }

      return _handleResponse(response);
    } catch (e) {
      try {
        final bookingResponse = await createBooking(
          parkingId: parkingId,
          startTime: DateTime.parse(startTime),
          endTime: DateTime.parse(endTime),
          customerName: customerName,
          vehicleNumber: vehicleNumber,
          phoneNumber: phoneNumber,
          slotNumber: slotNumber,
          paymentMethod: 'cash',
        );

        return bookingResponse;
      } catch (bookingError) {
        return {
          'success': false,
          'message': e.toString().replaceAll('Exception: ', ''),
        };
      }
    }
  }

  // ================= ADMIN FUNCTIONS =================

  static Future<Map<String, dynamic>> getParkingRequests({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/admin/parking-requests').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> approveParkingRequest(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/parking-requests/$id/approve'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> rejectParkingRequest(String id, {String? reason}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/parking-requests/$id/reject'),
      headers: await _getHeaders(),
      body: json.encode({'reason': reason}),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getAdminAnalytics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/analytics'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateUserStatus(String userId, bool isActive) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/status'),
        headers: await _getHeaders(),
        body: json.encode({'isActive': isActive}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ================= OWNER DASHBOARD =================

  static Future<Map<String, dynamic>> getOwnerParkings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/owner/parkings'),
      headers: await _getHeaders(),
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

  static Future<Map<String, dynamic>> getOwnerEarnings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/owner/earnings'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getOwnerAnalytics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/owner/analytics'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }
}
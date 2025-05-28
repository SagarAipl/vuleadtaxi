import 'package:flutter/material.dart';
import 'package:location/location.dart' as location_pkg;
import 'package:permission_handler/permission_handler.dart' as permission_handler_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Placeholder imports for other screens - ensure these files exist
import 'BookingsScreen.dart';
import 'LoginScreen.dart';
import 'ProfileScreen.dart';
import 'WalletScreen.dart';

// Constants for reusability
class AppConstants {
  static const Color backgroundColor = Color(0xFF333333);
  static const Color accentColor = Color(0xFFF5A623);
  static const Color skipButtonColor = Color(0xFF8EACC1);
  static const Color textColor = Colors.white;
  static const Color subtitleColor = Colors.white70;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOnline = false;
  String _userName = '';
  String _authToken = '';
  int _userId = 0;
  double _todaysEarnings = 79.94;
  int _todaysTrips = 5;
  double _avgRating = 4.4;
  String _rideStatus = 'none'; // none, accepted, started, ended

  // Google Maps related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng _currentLatLng = const LatLng(37.7749, -122.4194); // Default to San Francisco

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _toggleController;
  late Animation<double> _toggleAnimation;

  // Location related variables
  location_pkg.Location? location;
  location_pkg.LocationData? _currentLocation;
  Timer? _locationTimer;
  Timer? _rideCheckTimer;
  Timer? _rideAcceptTimer;
  bool _isLocationServiceEnabled = false;
  bool _isUpdatingLocation = false;
  bool _isLoading = true;
  String _locationError = '';
  String _currentLocationName = 'Getting location...';

  // Ride request variables
  Map<String, dynamic>? _latestRide;
  bool _isCheckingRides = false;
  bool _hasNewRideRequest = false;
  bool _isProcessingRide = false;
  int _rideAcceptCountdown = 60;
  int _notificationCount = 0;

  // Google Maps Directions API key (replace with your actual API key)
  final String _googleApiKey = 'AIzaSyD7H64TGlewo8dC_0EEvP754TtvUy2pMmY'; // Replace with your API key

  final List<Widget> _screens = [
    const SizedBox(), // Placeholder, will be replaced by home content
    const BookingsScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _toggleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _toggleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toggleController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _toggleController.dispose();
    _locationTimer?.cancel();
    _rideCheckTimer?.cancel();
    _rideAcceptTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadUserData();
      await _initializeLocationWithFallback();
    } catch (e) {
      print('Error initializing app: $e');
      _showError('Failed to initialize app: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('auth_token') ?? '';
      final userId = prefs.getInt('u_id') ?? 0;
      final userName = prefs.getString('u_name') ?? 'Driver';

      if (mounted) {
        setState(() {
          _authToken = token;
          _userId = userId;
          _userName = userName;
          _isOnline = false;
        });
      }

      await prefs.setBool('is_driver_online', false);
      await prefs.setString('availability_status', 'offline');

      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn || _authToken.isEmpty) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
        return;
      }

      print('Loaded auth token: $_authToken');
      print('User ID: $_userId');
      print('Driver status: OFFLINE (default)');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showProfessionalSnackBar(
              'Welcome back, $_userName! Ready to start your day?',
              AppConstants.accentColor,
              Icons.waving_hand,
            );
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      throw e;
    }
  }

  Future<void> _initializeLocationWithFallback() async {
    try {
      location = location_pkg.Location();
      await _initializeLocation();
    } catch (e) {
      print('Location plugin error: $e');
      try {
        await _initializeLocationWithPermissionHandler();
      } catch (fallbackError) {
        print('Fallback location initialization failed: $fallbackError');
        setState(() {
          _locationError = 'Location services unavailable: $fallbackError';
          _isLocationServiceEnabled = false;
        });
        _showError('Location services are not available on this device');
      }
    }
  }

  Future<void> _initializeLocation() async {
    if (location == null) {
      throw Exception('Location plugin not initialized');
    }

    try {
      bool serviceEnabled = await location!.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location!.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service is disabled');
        }
      }

      location_pkg.PermissionStatus permissionGranted = await location!.hasPermission();
      if (permissionGranted == location_pkg.PermissionStatus.denied) {
        permissionGranted = await location!.requestPermission();
        if (permissionGranted != location_pkg.PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = true;
          _locationError = '';
        });
      }

      await _getCurrentLocation();
    } catch (e) {
      print('Error initializing location: $e');
      throw e;
    }
  }

  Future<void> _initializeLocationWithPermissionHandler() async {
    try {
      var status = await permission_handler_pkg.Permission.location.status;

      if (status.isDenied) {
        status = await permission_handler_pkg.Permission.location.request();
      }

      if (status.isPermanentlyDenied) {
        throw Exception('Location permission permanently denied. Please enable in settings.');
      }

      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _isLocationServiceEnabled = true;
            _locationError = '';
          });
        }
        await _getMockLocation();
      } else {
        throw Exception('Location permission not granted');
      }
    } catch (e) {
      print('Permission handler error: $e');
      throw e;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (location == null) {
      await _getMockLocation();
      return;
    }

    try {
      location_pkg.LocationData locationData = await location!.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = locationData;
          _currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);
        });
        _updateMapLocation();
      }
      await _getLocationName(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      print('Error getting current location: $e');
      await _getMockLocation();
    }
  }

  Future<void> _getMockLocation() async {
    if (mounted) {
      setState(() {
        _currentLocation = location_pkg.LocationData.fromMap({
          'latitude': 37.7749,
          'longitude': -122.4194,
          'accuracy': 10.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speedAccuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
        _currentLocationName = 'San Francisco, CA (Mock Location)';
        _currentLatLng = const LatLng(37.7749, -122.4194);
      });
      _updateMapLocation();
    }
    _showError('Using mock location. Please enable location services for accurate positioning.');
  }

  void _updateMapLocation() {
    if (_mapController != null && _currentLocation != null) {
      final LatLng newPosition = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);

      _mapController!.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );

      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: newPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Your Location',
              snippet: _currentLocationName,
            ),
          ),
        );
      });
    }
  }

  Future<void> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locationName = '';

        if (place.street != null && place.street!.isNotEmpty) {
          locationName += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (locationName.isNotEmpty) locationName += ', ';
          locationName += place.locality!;
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (locationName.isNotEmpty) locationName += ', ';
          locationName += place.administrativeArea!;
        }

        if (locationName.isEmpty) {
          locationName = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
        }

        if (mounted) {
          setState(() {
            _currentLocationName = locationName;
          });
        }
      }
    } catch (e) {
      print('Error getting location name: $e');
      if (mounted) {
        setState(() {
          _currentLocationName = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  Future<void> _fetchRouteAndDrawPolylines(int rideId) async {
    if (_latestRide == null || _currentLocation == null) return;

    try {
      final pickupLat = _parseCoordinate(_latestRide!['ride']['Pick_location']['latitude']);
      final pickupLng = _parseCoordinate(_latestRide!['ride']['Pick_location']['longitude']);
      final dropoffLat = _parseCoordinate(_latestRide!['ride']['Drop_location']['latitude']);
      final dropoffLng = _parseCoordinate(_latestRide!['ride']['Drop_location']['longitude']);
      final driverLat = _currentLocation!.latitude!;
      final driverLng = _currentLocation!.longitude!;

      List<LatLng> points = [];

      if (_rideStatus == 'accepted') {
        // Show route from driver to pickup
        points = await _getRouteCoordinates(
          LatLng(driverLat, driverLng),
          LatLng(pickupLat, pickupLng),
        );
      } else if (_rideStatus == 'started') {
        // Show route from pickup to dropoff
        points = await _getRouteCoordinates(
          LatLng(pickupLat, pickupLng),
          LatLng(dropoffLat, dropoffLng),
        );
      }

      if (mounted) {
        setState(() {
          _polylines.clear();
          if (points.isNotEmpty) {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('current_route'),
                color: AppConstants.accentColor,
                width: 5,
                points: points,
              ),
            );
          }

          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: LatLng(driverLat, driverLng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(title: 'Your Location', snippet: _currentLocationName),
            ),
          );

          if (_rideStatus == 'accepted' || _rideStatus == 'started') {
            _markers.add(
              Marker(
                markerId: const MarkerId('pickup_location'),
                position: LatLng(pickupLat, pickupLng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'Pickup Location'),
              ),
            );
          }

          if (_rideStatus == 'started') {
            _markers.add(
              Marker(
                markerId: const MarkerId('dropoff_location'),
                position: LatLng(dropoffLat, dropoffLng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: 'Drop-off Location'),
              ),
            );
          }
        });

        if (points.isNotEmpty) {
          final bounds = _getBounds(points);
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        }
      }
    } catch (e) {
      print('Error fetching route: $e');
      _showError('Unable to fetch route: $e');
    }
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          return _decodePolyline(encodedPolyline);
        } else {
          throw Exception('Directions API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _getRouteCoordinates: $e');
      throw e;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylinePoints;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double south = points[0].latitude;
    double north = points[0].latitude;
    double west = points[0].longitude;
    double east = points[0].longitude;

    for (var point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _clearPolylines() {
    if (mounted) {
      setState(() {
        _polylines.clear();
        _markers.removeWhere((marker) => marker.markerId != const MarkerId('current_location'));
      });
    }
  }

  void _showError(String message) {
    _showProfessionalSnackBar(message, Colors.red.shade700, Icons.error_outline);
  }

  void _showProfessionalSnackBar(String message, Color color, IconData icon) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: AppConstants.textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textColor,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _updateDriverLocation() async {
    if (_authToken.isEmpty) {
      _showError('Authentication token not found. Please login again.');
      _logout();
      return;
    }

    if (_currentLocation == null) {
      await _getCurrentLocation();
      if (_currentLocation == null) {
        _showError('Unable to get current location');
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isUpdatingLocation = true;
      });
    }

    try {
      final payload = {
        'location': {
          'lat': _currentLocation!.latitude.toString(),
          'lng': _currentLocation!.longitude.toString(),
        },
        'availability_status': _isOnline ? 'online' : 'offline',
      };

      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/driver/update-location'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_driver_online', _isOnline);
        await prefs.setString('availability_status', _isOnline ? 'online' : 'offline');
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to update location';
          _showError('Failed to update location: $errorMessage');
        } catch (e) {
          _showError('Failed to update location. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      _showError('Request timeout. Please check your internet connection.');
    } catch (e) {
      print('Error updating location: $e');
      _showError('Network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  Future<void> _checkForRideRequests() async {
    if (_authToken.isEmpty || !_isOnline || _rideStatus != 'none' || _isProcessingRide) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingRides = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/rides'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['rides'] != null) {
          Map<String, dynamic>? latestRide;
          DateTime? latestTime;
          final now = DateTime.now();
          const threeMinutes = Duration(minutes: 3);

          for (var rideData in responseData['rides']) {
            if (rideData['status'] != 'pending') {
              continue;
            }

            if (rideData['nearby_drivers'] != null) {
              bool isDriverNearby = false;
              for (var driver in rideData['nearby_drivers']) {
                if (driver['U_Id'] == _userId) {
                  isDriverNearby = true;
                  break;
                }
              }

              if (isDriverNearby) {
                try {
                  DateTime rideTime = DateTime.parse(rideData['ride']['created_at']);
                  // Check if the ride is within the last 3 minutes
                  if (now.difference(rideTime) <= threeMinutes) {
                    if (latestTime == null || rideTime.isAfter(latestTime)) {
                      latestTime = rideTime;
                      latestRide = rideData;
                    }
                  }
                } catch (e) {
                  print('Error parsing ride time: $e');
                  // Fallback to selecting the ride if no other valid ride is found
                  if (latestRide == null) {
                    latestRide = rideData;
                  }
                }
              }
            }
          }

          bool hasNewRequest = latestRide != null &&
              (_latestRide == null || latestRide['ride']['id'] != _latestRide!['ride']['id']);

          if (mounted) {
            setState(() {
              _latestRide = latestRide;
              _hasNewRideRequest = hasNewRequest && latestRide != null;
              if (hasNewRequest && latestRide != null) {
                _notificationCount = 1; // Only one notification for the latest ride
                _startRideAcceptTimer();
                _slideController.forward(from: 0.0);
              } else {
                _rideAcceptTimer?.cancel();
                _rideAcceptCountdown = 60;
                _notificationCount = 0;
                _clearPolylines();
                _hasNewRideRequest = false;
                _latestRide = null; // Reset to ensure no stale rides
              }
            });
          }
        } else {
          // No rides available, reset state
          if (mounted) {
            setState(() {
              _latestRide = null;
              _hasNewRideRequest = false;
              _notificationCount = 0;
              _rideAcceptTimer?.cancel();
              _clearPolylines();
            });
          }
        }
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        print('Failed to fetch rides: ${response.statusCode}');
        _showError('Failed to fetch rides: ${response.statusCode}');
      }
    } on TimeoutException {
      print('Ride check timeout');
      _showError('Ride check timeout. Please check your connection.');
    } catch (e) {
      print('Error checking for rides: $e');
      _showError('Error checking for rides: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingRides = false;
        });
      }
    }
  }

  void _startRideAcceptTimer() {
    _rideAcceptTimer?.cancel();
    _rideAcceptCountdown = 60;

    _rideAcceptTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _rideAcceptCountdown--;
        });

        if (_rideAcceptCountdown <= 0) {
          timer.cancel();
          setState(() {
            _latestRide = null;
            _hasNewRideRequest = false;
            _notificationCount = 0;
            _slideController.reverse();
            _clearPolylines();
          });
          _showError('Ride request expired');
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startTrip(int rideId) async {
    if (mounted) {
      setState(() {
        _isProcessingRide = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/ride/start'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'ride_id': rideId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _rideStatus = 'started';
            _hasNewRideRequest = false;
            _notificationCount = 0;
            _rideAcceptTimer?.cancel();
            _slideController.reverse();
          });
        }

        await _fetchRouteAndDrawPolylines(rideId);
        _showSuccessMessage('Trip started successfully! 🚗');
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to start trip';
          _showError('Failed to start trip: $errorMessage');
        } catch (e) {
          _showError('Failed to start trip. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      _showError('Request timeout. Please check your internet connection.');
    } catch (e) {
      print('Error starting trip: $e');
      _showError('Error starting trip: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRide = false;
        });
      }
    }
  }

  Future<void> _endTrip(int rideId) async {
    if (mounted) {
      setState(() {
        _isProcessingRide = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/ride/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'ride_id': rideId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _rideStatus = 'ended';
            _hasNewRideRequest = false;
            _notificationCount = 0;
            _latestRide = null;
            _rideAcceptTimer?.cancel();
            _slideController.reverse();
            _clearPolylines();
            _todaysEarnings += _parseFare(_latestRide?['ride']['total_fare'] ?? '0');
            _todaysTrips += 1;
            _rideStatus = 'none'; // Reset for next ride
          });
        }

        _showSuccessMessage('Trip completed successfully! 🎉');
        await _checkForRideRequests();
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to end trip';
          _showError('Failed to end trip: $errorMessage');
        } catch (e) {
          _showError('Failed to end trip. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      _showError('Request timeout. Please check your internet connection.');
    } catch (e) {
      print('Error ending trip: $e');
      _showError('Error ending trip: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRide = false;
        });
      }
    }
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required Color color,
    required Future<String> locationFuture,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: Icon(icon, color: AppConstants.textColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.subtitleColor,
                  ),
                ),
                FutureBuilder<String>(
                  future: locationFuture,
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppConstants.textColor,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseCoordinate(dynamic coordinate) {
    try {
      if (coordinate is String) {
        return double.parse(coordinate);
      } else if (coordinate is num) {
        return coordinate.toDouble();
      }
    } catch (e) {
      print('Error parsing coordinate: $e');
    }
    return 0.0;
  }

  int _parseRideId(dynamic rideId) {
    try {
      if (rideId is String) {
        return int.parse(rideId);
      } else if (rideId is num) {
        return rideId.toInt();
      }
    } catch (e) {
      print('Error parsing ride ID: $e');
    }
    return 0;
  }

  Future<String> _getLocationNameFromCoords(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locationName = '';

        if (place.street != null && place.street!.isNotEmpty) {
          locationName += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (locationName.isNotEmpty) locationName += ', ';
          locationName += place.locality!;
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (locationName.isNotEmpty) locationName += ', ';
          locationName += place.administrativeArea!;
        }

        return locationName.isEmpty
            ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
            : locationName;
      }
    } catch (e) {
      print('Error getting location name: $e');
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  Future<void> _acceptRide(int rideId) async {
    if (mounted) {
      setState(() {
        _isProcessingRide = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/ride/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'ride_id': rideId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _rideStatus = 'accepted';
            _hasNewRideRequest = false;
            _notificationCount = 0;
            _rideAcceptTimer?.cancel();
            _slideController.reverse();
          });
        }

        await _fetchRouteAndDrawPolylines(rideId);
        _showSuccessMessage('Ride accepted successfully! 🎉');
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to accept ride';
          _showError('Failed to accept ride: $errorMessage');
        } catch (e) {
          _showError('Failed to accept ride. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      _showError('Request timeout. Please check your internet connection.');
    } catch (e) {
      print('Error accepting ride: $e');
      _showError('Error accepting ride: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRide = false;
        });
      }
    }
  }

  Future<void> _cancelRide(int rideId) async {
    if (mounted) {
      setState(() {
        _isProcessingRide = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/ride/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'ride_id': rideId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _rideStatus = 'none';
            _hasNewRideRequest = false;
            _notificationCount = 0;
            _latestRide = null;
            _rideAcceptTimer?.cancel();
            _slideController.reverse();
            _clearPolylines();
          });
        }

        _showSuccessMessage('Ride declined.');
        await _checkForRideRequests();
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
        _logout();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to decline ride';
          _showError('Failed to decline ride: $errorMessage');
        } catch (e) {
          _showError('Failed to decline ride. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      _showError('Request timeout. Please check your internet connection.');
    } catch (e) {
      print('Error declining ride: $e');
      _showError('Error declining ride: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRide = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    _showProfessionalSnackBar(message, AppConstants.accentColor, Icons.check_circle_outline);
  }

  void _startLocationUpdates() {
    _stopLocationUpdates();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline && _authToken.isNotEmpty && mounted) {
        _getCurrentLocation().then((_) => _updateDriverLocation());
      }
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _startRideChecking() {
    _stopRideChecking();
    _rideCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isOnline && _authToken.isNotEmpty && mounted && _rideStatus == 'none') {
        _checkForRideRequests();
      }
    });
  }

  void _stopRideChecking() {
    _rideCheckTimer?.cancel();
    _rideCheckTimer = null;
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (!_isLocationServiceEnabled && _currentLocation == null) {
      _showError('Location service is not available');
      return;
    }

    if (_authToken.isEmpty) {
      _showError('Authentication required. Please login again.');
      _logout();
      return;
    }

    if (value == true) {
      bool? confirmed = await _showOnlineConfirmationDialog();
      if (confirmed != true) {
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isOnline = value;
        _hasNewRideRequest = false;
        if (!value) {
          _latestRide = null;
          _notificationCount = 0;
          _slideController.reverse();
          _clearPolylines();
          _rideStatus = 'none';
        }
      });
      _toggleController.forward(from: value ? 0.0 : 1.0);
    }

    await _updateDriverLocation();

    if (_isOnline) {
      _startLocationUpdates();
      _startRideChecking();
      _showProfessionalSnackBar(
        '🟢 You are now ONLINE',
        AppConstants.accentColor,
        Icons.online_prediction,
      );
    } else {
      _stopLocationUpdates();
      _stopRideChecking();
      _rideAcceptTimer?.cancel();
      _clearPolylines();
      _showProfessionalSnackBar(
        '🔴 You are now OFFLINE',
        Colors.grey.shade600,
        Icons.offline_bolt,
      );
    }
  }

  Future<bool?> _showOnlineConfirmationDialog() async {
    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppConstants.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppConstants.accentColor.withOpacity(0.2),
                child: Icon(Icons.online_prediction, color: AppConstants.accentColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Go Online?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          content: Text(
            'Ready to receive ride requests? Your location will be shared.',
            style: TextStyle(color: AppConstants.subtitleColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppConstants.skipButtonColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Go Online',
                style: TextStyle(color: AppConstants.textColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    _stopLocationUpdates();
    _stopRideChecking();
    _rideAcceptTimer?.cancel();
    _clearPolylines();

    if (!mounted) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppConstants.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade100,
                child: Icon(Icons.logout, color: Colors.red.shade600),
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: AppConstants.subtitleColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppConstants.skipButtonColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Logout',
                style: TextStyle(color: AppConstants.textColor),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      } catch (e) {
        print('Error during logout: $e');
        _showError('Error during logout: $e');
      }
    }
  }

  double _parseFare(dynamic fare) {
    try {
      if (fare is String) {
        return double.parse(fare);
      } else if (fare is num) {
        return fare.toDouble();
      }
    } catch (e) {
      print('Error parsing fare: $e');
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Driver Dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppConstants.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppConstants.accentColor.withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: AppConstants.accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                  ),
                  Text(
                    _currentLocationName,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppConstants.subtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _toggleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_toggleAnimation.value * 0.1),
                child: GestureDetector(
                  onTap: () => _toggleOnlineStatus(!_isOnline),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isOnline ? AppConstants.accentColor : Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _isOnline ? AppConstants.accentColor.withOpacity(0.3) : Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.online_prediction : Icons.offline_bolt,
                          color: AppConstants.textColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: AppConstants.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (_notificationCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications, color: AppConstants.accentColor),
                    onPressed: () {
                      // Show ride history or notifications
                    },
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_notificationCount',
                        style: TextStyle(
                          color: AppConstants.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _currentIndex == 0
          ? SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _updateMapLocation();
              },
              initialCameraPosition: CameraPosition(
                target: _currentLatLng,
                zoom: 15.0,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              mapType: MapType.normal,
            ),
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Earnings', '\$${_todaysEarnings.toStringAsFixed(2)}', AppConstants.accentColor),
                      _buildStatCard('Trips', _todaysTrips.toString(), AppConstants.accentColor),
                      _buildStatCard('Rating', '⭐ ${_avgRating.toStringAsFixed(1)}', AppConstants.accentColor),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
            if (_isOnline && (_hasNewRideRequest || _rideStatus != 'none') && _latestRide != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppConstants.accentColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppConstants.textColor.withOpacity(0.2),
                                  radius: 20,
                                  child: Icon(
                                    Icons.directions_car,
                                    color: AppConstants.textColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _rideStatus == 'none'
                                            ? 'New Ride Request'
                                            : _rideStatus == 'accepted'
                                            ? 'Ride Accepted'
                                            : 'Trip In Progress',
                                        style: TextStyle(
                                          color: AppConstants.textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _latestRide!['ride']['ride_type']?.toString() ?? 'Standard',
                                        style: TextStyle(
                                          color: AppConstants.textColor.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_rideStatus == 'none')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _rideAcceptCountdown <= 10
                                          ? Colors.red.shade600
                                          : AppConstants.textColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_rideAcceptCountdown}s',
                                      style: TextStyle(
                                        color: AppConstants.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildLocationCard(
                                  icon: Icons.my_location,
                                  title: 'Pickup Location',
                                  color: Colors.green.shade600,
                                  locationFuture: _getLocationNameFromCoords(
                                    _parseCoordinate(_latestRide!['ride']['Pick_location']['latitude']),
                                    _parseCoordinate(_latestRide!['ride']['Pick_location']['longitude']),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildLocationCard(
                                  icon: Icons.location_on,
                                  title: 'Drop-off Location',
                                  color: Colors.red.shade600,
                                  locationFuture: _getLocationNameFromCoords(
                                    _parseCoordinate(_latestRide!['ride']['Drop_location']['latitude']),
                                    _parseCoordinate(_latestRide!['ride']['Drop_location']['longitude']),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppConstants.accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '\$${_parseFare(_latestRide!['ride']['total_fare']).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (_rideStatus == 'none') ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isProcessingRide
                                              ? null
                                              : () {
                                            _rideAcceptTimer?.cancel();
                                            _cancelRide(_parseRideId(_latestRide!['ride']['id']));
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.red.shade600),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: Text(
                                            'Decline',
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isProcessingRide
                                              ? null
                                              : () {
                                            _rideAcceptTimer?.cancel();
                                            _acceptRide(_parseRideId(_latestRide!['ride']['id']));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppConstants.accentColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: _isProcessingRide
                                              ? CircularProgressIndicator(
                                            color: AppConstants.textColor,
                                            strokeWidth: 2,
                                          )
                                              : Text(
                                            'Accept',
                                            style: TextStyle(
                                              color: AppConstants.textColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_rideStatus == 'accepted')
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isProcessingRide
                                              ? null
                                              : () {
                                            _startTrip(_parseRideId(_latestRide!['ride']['id']));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppConstants.accentColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: _isProcessingRide
                                              ? CircularProgressIndicator(
                                            color: AppConstants.textColor,
                                            strokeWidth: 2,
                                          )
                                              : Text(
                                            'Start Trip',
                                            style: TextStyle(
                                              color: AppConstants.textColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_rideStatus == 'started')
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isProcessingRide
                                              ? null
                                              : () {
                                            _endTrip(_parseRideId(_latestRide!['ride']['id']));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade600,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: _isProcessingRide
                                              ? CircularProgressIndicator(
                                            color: AppConstants.textColor,
                                            strokeWidth: 2,
                                          )
                                              : Text(
                                            'End Trip',
                                            style: TextStyle(
                                              color: AppConstants.textColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppConstants.backgroundColor,
                    onPressed: () {
                      if (_mapController != null && _currentLocation != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                              zoom: 15.0,
                            ),
                          ),
                        );
                      }
                    },
                    child: Icon(
                      Icons.my_location,
                      color: AppConstants.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      )
          : _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.accentColor,
        unselectedItemColor: AppConstants.subtitleColor,
        backgroundColor: AppConstants.backgroundColor,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_rounded),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: AppConstants.subtitleColor,
          ),
        ),
      ],
    );
  }
}
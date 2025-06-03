import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/pickup_location.dart';
import '../widgets/map_content.dart';
import '../widgets/floating_action_buttons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/pickup_list_overlay.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// Helper class for decoding polylines
class PointLatLng {
  final double latitude;
  final double longitude;

  PointLatLng(this.latitude, this.longitude);
}

class RiderMapScreen extends StatefulWidget {
  const RiderMapScreen({super.key});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen>
    with SingleTickerProviderStateMixin {
  final List<PickupLocation> pickups = [
    PickupLocation(
      id: 1,
      location: LatLng(29.235692, 79.499676),
      timeSlot: "9AM-10AM",
      inventory: 5,
      address: "Haldwani, 1",
    ),
    PickupLocation(
      id: 2,
      location: LatLng(29.234165, 79.498690),
      timeSlot: "10AM-11AM",
      inventory: 3,
      address: "Haldwani 2",
    ),
    PickupLocation(
      id: 3,
      location: LatLng(29.237675, 79.503989),
      timeSlot: "12PM-1PM",
      inventory: 7,
      address: "Haldwani 3",
    ),
    PickupLocation(
      id: 4,
      location: LatLng(29.238406, 79.496738),
      timeSlot: "1AM-2PM",
      inventory: 7,
      address: "Haldwani 4",
    ),
    PickupLocation(
      id: 5,
      location: LatLng(29.232400, 79.488886),
      timeSlot: "2PM-3PM",
      inventory: 7,
      address: "Haldwani 5",
    ),
  ];

  final warehouseLocation = LatLng(29.217266, 79.529220);
  final String warehouseAddress = "Warehouse";

  LatLng? currentLocation;
  List<LatLng> routePoints = [];
  bool isLoading = true;
  String? errorMessage;
  double totalDistance = 0.0;
  String estimatedTime = '';
  late MapController mapController;
  bool _isMapReady = false;
  bool _isPickupsVisible = true;
  bool _isButtonLoading = false;
  bool _isNavigationActive = false;
  int _activePickupIndex = 0;
  List<List<LatLng>> _segmentedRoutes = [];
  List<double> _segmentDistances = [];
  List<String> _segmentTimes = [];
  late AnimationController _animationController;

  // Location tracking variables
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  bool _isPickupsListVisible = false;

  // Navigation mode properties
  double? _currentHeading;
  bool _inAppNavigationActive = false;
  double _arrivalThresholdMeters =
      30.0; // Consider arrived when within 30 meters
  LatLng? _selectedDestination;
  Timer? _proximityCheckTimer;
  bool _destinationReached = false;

  // Add a new property to track the direct route from rider to selected destination
  List<LatLng> _directRoutePoints = [];

  // Add a property to track when we last calculated the route
  DateTime _lastRouteCalculation = DateTime.now().subtract(
    const Duration(days: 1),
  );
  double _routeUpdateDistanceThreshold = 10.0; // meters
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _positionStreamSubscription?.cancel();
    _proximityCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _isMapReady = false;
    });

    try {
      // Request location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update state with current location
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Calculate route after getting location
      await _calculateRoute();

      // Start tracking position for real-time updates
      _startPositionTracking();

      // If we have a current location and selected a pickup, calculate direct route
      if (currentLocation != null && _activePickupIndex >= 0) {
        final targetLocation =
            _activePickupIndex < pickups.length
                ? pickups[_activePickupIndex].location
                : warehouseLocation;
        _calculateDirectRoute(currentLocation!, targetLocation);
      }
    } catch (e) {
      print('Error getting location: ${e.toString()}');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _calculateRoute() async {
    try {
      if (currentLocation == null) {
        throw Exception('Current location not available');
      }

      // Create list of all points in order: current location -> all pickups -> warehouse
      final List<LatLng> waypoints = [
        currentLocation!,
        ...pickups.map((pickup) => pickup.location),
        warehouseLocation,
      ];

      // Clear existing routes
      routePoints = [];
      _segmentedRoutes = [];
      _segmentDistances = [];
      _segmentTimes = [];
      totalDistance = 0.0;
      estimatedTime = '';

      // Create route segments
      for (int i = 0; i < waypoints.length - 1; i++) {
        final from = waypoints[i];
        final to = waypoints[i + 1];

        final segment = await _getRouteBetweenPoints(from, to);
        if (segment.isNotEmpty) {
          routePoints.addAll(segment);
          _segmentedRoutes.add(segment);

          // Calculate distance for segment (in km)
          double segmentDistance = _calculateDistance(segment);
          _segmentDistances.add(segmentDistance);
          totalDistance += segmentDistance;

          // Estimate time (rough calculation: 30km/h average speed in city)
          final segmentTimeMinutes = (segmentDistance / 30 * 60).round();
          _segmentTimes.add('${segmentTimeMinutes}min');
        }
      }

      // Calculate direct distances from current location to each destination
      // This is used for real-time updates
      _updateDistancesToDestinations(currentLocation!);

      // Estimate total time
      final totalTimeMinutes = (totalDistance / 30 * 60).round();
      if (totalTimeMinutes >= 60) {
        final hours = totalTimeMinutes ~/ 60;
        final minutes = totalTimeMinutes % 60;
        estimatedTime = '${hours}h ${minutes}min';
      } else {
        estimatedTime = '${totalTimeMinutes}min';
      }

      setState(() {
        _isMapReady = true;
        isLoading = false;
      });

      // Fit map to show the entire route after state has updated
      Future.delayed(const Duration(milliseconds: 300), () {
        _fitMapToRoute();
      });
    } catch (e) {
      // Print detailed error for debugging
      print('Route calculation error: ${e.toString()}');

      setState(() {
        errorMessage = 'Failed to calculate route: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<List<LatLng>> _getRouteBetweenPoints(LatLng from, LatLng to) async {
    List<LatLng> polylineCoordinates = [];

    try {
      // Skip MapTiler and go directly to OSM
      print('Using OSM routing API directly');
      polylineCoordinates = await _getRouteFromOSRM(from, to);

      // Last resort: if OSM API fails, create a straight line as fallback
      if (polylineCoordinates.isEmpty) {
        print('OSM route API failed, using fallback straight line');
        polylineCoordinates = _createStraightLineRoute(from, to);
      }
    } catch (e) {
      print('Error getting route: ${e.toString()}');
      // Fall back to straight line as absolute last resort
      polylineCoordinates = _createStraightLineRoute(from, to);
    }

    return polylineCoordinates;
  }

  // Alternative routing using OSRM API
  Future<List<LatLng>> _getRouteFromOSRM(LatLng from, LatLng to) async {
    List<LatLng> polylineCoordinates = [];

    try {
      // OSRM uses longitude,latitude order
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=polyline&steps=true',
      );

      print('Requesting route from OSRM: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('OSRM connection timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final String geometry = data['routes'][0]['geometry'];

          // OSRM uses polyline format
          final List<PointLatLng> points = decodePolyline(geometry);

          for (var point in points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
      }
    } catch (e) {
      print('OSRM routing error: ${e.toString()}');
      // Let the calling method handle the fallback
      throw e;
    }

    return polylineCoordinates;
  }

  List<PointLatLng> decodePolyline(String encoded) {
    List<PointLatLng> points = [];
    int index = 0;
    int len = encoded.length;
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

      points.add(PointLatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  List<LatLng> _createStraightLineRoute(LatLng from, LatLng to) {
    // Create a straight line with 5 interpolated points
    List<LatLng> points = [];
    points.add(from);

    // Add 3 interpolated points
    for (int i = 1; i <= 3; i++) {
      double fraction = i / 4.0;
      double lat = from.latitude + (to.latitude - from.latitude) * fraction;
      double lng = from.longitude + (to.longitude - from.longitude) * fraction;
      points.add(LatLng(lat, lng));
    }

    points.add(to);
    return points;
  }

  // Helper method to decode MapTiler geometry format
  List _decodeGeometry(String geometry) {
    try {
      // If the geometry is a polyline encoded string
      if (geometry.startsWith('e')) {
        // Use line decoder - similar to PolylinePoints
        return _decodePolyline(geometry.substring(1));
      } else {
        // For this example, we'll create a simple straight line as fallback
        return []; // This is a simplified approach
      }
    } catch (e) {
      return [];
    }
  }

  // Helper method to decode a polyline string into coordinates
  List _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add([lng / 1e5, lat / 1e5]); // [longitude, latitude]
    }

    return points;
  }

  double _calculateDistance(List<LatLng> points) {
    double distance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      distance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    // Convert meters to kilometers
    return distance / 1000;
  }

  void _fitMapToRoute() {
    if (routePoints.isEmpty || !_isMapReady) return;

    try {
      final bounds = LatLngBounds.fromPoints(routePoints);
      // Add small padding to ensure all points are visible
      LatLng sw = LatLng(
        bounds.southWest.latitude - 0.01,
        bounds.southWest.longitude - 0.01,
      );
      LatLng ne = LatLng(
        bounds.northEast.latitude + 0.01,
        bounds.northEast.longitude + 0.01,
      );

      final updatedBounds = LatLngBounds(sw, ne);

      mapController.fitCamera(
        CameraFit.bounds(
          bounds: updatedBounds,
          padding: const EdgeInsets.all(50.0),
        ),
      );
    } catch (e) {
      // If bounds calculation fails, just center on current location
      if (currentLocation != null) {
        mapController.move(currentLocation!, 12.0);
      }
    }
  }

  // Start in-app navigation to the selected destination
  void _startInAppNavigation() {
    if (currentLocation == null) {
      return;
    }

    setState(() {
      _isButtonLoading = true;
    });

    try {
      // Get the active destination
      LatLng targetLocation;
      if (_activePickupIndex < pickups.length) {
        _selectedDestination = pickups[_activePickupIndex].location;
        targetLocation = _selectedDestination!;
      } else {
        _selectedDestination = warehouseLocation;
        targetLocation = warehouseLocation;
      }

      // Calculate direct route between rider and destination
      _calculateDirectRoute(currentLocation!, targetLocation).then((_) {
        // Start following mode with increased frequency
        _startHighPrecisionTracking();

        // Set navigation mode active
        setState(() {
          _inAppNavigationActive = true;
          _isNavigationActive = true;
          _isFollowingUser = true;
          _isPickupsListVisible = false;
          _destinationReached = false;
          _isButtonLoading = false;
        });

        // Start checking for arrival at destination
        _startProximityCheck();

        // Center map on current location with appropriate zoom
        if (currentLocation != null) {
          mapController.move(currentLocation!, 17);
        }

        // Keep screen on during navigation
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );

        // Vibrate to indicate navigation has started
        HapticFeedback.mediumImpact();
      });
    } catch (e) {
      setState(() {
        _isButtonLoading = false;
      });
    }
  }

  void _stopInAppNavigation() {
    // Stop the high-precision tracking
    _stopPositionTracking();
    _startPositionTracking(); // Restart with normal precision

    // Stop proximity check
    _proximityCheckTimer?.cancel();

    // Reset navigation state
    setState(() {
      _inAppNavigationActive = false;
      _isNavigationActive = false;
      _currentHeading = null;
      _selectedDestination = null;
      _destinationReached = false;
    });

    // Allow screen to sleep again
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Start tracking with higher precision and frequency
  void _startHighPrecisionTracking() {
    // Cancel existing tracking subscription
    _positionStreamSubscription?.cancel();

    // Use high precision settings for navigation
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // Update more frequently (every 5 meters)
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newLocation = LatLng(position.latitude, position.longitude);

      // Update state with new location and heading
      setState(() {
        currentLocation = newLocation;

        // Update heading if available
        if (position.heading != null) {
          _currentHeading = position.heading;
        }
      });

      // Center map on current location during navigation
      if (_inAppNavigationActive && _isFollowingUser) {
        mapController.move(newLocation, mapController.camera.zoom);
      }

      // Update distances to destinations
      _updateDistancesToDestinations(newLocation);

      // Update direct route if we have a destination selected
      if (_selectedDestination != null && currentLocation != null) {
        // Don't need to call setState here as the async method will do it
        _calculateDirectRoute(currentLocation!, _selectedDestination!);
      }
    });

    _isTracking = true;
  }

  // Start checking if we've reached the destination
  void _startProximityCheck() {
    _proximityCheckTimer?.cancel();

    _proximityCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Check if we should exit
      if (!_inAppNavigationActive ||
          currentLocation == null ||
          _selectedDestination == null) {
        timer.cancel();
        return;
      }

      // Calculate distance to destination
      double distanceToDestination = Geolocator.distanceBetween(
        currentLocation!.latitude,
        currentLocation!.longitude,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
      );

      // Check if we've reached the destination
      if (distanceToDestination <= _arrivalThresholdMeters &&
          !_destinationReached) {
        _onDestinationReached();
      }
    });
  }

  // Handle arrival at destination
  void _onDestinationReached() {
    setState(() {
      _destinationReached = true;
    });

    // Notify with vibration and sound
    HapticFeedback.heavyImpact();

    // Show arrival dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String destinationName = "Destination";
        if (_activePickupIndex < pickups.length) {
          destinationName = "Pickup ${pickups[_activePickupIndex].id}";
        } else {
          destinationName = "Warehouse";
        }

        return AlertDialog(
          title: Text('Arrived at $destinationName!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 50),
              const SizedBox(height: 16),
              Text(
                'You have successfully reached your destination.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                // If we reached a pickup but not the warehouse yet
                if (_activePickupIndex < pickups.length - 1) {
                  // Offer to navigate to next pickup
                  _offerNextDestination();
                } else {
                  // End navigation if last destination
                  _stopInAppNavigation();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Offer to navigate to next destination
  void _offerNextDestination() {
    // Only offer if there are more destinations
    if (_activePickupIndex >= pickups.length - 1) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        int nextIndex = _activePickupIndex + 1;
        String nextDestination =
            nextIndex < pickups.length
                ? "Pickup ${pickups[nextIndex].id}"
                : "Warehouse";

        return AlertDialog(
          title: const Text('Continue to next destination?'),
          content: Text('Would you like to navigate to $nextDestination?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopInAppNavigation();
              },
              child: const Text('No, End Navigation'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _activePickupIndex++;
                  _destinationReached = false;
                });

                // Update selected destination
                if (_activePickupIndex < pickups.length) {
                  _selectedDestination = pickups[_activePickupIndex].location;
                } else {
                  _selectedDestination = warehouseLocation;
                }

                // Reset proximity check
                _startProximityCheck();
              },
              child: const Text('Yes, Continue'),
            ),
          ],
        );
      },
    );
  }

  // Modified to handle the new in-app navigation
  Future<void> _launchExternalNavigation() async {
    // If already in navigation mode, stop it
    if (_inAppNavigationActive) {
      _stopInAppNavigation();
      return;
    }

    // Otherwise, start in-app navigation
    _startInAppNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation, color: Color(0xFF1A73E8), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Task Reuseall',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              color: const Color(0xFF1A73E8),
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _getCurrentLocation();
              },
              tooltip: 'Refresh Route',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapContent(
            isLoading: isLoading,
            errorMessage: errorMessage,
            currentLocation: currentLocation,
            mapController: mapController,
            isMapReady: _isMapReady,
            routePoints: routePoints,
            segmentedRoutes: _segmentedRoutes,
            activePickupIndex: _activePickupIndex,
            pickups: pickups,
            warehouseLocation: warehouseLocation,
            isPickupsVisible: _isPickupsVisible,
            onRefresh: _getCurrentLocation,
            onPickupTap: _navigateToPickup,
            isNavigationActive: _inAppNavigationActive,
            heading: _currentHeading,
            directRoutePoints: _directRoutePoints,
          ),

          // Display navigation information overlay when in navigation mode
          if (_inAppNavigationActive &&
              currentLocation != null &&
              _selectedDestination != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              _activePickupIndex < pickups.length
                                  ? Colors.red
                                  : Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child:
                              _activePickupIndex < pickups.length
                                  ? Text(
                                    '${pickups[_activePickupIndex].id}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.warehouse,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activePickupIndex < pickups.length
                                ? 'Pickup ${pickups[_activePickupIndex].id}'
                                : 'Warehouse',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _destinationReached
                                ? 'You have arrived!'
                                : '${_getDistanceToActiveDestination().toStringAsFixed(1)} km remaining',
                            style: TextStyle(
                              color:
                                  _destinationReached
                                      ? Colors.green
                                      : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _isFollowingUser
                              ? Icons.location_searching
                              : Icons.location_disabled,
                        ),
                        onPressed: _toggleFollowMode,
                        color:
                            _isFollowingUser
                                ? const Color(0xFF1A73E8)
                                : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Only show the overlay when _isPickupsListVisible is true
          if (_isPickupsListVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, // Below app bar
              left: 0,
              right: 0,
              child: PickupListOverlay(
                pickups: pickups,
                activePickupIndex: _activePickupIndex,
                onPickupSelected: _selectPickupRoute,
                onClose: () => setState(() => _isPickupsListVisible = false),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButtons(
        currentLocation: currentLocation,
        isPickupsVisible: _isPickupsVisible,
        onLocationPressed: () {
          if (currentLocation != null) {
            mapController.move(currentLocation!, 16);
            HapticFeedback.selectionClick();
          }
        },
        onVisibilityPressed: _inAppNavigationActive ? null : _togglePickupsVisibility,
        onCompassPressed: _resetMapOrientation,
      ),
      bottomNavigationBar: BottomNavBar(
        isButtonLoading: _isButtonLoading,
        onNavigatePressed: _launchExternalNavigation,
        isNavigationActive: _inAppNavigationActive,
      ),
    );
  }

  // Helper to get distance to active destination
  double _getDistanceToActiveDestination() {
    if (currentLocation == null ||
        (_activePickupIndex >= pickups.length &&
            _activePickupIndex != pickups.length)) {
      return 0.0;
    }

    LatLng destination;
    if (_activePickupIndex < pickups.length) {
      destination = pickups[_activePickupIndex].location;
    } else {
      destination = warehouseLocation;
    }

    double distance =
        Geolocator.distanceBetween(
          currentLocation!.latitude,
          currentLocation!.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000; // Convert to km

    return distance;
  }

  // Modified method to handle the new in-app navigation
  void _selectPickupRoute(int index) {
    if (index >= 0 && index <= pickups.length) {
      setState(() {
        _activePickupIndex = index;

        // Hide the pickup list after selecting
        _isPickupsListVisible = false;
      });

      // Focus map on selected location
      final targetLocation =
          index < pickups.length ? pickups[index].location : warehouseLocation;

      // Calculate direct route between rider and selected location
      _calculateDirectRoute(currentLocation!, targetLocation);

      // Use a smooth animation to move to the target
      mapController.move(targetLocation, 15);

      // Show details about the selected location
      if (index < pickups.length) {
        _showPickupDetails(index);
      }
    }
  }

  // Calculate a direct route between current location and selected destination
  Future<void> _calculateDirectRoute(LatLng from, LatLng to) async {
    // Skip calculation if we just did it recently or location hasn't changed much
    final now = DateTime.now();
    final timeSinceLastUpdate = now.difference(_lastRouteCalculation);

    // Calculate distance from last route calculation point if available
    double distanceFromLastCalc = double.infinity;
    if (_lastRouteStart != null) {
      distanceFromLastCalc = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        _lastRouteStart!.latitude,
        _lastRouteStart!.longitude,
      );
    }

    // If less than 3 seconds passed and we haven't moved much, skip
    if (timeSinceLastUpdate.inSeconds < 3 &&
        distanceFromLastCalc < _routeUpdateDistanceThreshold &&
        _lastRouteEnd != null &&
        _lastRouteEnd!.latitude == to.latitude &&
        _lastRouteEnd!.longitude == to.longitude) {
      return;
    }

    // Update last calculation tracking
    _lastRouteCalculation = now;
    _lastRouteStart = from;
    _lastRouteEnd = to;

    // Only show loading indicator for user-initiated actions, not during tracking
    final bool isInitialCalculation = _directRoutePoints.isEmpty;
    if (isInitialCalculation) {
      setState(() {
        _isButtonLoading = true;
      });
    }

    try {
      // Get route between current location and selected destination
      final routeSegment = await _getRouteBetweenPoints(from, to);

      setState(() {
        _directRoutePoints = routeSegment;
        if (isInitialCalculation) {
          _isButtonLoading = false;
        }
      });
    } catch (e) {
      print('Error calculating direct route: $e');
      setState(() {
        _directRoutePoints = _createStraightLineRoute(from, to);
        if (isInitialCalculation) {
          _isButtonLoading = false;
        }
      });
    }
  }

  // Start tracking the rider's position in real-time
  void _startPositionTracking() {
    if (_isTracking) return;

    _isTracking = true;
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newLocation = LatLng(position.latitude, position.longitude);

      // Update current location
      setState(() {
        currentLocation = newLocation;
      });

      // Update distances
      _updateDistancesToDestinations(newLocation);

      // Center map on current location if following
      if (_isFollowingUser) {
        mapController.move(newLocation, mapController.camera.zoom);
      }
    });
  }

  // Stop tracking position
  void _stopPositionTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  // Flag to control if map should follow user
  bool _isFollowingUser = false;

  // Toggle tracking mode
  void _toggleFollowMode() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;
    });

    if (_isFollowingUser && currentLocation != null) {
      mapController.move(currentLocation!, 16);
    }
  }

  // Update distances based on current location
  void _updateDistancesToDestinations(LatLng currentPos) {
    if (pickups.isEmpty) return;

    List<double> newDistances = [];
    double totalNewDistance = 0;

    // For each segment, calculate new distances
    for (int i = 0; i < pickups.length; i++) {
      // Actual distance to next pickup
      final destination = pickups[i].location;
      final distance =
          Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            destination.latitude,
            destination.longitude,
          ) /
          1000; // Convert to km

      newDistances.add(distance);

      if (i == _activePickupIndex) {
        totalNewDistance += distance;
      }
    }

    // Add warehouse
    final warehouseDistance =
        Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          warehouseLocation.latitude,
          warehouseLocation.longitude,
        ) /
        1000;
    newDistances.add(warehouseDistance);

    // Calculate total distance for all relevant segments
    double calculatedTotalDistance = 0;
    if (_activePickupIndex < pickups.length) {
      // Calculate distance from current to active pickup
      calculatedTotalDistance = newDistances[_activePickupIndex];

      // Add distances for remaining pickups
      for (int i = _activePickupIndex; i < pickups.length - 1; i++) {
        final from = pickups[i].location;
        final to = pickups[i + 1].location;
        final segmentDistance =
            Geolocator.distanceBetween(
              from.latitude,
              from.longitude,
              to.latitude,
              to.longitude,
            ) /
            1000;
        calculatedTotalDistance += segmentDistance;
      }

      // Add last segment to warehouse
      if (pickups.isNotEmpty) {
        final lastPickup = pickups.last.location;
        final lastSegment =
            Geolocator.distanceBetween(
              lastPickup.latitude,
              lastPickup.longitude,
              warehouseLocation.latitude,
              warehouseLocation.longitude,
            ) /
            1000;
        calculatedTotalDistance += lastSegment;
      }
    } else {
      // Just distance to warehouse
      calculatedTotalDistance = warehouseDistance;
    }

    // Update distances
    setState(() {
      _segmentDistances = newDistances;
      totalDistance = calculatedTotalDistance;

      // Update ETA based on new distance
      final totalTimeMinutes = (totalDistance / 30 * 60).round(); // 30km/h
      if (totalTimeMinutes >= 60) {
        final hours = totalTimeMinutes ~/ 60;
        final minutes = totalTimeMinutes % 60;
        estimatedTime = '${hours}h ${minutes}min';
      } else {
        estimatedTime = '${totalTimeMinutes}min';
      }
    });
  }

  void _showPickupDetails(int index) {
    if (index >= pickups.length) return;

    final pickup = pickups[index];
  }

  // Modified method to handle the route summary card visibility
  void _togglePickupsVisibility() {
    setState(() {
      _isPickupsVisible = !_isPickupsVisible;
      
      // Close the pickup list if we're hiding everything
      if (!_isPickupsVisible) {
        _isPickupsListVisible = false;
      }
    });
    
    // Provide haptic feedback for the toggle
    HapticFeedback.selectionClick();
  }

  // This toggles the pickup list overlay when the eye button is clicked
  void _togglePickupsList() {
    setState(() {
      _isPickupsListVisible = !_isPickupsListVisible;
    });
  }

  // Keep the existing _navigateToPickup method but update its implementation
  void _navigateToPickup(int index) {
    _selectPickupRoute(index);
  }

  // Add a method to reset map orientation to north
  void _resetMapOrientation() {
    // Set the map's rotation to 0 (north at top)
    mapController.rotate(0);
    
    // Provide haptic feedback to indicate orientation reset
    HapticFeedback.lightImpact();
  }
}

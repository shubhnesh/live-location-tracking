import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_map_view/models/pickup_location.dart';
import 'package:rider_map_view/widgets/route_summary_card.dart';
import 'dart:math';

class MapContent extends StatefulWidget {
  final bool isLoading;
  final String? errorMessage;
  final LatLng? currentLocation;
  final MapController mapController;
  final bool isMapReady;
  final List<LatLng> routePoints;
  final List<List<LatLng>> segmentedRoutes;
  final int activePickupIndex;
  final List<PickupLocation> pickups;
  final LatLng warehouseLocation;
  final bool isPickupsVisible;
  final VoidCallback onRefresh;
  final Function(int) onPickupTap;
  final bool isNavigationActive;
  final double? heading;
  final List<LatLng> directRoutePoints;

  const MapContent({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.currentLocation,
    required this.mapController,
    required this.isMapReady,
    required this.routePoints,
    required this.segmentedRoutes,
    required this.activePickupIndex,
    required this.pickups,
    required this.warehouseLocation,
    required this.isPickupsVisible,
    required this.onRefresh,
    required this.onPickupTap,
    this.isNavigationActive = false,
    this.heading,
    this.directRoutePoints = const [],
  });

  @override
  State<MapContent> createState() => _MapContentState();
}

class _MapContentState extends State<MapContent> {
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.errorMessage != null) {
      return _buildErrorState();
    }

    if (widget.currentLocation == null) {
      return const Center(child: Text('No location data available'));
    }

    return RepaintBoundary(
      child: _buildMapContent(),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1A73E8),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your route...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we calculate the optimal path',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade800,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.errorMessage ?? 'An unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapContent() {
    return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation ?? LatLng(0, 0),
              initialZoom: widget.currentLocation != null ? 14.0 : 2.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onMapReady: () {
                print('Map is ready');
                // This could be replaced with a callback to parent if needed
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // Allow all interactions including rotation
                enableMultiFingerGestureRace: true,
              ),
              // Set default rotation to 0 (north up)
              rotation: 0.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=aYsQM4HbMnbMyYhvub76',
                additionalOptions: const {'key': 'aYsQM4HbMnbMyYhvub76'},
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.rider_map_view',
                tileProvider: NetworkTileProvider(),
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                maxZoom: 18,
                keepBuffer: 5,
                retinaMode: true,
                backgroundColor: Colors.grey[300],
              ),
              PolylineLayer(
                polylines: _buildPolylines(),
                polylineCulling: true,
              ),
              MarkerLayer(
                markers: _buildMarkers(),
                rotate: widget.isNavigationActive, // Only rotate markers in navigation mode
                alignment: Alignment.center,
              ),
            ],
          ),
        ),
        if (widget.isPickupsVisible && widget.pickups.isNotEmpty)
          Positioned(
            top: 100, // Positioned below the app bar for better visibility
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: RouteSummaryCard(
                totalDistance: calculateTotalDistance(),
                estimatedTime: calculateEstimatedTime(),
                pickups: widget.pickups,
                activePickupIndex: widget.activePickupIndex,
                segmentDistances: widget.segmentedRoutes.isNotEmpty
                    ? getSegmentDistances()
                    : widget.pickups.map((p) => 0.0).toList(),
                onPickupTap: widget.onPickupTap,
              ),
            ),
          ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    List<Polyline> polylines = [];

    // If we have a direct route between rider and selected destination, show it prominently
    if (widget.directRoutePoints.isNotEmpty && widget.currentLocation != null) {
      polylines.add(
        Polyline(
          points: widget.directRoutePoints,
          strokeWidth: 6.0,
          color: const Color(0xFF1A73E8), // Blue for the direct route
          borderColor: Colors.white,
          borderStrokeWidth: 1.5,
          isDotted: false,
        ),
      );
      
      // If not in navigation mode, also show all route segments in gray
      if (!widget.isNavigationActive) {
        _addRegularRoutePolylines(polylines);
      }
      
      return polylines;
    }

    // Otherwise, fall back to the old behavior
    if (widget.routePoints.isEmpty) return polylines;
    
    _addRegularRoutePolylines(polylines);

    return polylines;
  }
  
  // Helper to add the regular route polylines (segmented routes)
  void _addRegularRoutePolylines(List<Polyline> polylines) {
    // Simplify routes for better performance when there are many points
    List<List<LatLng>> optimizedRoutes = [];
    for (final segment in widget.segmentedRoutes) {
      // Simple point reduction - keep only every Nth point for long segments
      if (segment.length > 100) {
        final reducedSegment = <LatLng>[];
        for (int i = 0; i < segment.length; i += 3) {
          // Skip every 3 points
          reducedSegment.add(segment[i]);
        }
        // Always include the last point
        if (segment.isNotEmpty && (segment.length - 1) % 3 != 0) {
          reducedSegment.add(segment.last);
        }
        optimizedRoutes.add(reducedSegment);
      } else {
        optimizedRoutes.add(segment);
      }
    }

    // Add each segment with a different color
    for (int i = 0; i < optimizedRoutes.length; i++) {
      final segment = optimizedRoutes[i];
      
      // If we're showing direct route, all regular routes are gray
      final bool isActiveSegment = widget.directRoutePoints.isEmpty && i == widget.activePickupIndex;
      final Color color = isActiveSegment 
          ? const Color(0xFF1A73E8)  // Blue for active
          : Colors.grey;
      final double opacity = isActiveSegment ? 1.0 : 0.6;
      final double width = isActiveSegment ? 6.0 : 3.5;
      final double borderWidth = isActiveSegment ? 1.5 : 1.0;

      polylines.add(
        Polyline(
          points: segment,
          strokeWidth: width,
          color: color.withOpacity(opacity),
          borderColor: Colors.white,
          borderStrokeWidth: borderWidth,
          isDotted: false,
        ),
      );
    }
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Only add visible markers based on zoom level and view bounds
    // This helps reduce rendering load
    final visibleMarkers = [];

    // Add current location marker with a pulse effect
    if (widget.currentLocation != null) {
      markers.add(
        Marker(
          point: widget.currentLocation!,
          width: 40, // Reduced size
          height: 40, // Reduced size
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: widget.heading != null ? (widget.heading! * (3.14159265359 / 180)) : 0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse circle
                    Container(
                      width: 30, // Reduced size
                      height: 30, // Reduced size
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Inner circle for current location
                    Container(
                      width: 14, // Reduced size
                      height: 14, // Reduced size
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A73E8).withOpacity(0.4),
                            blurRadius: 4, // Reduced blur for better performance
                            spreadRadius: 1, // Reduced spread for better performance
                          ),
                        ],
                      ),
                    ),
                    // Direction indicator when in navigation mode
                    if (widget.isNavigationActive && widget.heading != null)
                      Positioned(
                        top: -12,
                        child: Container(
                          width: 10,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A73E8),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Only add pickup markers that would be relevant to the user
    final markerLimit =
        10; // Limit the number of markers for better performance
    final activePickups = widget.pickups.length > markerLimit
        ? [
            ...widget.pickups.sublist(
                0, min(widget.activePickupIndex + 3, widget.pickups.length)),
            if (widget.activePickupIndex + 3 < widget.pickups.length)
              widget.pickups.last
          ]
        : widget.pickups;

    // Add pickup location markers (limited to improve performance)
    for (int i = 0; i < activePickups.length; i++) {
      final pickup = activePickups[i];
      final location = pickup.location;

      // Check if this is the active pickup
      final isActive =
          widget.pickups.indexOf(pickup) == widget.activePickupIndex;

      markers.add(
        Marker(
          point: location,
          width: 60,
          height: 85, // Increased height to accommodate content
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 60, maxHeight: 85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(bottom: 0),
                    constraints: const BoxConstraints(
                      maxWidth: 60,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'Pickup ${pickup.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Icon(Icons.location_on, color: Colors.red, size: 30),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Add warehouse marker
    markers.add(
      Marker(
        point: widget.warehouseLocation,
        width: 80,
        height: 85, // Increased height to accommodate content
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80, maxHeight: 85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 0),
                  constraints: const BoxConstraints(
                    maxWidth: 80,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Warehouse',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(height: 1),
                const Icon(Icons.location_on, color: Colors.green, size: 30),
              ],
            ),
          ),
        ),
      ),
    );

    return markers;
  }

  double calculateTotalDistance() {
    // Simplified method - ideally this would come from parent
    double total = 0;
    for (var segment in widget.segmentedRoutes) {
      total += _calculateSegmentDistance(segment);
    }
    return total;
  }

  String calculateEstimatedTime() {
    // Simplified method - ideally this would come from parent
    double totalDistance = calculateTotalDistance();
    int minutes =
        (totalDistance / 30 * 60).round(); // Assuming 30km/h avg speed

    if (minutes >= 60) {
      int hours = minutes ~/ 60;
      int mins = minutes % 60;
      return '${hours}h ${mins}min';
    } else {
      return '${minutes}min';
    }
  }

  List<double> getSegmentDistances() {
    // Simplified method - ideally this would come from parent
    List<double> distances = [];
    for (var segment in widget.segmentedRoutes) {
      distances.add(_calculateSegmentDistance(segment));
    }
    return distances;
  }

  double _calculateSegmentDistance(List<LatLng> points) {
    if (points.isEmpty || points.length < 2) return 0;

    double distance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      distance += _distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return distance;
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    // Simplified haversine formula for distance calculation
    const double earthRadius = 6371; // in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  void didUpdateWidget(MapContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild markers and polylines when relevant properties change
    if (oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.activePickupIndex != widget.activePickupIndex ||
        oldWidget.isPickupsVisible != widget.isPickupsVisible ||
        oldWidget.segmentedRoutes != widget.segmentedRoutes) {
      // Force a rebuild of just what changed
      setState(() {});
    }
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class FloatingActionButtons extends StatelessWidget {
  final LatLng? currentLocation;
  final bool isPickupsVisible;
  final VoidCallback onLocationPressed;
  final VoidCallback? onVisibilityPressed;
  final VoidCallback onCompassPressed;

  const FloatingActionButtons({
    super.key,
    required this.currentLocation,
    required this.isPickupsVisible,
    required this.onLocationPressed,
    required this.onVisibilityPressed,
    required this.onCompassPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // My Location button
        FloatingActionButton(
          heroTag: 'location',
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A73E8),
          elevation: 4,
          onPressed: onLocationPressed,
          mini: true,
          tooltip: 'My Location',
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 12),
        
        // Eye button for toggling Route Summary Card visibility
        FloatingActionButton(
          heroTag: 'visibility',
          backgroundColor: Colors.white,
          foregroundColor: onVisibilityPressed == null 
              ? Colors.grey.shade400
              : const Color(0xFF1A73E8),
          elevation: 4,
          onPressed: onVisibilityPressed,
          mini: true,
          tooltip: isPickupsVisible ? 'Hide Route Summary' : 'Show Route Summary',
          child: Icon(
            isPickupsVisible ? Icons.visibility : Icons.visibility_off,
            size: 20,
            color: onVisibilityPressed == null 
                ? Colors.grey.shade400
                : const Color(0xFF1A73E8),
          ),
        ),
        const SizedBox(height: 12),
        
        // Compass button for map orientation
        FloatingActionButton(
          heroTag: 'compass',
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A73E8),
          elevation: 4,
          onPressed: onCompassPressed,
          mini: true,
          tooltip: 'Reset Map Orientation',
          child: const Icon(Icons.explore),
        ),
      ],
    );
  }
}

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class MapUtils {
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end) / 1000; // Convert to km
  }

  static double getZoomLevel(LatLngBounds bounds) {
    const double worldDimension = 256;
    const double padding = 1.5;

    final latDiff = bounds.north - bounds.south;
    final lngDiff = bounds.east - bounds.west;

    final latZoom = log(worldDimension * padding / latDiff) / ln2;
    final lngZoom = log(worldDimension * padding / lngDiff) / ln2;

    return min(latZoom, lngZoom);
  }
}

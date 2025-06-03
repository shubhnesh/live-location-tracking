import 'package:latlong2/latlong.dart';

class PickupLocation {
  final int id;
  final LatLng location;
  final String timeSlot;
  final int inventory;
  final String address;

  PickupLocation({
    required this.id,
    required this.location,
    required this.timeSlot,
    required this.inventory,
    required this.address,
  });
}

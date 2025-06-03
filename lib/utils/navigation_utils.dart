import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class NavigationUtils {
  static Future<void> launchExternalNavigation({
    required LatLng currentLocation,
    required LatLng destination,
  }) async {
    try {
      // Try Google Maps first
      final googleUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${currentLocation.latitude},${currentLocation.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
      );

      final canLaunchGoogle = await canLaunchUrl(googleUrl);

      if (canLaunchGoogle) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else {
        // Try Apple Maps on iOS
        final appleMapsUrl = Uri.parse(
          'https://maps.apple.com/?saddr=${currentLocation.latitude},${currentLocation.longitude}&daddr=${destination.latitude},${destination.longitude}&dirflg=d',
        );

        final canLaunchApple = await canLaunchUrl(appleMapsUrl);

        if (canLaunchApple) {
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
        } else {
          // Try OSM as last resort
          final osmUrl = Uri.parse(
            'https://www.openstreetmap.org/directions?engine=osrm_car&route=${currentLocation.latitude},${currentLocation.longitude};${destination.latitude},${destination.longitude}',
          );

          if (await canLaunchUrl(osmUrl)) {
            await launchUrl(osmUrl, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Could not launch any navigation app');
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

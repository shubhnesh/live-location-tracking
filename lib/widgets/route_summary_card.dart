import 'package:flutter/material.dart';
import '../models/pickup_location.dart';

class RouteSummaryCard extends StatelessWidget {
  final double totalDistance;
  final String estimatedTime;
  final List<PickupLocation> pickups;
  final int activePickupIndex;
  final List<double> segmentDistances;
  final Function(int) onPickupTap;

  const RouteSummaryCard({
    super.key,
    required this.totalDistance,
    required this.estimatedTime,
    required this.pickups,
    required this.activePickupIndex,
    required this.segmentDistances,
    required this.onPickupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Route',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalDistance.toStringAsFixed(1)} km • ${estimatedTime.isEmpty ? '00:00' : estimatedTime}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _buildActivePickupSection(),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pickup Locations',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Text(
                  'Distances',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pickups.asMap().entries.map((entry) {
              final index = entry.key;
              final pickup = entry.value;

              // Get the distance for this pickup
              final distance =
                  segmentDistances.isNotEmpty && index < segmentDistances.length
                      ? segmentDistances[index]
                      : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () => onPickupTap(index),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: index == activePickupIndex
                              ? Colors.red
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          pickup.id.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickup.timeSlot,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${pickup.inventory} items',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: index == activePickupIndex
                              ? Colors.red
                              : Colors.grey[700],
                          fontWeight: index == activePickupIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // Display warehouse as the final destination
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: InkWell(
                onTap: () => onPickupTap(pickups.length),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: activePickupIndex >= pickups.length
                            ? Colors.green
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Warehouse',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Final Destination',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      segmentDistances.length > pickups.length
                          ? '${segmentDistances.last.toStringAsFixed(1)} km'
                          : '-- km',
                      style: TextStyle(
                        color: activePickupIndex >= pickups.length
                            ? Colors.green
                            : Colors.grey[700],
                        fontWeight: activePickupIndex >= pickups.length
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePickupSection() {
    if (activePickupIndex >= pickups.length) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Destination',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Warehouse',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      );
    }

    final pickup = pickups[activePickupIndex];
    final distance =
        segmentDistances.isEmpty || activePickupIndex >= segmentDistances.length
            ? 0.0
            : segmentDistances[activePickupIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Next Pickup',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                pickup.id.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${distance.toStringAsFixed(1)} km',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}

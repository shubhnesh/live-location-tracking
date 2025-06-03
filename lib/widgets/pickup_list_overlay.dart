import 'package:flutter/material.dart';
import '../models/pickup_location.dart';

class PickupListOverlay extends StatelessWidget {
  final List<PickupLocation> pickups;
  final int activePickupIndex;
  final Function(int) onPickupSelected;
  final VoidCallback onClose;

  const PickupListOverlay({
    Key? key,
    required this.pickups,
    required this.activePickupIndex,
    required this.onPickupSelected,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Destination',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ...pickups.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pickup = entry.value;
                  final isActive = index == activePickupIndex;

                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.red : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${pickup.id}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text('Pickup ${pickup.id}'),
                    subtitle: Text('${pickup.inventory} items • ${pickup.timeSlot}'),
                    selected: isActive,
                    onTap: () {
                      onPickupSelected(index);
                      onClose();
                    },
                  );
                }).toList(),
                
                // Add warehouse as the last item
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: activePickupIndex >= pickups.length 
                          ? Colors.green 
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.warehouse,
                        size: 16,
                        color: activePickupIndex >= pickups.length 
                            ? Colors.white 
                            : Colors.black,
                      ),
                    ),
                  ),
                  title: const Text('Warehouse'),
                  subtitle: const Text('Final Destination'),
                  selected: activePickupIndex >= pickups.length,
                  onTap: () {
                    onPickupSelected(pickups.length);
                    onClose();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Tap on a destination to view its route',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final bool isButtonLoading;
  final VoidCallback onNavigatePressed;
  final bool isNavigationActive;

  const BottomNavBar({
    super.key,
    required this.isButtonLoading,
    required this.onNavigatePressed,
    this.isNavigationActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isButtonLoading ? null : onNavigatePressed,
        icon: isButtonLoading
            ? Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isNavigationActive ? Icons.stop_circle : Icons.navigation,
                  key: ValueKey<bool>(isNavigationActive),
                ),
              ),
        label: Text(
          isNavigationActive ? 'Stop Navigation' : 'Start Navigation',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isNavigationActive ? Colors.red : const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

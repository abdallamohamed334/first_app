import 'package:flutter/material.dart';

/// Displays the Flaticon service artwork with a lightweight local animation.
///
/// The local PNG previews keep the service grid fast and offline-friendly while
/// the motion gives each service tile the animated-icon feel requested in the
/// product UI.
class AnimatedServiceIcon extends StatefulWidget {
  const AnimatedServiceIcon({
    super.key,
    required this.slug,
    this.size = 28,
    this.fallbackIcon = Icons.category_rounded,
    this.color,
  });

  final String? slug;
  final double size;
  final IconData fallbackIcon;
  final Color? color;

  @override
  State<AnimatedServiceIcon> createState() => _AnimatedServiceIconState();
}

class _AnimatedServiceIconState extends State<AnimatedServiceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  static const _assets = <String, String>{
    'plumbing': 'assets/icons/flaticon/plumbing.png',
    'electricity': 'assets/icons/flaticon/electricity.png',
    'screen_maintenance': 'assets/icons/flaticon/screen_maintenance.png',
    'transportation': 'assets/icons/flaticon/transportation.png',
    'daily_wage': 'assets/icons/flaticon/daily_wage.png',
    'car_mechanic': 'assets/icons/flaticon/car_mechanic.png',
    'carpentry': 'assets/icons/flaticon/carpentry.png',
    'air_conditioning': 'assets/icons/flaticon/air_conditioning.png',
    'water_heaters': 'assets/icons/flaticon/water_heaters.png',
    'car_electrician': 'assets/icons/flaticon/car_electrician.png',
    'water_filters': 'assets/icons/flaticon/water_filters.png',
    'home_fan_maintenance':
        'assets/icons/flaticon/home_fan_maintenance.png',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(curve);
    _lift = Tween<double>(begin: 2, end: -2).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assets[widget.slug?.trim().toLowerCase()];
    return Semantics(
      label: 'أيقونة خدمة ${widget.slug ?? ''}',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _lift.value),
          child: Transform.scale(scale: _scale.value, child: child),
        ),
        child: asset == null
            ? Icon(widget.fallbackIcon, color: widget.color, size: widget.size)
            : Image.asset(
                asset,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  widget.fallbackIcon,
                  color: widget.color,
                  size: widget.size,
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:loqma/core/models/business.dart';
import 'package:loqma/features/business/domain/entities/business_capability.dart';

class BusinessCapabilityAction extends StatelessWidget {
  final Business business;
  final BusinessCapability capability;
  final Widget child;
  final Widget? fallback;

  const BusinessCapabilityAction({
    super.key,
    required this.business,
    required this.capability,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!business.can(capability)) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

class BusinessCapabilityButton extends StatelessWidget {
  final Business business;
  final BusinessCapability capability;
  final VoidCallback? onPressed;
  final Widget child;

  const BusinessCapabilityButton({
    super.key,
    required this.business,
    required this.capability,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!business.can(capability)) return const SizedBox.shrink();
    return ElevatedButton(onPressed: onPressed, child: child);
  }
}

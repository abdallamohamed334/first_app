import 'package:flutter/material.dart';
import 'package:loqma/features/business/domain/entities/business_capability.dart';

class BusinessCapabilityGuard {
  const BusinessCapabilityGuard._();

  static bool can(Set<BusinessCapability> capabilities,
          BusinessCapability capability) =>
      capabilities.contains(capability);

  static Widget action({
    required Set<BusinessCapability> capabilities,
    required BusinessCapability capability,
    required Widget child,
  }) {
    return can(capabilities, capability) ? child : const SizedBox.shrink();
  }

  static Widget disabledMessage({
    required BuildContext context,
    required BusinessCapability capability,
  }) {
    return Text(
      'هذه الصلاحية غير مفعلة لحسابك: ${capability.displayName}',
      textAlign: TextAlign.center,
    );
  }
}

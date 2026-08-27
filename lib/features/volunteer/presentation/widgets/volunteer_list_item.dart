// lib/features/volunteer/presentation/widgets/volunteer_list_item.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/volunteer/presentation/models/volunteer_model.dart';

class VolunteerListItem extends StatelessWidget {
  final VolunteerModel volunteer;
  final bool isCurrentUser;

  const VolunteerListItem({
    super.key,
    required this.volunteer,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primary.withAlpha(25)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: colorScheme.primary, width: 2)
            : Border.all(color: colorScheme.outlineVariant.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ الصورة
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primary.withAlpha(20),
            backgroundImage: volunteer.avatarUrl != null
                ? NetworkImage(volunteer.avatarUrl!)
                : null,
            child: volunteer.avatarUrl == null
                ? Text(
                    volunteer.name.isNotEmpty
                        ? volunteer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // ✅ الاسم والنقاط
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      volunteer.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrentUser ? FontWeight.bold : FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'أنت',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${volunteer.points} نقطة',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'المستوى ${volunteer.level}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

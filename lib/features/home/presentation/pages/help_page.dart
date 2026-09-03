import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  final List<Map<String, dynamic>> deliveryTasks;

  const HelpPage({super.key, required this.deliveryTasks});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      appBar: AppBar(
        title: const Text(
          '🚗 أساعد في توصيل',
          style: TextStyle(
            color: Color(0xFF123F31),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: deliveryTasks.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deliveryTasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(deliveryTasks[index]);
              },
            ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3679C8).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3679C8).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3679C8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Color(0xFF3679C8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task['title'] ?? 'فرصة توصيل',
                  style: const TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.restaurant_rounded,
            'المتبرع: ${task['donor_name'] ?? 'غير محدد'}',
          ),
          _infoRow(
            Icons.location_on_rounded,
            'الاستلام: ${task['pickup_location'] ?? 'غير محدد'}',
          ),
          _infoRow(
            Icons.location_on_rounded,
            'التسليم: ${task['delivery_location'] ?? 'غير محدد'}',
            color: const Color(0xFF0B7650),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badge(
                '${task['quantity'] ?? 0} وجبة',
                const Color(0xFF0B7650),
              ),
              const SizedBox(width: 6),
              _badge(
                '~${task['distance']?.toStringAsFixed(1) ?? '?'} كم',
                const Color(0xFFB77700),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  // TODO: فتح تفاصيل فرصة التوصيل
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3679C8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('أريد التوصيل'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFF71837C)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? const Color(0xFF71837C),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delivery_dining_rounded,
            size: 48,
            color: Color(0xFF71837C),
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد فرص توصيل حالياً',
            style: TextStyle(
              color: Color(0xFF71837C),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'ستظهر هنا التبرعات التي تحتاج متطوعين',
            style: TextStyle(
              color: Color(0xFF71837C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

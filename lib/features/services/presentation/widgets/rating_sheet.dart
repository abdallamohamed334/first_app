// lib/features/services/presentation/widgets/rating_sheet.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/services/data/repositories/service_providers_repository.dart';

class RatingSheet extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String userId;

  const RatingSheet({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.userId,
  });

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  final _repository = ServiceProvidersRepository();
  final _commentController = TextEditingController();

  int _rating = 0;
  bool _isAnonymous = false;
  bool _submitting = false;
  final Set<String> _selectedTags = {};

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF1C1C1C);
  static const _cardSoft = Color(0xFF2C2C2E);
  static const _primaryRed = Color(0xFFE31C25);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFFAAAAAA);
  static const _border = Color(0x14FFFFFF);
  static const _gold = Color(0xFFFFD700);
  static const _green = Color(0xFF2E9B5C);

  static const List<String> _availableTags = [
    'سريع',
    'محترم',
    'نضيف',
    'محترف',
    'سعر معقول',
    'متطوع',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _showSnack('اختار عدد النجوم الأول');
      return;
    }

    setState(() => _submitting = true);

    try {
      await _repository.submitReview(
        providerId: widget.providerId,
        userId: widget.userId,
        rating: _rating,
        comment: _commentController.text,
        tags: _selectedTags.toList(),
        isAnonymous: _isAnonymous,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(msg.isEmpty ? 'تعذر إرسال التقييم' : msg);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: _cardSoft,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── العنوان
                  const Text(
                    'قيّم الخدمة',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.providerName,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── النجوم
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final starIndex = i + 1;
                        final filled = starIndex <= _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = starIndex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: filled
                                  ? _gold.withValues(alpha: 0.15)
                                  : _cardSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: filled ? _gold : _textSecondary,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _ratingLabel(_rating),
                      style: TextStyle(
                        color: _rating > 0 ? _gold : _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── التعليق
                  const Text(
                    'اكتب تجربتك (اختياري)',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'شاركنا رأيك في الخدمة...',
                        hintStyle: TextStyle(
                          color: _textSecondary.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                        counterStyle: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── التاجات
                  const Text(
                    'اختار اللي يناسبك',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _green.withValues(alpha: 0.15)
                                : _card,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: selected
                                  ? _green.withValues(alpha: 0.4)
                                  : _border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(Icons.check_rounded,
                                    color: _green, size: 13),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                tag,
                                style: TextStyle(
                                  color: selected ? _green : _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // ── مجهول؟
                  GestureDetector(
                    onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAnonymous
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: _isAnonymous ? _green : _textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'انشر التقييم كمجهول',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            value: _isAnonymous,
                            onChanged: (v) => setState(() => _isAnonymous = v),
                            activeColor: _green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── زر الإرسال
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting || _rating == 0 ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryRed,
                        disabledBackgroundColor:
                            _primaryRed.withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'إرسال التقييم',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 5:
        return 'ممتاز جدًا 🌟';
      case 4:
        return 'كويس جدًا 👍';
      case 3:
        return 'متوسط 🙂';
      case 2:
        return 'مش كويس 👎';
      case 1:
        return 'سيء جدًا 😡';
      default:
        return 'اختار التقييم';
    }
  }
}

// lib/features/institutions/presentation/pages/institution_booking_search_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';
import 'institution_booking_details_page.dart';

// ✅ تعريف الألوان خارج الكلاس
const Color _primary = Color(0xFF0B7650);
const Color _primaryDark = Color(0xFF123F31);
const Color _background = Color(0xFFF6FAF8);
const Color _surface = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF71837C);
const Color _errorColor = Color(0xFFD64545);

class InstitutionBookingSearchPage extends StatefulWidget {
  const InstitutionBookingSearchPage({super.key});

  @override
  State<InstitutionBookingSearchPage> createState() =>
      _InstitutionBookingSearchPageState();
}

class _InstitutionBookingSearchPageState
    extends State<InstitutionBookingSearchPage> {
  final _codeController = TextEditingController();
  final _repository = InstitutionOffersRepository();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i');
      result = result.replaceAll(persian[i], '$i');
    }
    return result.trim();
  }

  Future<void> _searchBooking() async {
    final code = _normalizeDigits(_codeController.text);

    if (code.isEmpty) {
      setState(() => _error = 'يرجى إدخال كود الحجز');
      return;
    }

    if (code.length != 6) {
      setState(() => _error = 'كود الحجز يجب أن يتكون من 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _repository.findBookingByCode(code);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _error = '❌ لا يوجد حجز بهذا الكود';
        });
        return;
      }

      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (_) => InstitutionBookingDetailsPage(
            booking: result,
            repository: _repository,
          ),
        ),
      )
          .then((_) {
        if (mounted) {
          _codeController.clear();
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'تعذر البحث عن الحجز: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: _primaryDark,
          ),
          title: const Text(
            'البحث عن حجز',
            style: TextStyle(
              color: _primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ شرح
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: _primary,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'أدخل كود الحجز المكون من 6 أرقام للبحث عن طلب العميل',
                        style: TextStyle(
                          color: _primaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ حقل إدخال الكود
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchBooking(),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'كود الحجز (6 أرقام)',
                  hintText: 'مثال: 123456',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  suffixIcon: _codeController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              _codeController.clear();
                              _error = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2EEE8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2EEE8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _errorColor, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _errorColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: _errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ✅ زر البحث
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _searchBooking,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded),
                            SizedBox(width: 8),
                            Text(
                              'بحث',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // ✅ النصائح - باستخدام Expanded بدلاً من Spacer
              const SizedBox(height: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2EEE8)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 نصائح:',
                          style: TextStyle(
                            color: _primaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        _BulletPoint(
                          text: 'الكود يتكون من 6 أرقام',
                        ),
                        _BulletPoint(
                          text: 'يمكنك العثور على الكود في رسالة تأكيد الحجز',
                        ),
                        _BulletPoint(
                          text: 'بعد البحث ستظهر لك تفاصيل الحجز الكاملة',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/services/image_picker_recovery.dart';
import 'package:loqma/features/provider/data/repositories/provider_completed_work_repository.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';

class ProviderServiceJobsPage extends StatefulWidget {
  const ProviderServiceJobsPage({super.key});

  @override
  State<ProviderServiceJobsPage> createState() => _ProviderServiceJobsPageState();
}

class _ProviderServiceJobsPageState extends State<ProviderServiceJobsPage> {
  final _providerRepository = ServiceProviderRepository();
  final _workRepository = ProviderCompletedWorkRepository();
  bool _loading = true;
  String? _error;
  String? _providerId;
  String? _ownerUserId;
  List<Map<String, dynamic>> _works = [];

  static const _green = Color(0xFF0B7650);
  static const _greenDark = Color(0xFF07533A);
  static const _ink = Color(0xFF123F31);
  static const _muted = Color(0xFF6D8078);
  static const _blue = Color(0xFF3679C8);
  static const _background = Color(0xFFF4F8F6);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await _providerRepository.getCurrentProvider();
    if (!mounted) return;
    await result.fold(
      (error) async => setState(() {
        _loading = false;
        _error = error;
      }),
      (provider) async {
        final providerId = provider['id']?.toString();
        final ownerUserId = provider['user_id']?.toString();
        if (providerId == null || providerId.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'تعذر تحديد حساب مزود الخدمة';
          });
          return;
        }
        if (ownerUserId == null || ownerUserId.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'تعذر تحديد صاحب حساب مزود الخدمة';
          });
          return;
        }
        try {
          final works = await _workRepository.listForProvider(providerId);
          if (!mounted) return;
          setState(() {
            _providerId = providerId;
            _ownerUserId = ownerUserId;
            _works = works;
            _loading = false;
          });
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = error.toString().replaceFirst('Exception: ', '');
          });
        }
      },
    );
  }

  Future<void> _addWork() async {
    final providerId = _providerId;
    final ownerUserId = _ownerUserId;
    if (providerId == null || ownerUserId == null) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddCompletedWorkPage(
          providerId: providerId,
          ownerUserId: ownerUserId,
          repository: _workRepository,
        ),
      ),
    );
    if (added == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تمت إضافة العمل إلى أعمالك المنفذة'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _greenDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 20,
          title: const Text(
            'أعمالي المنفذة',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          iconTheme: const IconThemeData(color: _ink),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: _loading || _providerId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addWork,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'إضافة عمل',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : _error != null
                ? _errorView()
                : RefreshIndicator(
                    color: _green,
                    onRefresh: _load,
                    child: _works.isEmpty
                        ? _emptyView()
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                            itemCount: _works.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              if (index == 0) return _summaryHeader();
                              return _workCard(_works[index - 1]);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _summaryHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'معرض شغلك يوصل للعميل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_works.length} ${_works.length == 1 ? 'عمل منفذ' : 'أعمال منفذة'} موثقة في ملفك',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _addWork,
            tooltip: 'إضافة عمل',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
      children: [
        _summaryHeader(),
        const SizedBox(height: 54),
        Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_library_outlined,
            size: 44,
            color: _blue,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'ابدأ بإضافة أول عمل منفذ',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'أضف صورًا ووصفًا وسعرًا اختياريًا ليشاهد العملاء خبرتك قبل التواصل معك.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.6, fontSize: 13),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _addWork,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('إضافة أول عمل منفذ'),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.red.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 42),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _workCard(Map<String, dynamic> work) {
    final paths = (work['photo_paths'] as List?)
            ?.map((item) => item.toString())
            .where((path) => path.isNotEmpty)
            .toList() ??
        const <String>[];
    final amount = work['amount'];
    final amountText = amount == null ? null : '${_formatAmount(amount)} ج.م';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paths.isNotEmpty) _workGallery(paths),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تاريخ التنفيذ',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _date(work['executed_on']),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (amountText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          amountText,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  work['description']?.toString() ?? '',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.65,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workGallery(List<String> paths) {
    return SizedBox(
      height: 178,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _workRepository.imageUrl(paths.first),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: _blue.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: _blue,
                size: 36,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          if (paths.length > 1)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${paths.length} صور',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (paths.length > 1)
            Positioned(
              left: 12,
              bottom: 12,
              child: SizedBox(
                height: 42,
                width: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length > 4 ? 4 : paths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Image.network(
                        _workRepository.imageUrl(paths[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic value) {
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
  }
}

class _AddCompletedWorkPage extends StatefulWidget {
  const _AddCompletedWorkPage({
    required this.providerId,
    required this.ownerUserId,
    required this.repository,
  });

  final String providerId;
  final String ownerUserId;
  final ProviderCompletedWorkRepository repository;

  @override
  State<_AddCompletedWorkPage> createState() => _AddCompletedWorkPageState();
}

class _AddCompletedWorkPageState extends State<_AddCompletedWorkPage> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _picker = ImagePicker();
  DateTime _executedOn = DateTime.now();
  List<XFile> _images = [];
  bool _saving = false;

  static const _green = Color(0xFF0B7650);
  static const _ink = Color(0xFF123F31);
  static const _muted = Color(0xFF6D8078);
  static const _blue = Color(0xFF3679C8);
  static const _background = Color(0xFFF4F8F6);

  @override
  void initState() {
    super.initState();
    _restoreLostImages();
  }

  Future<void> _restoreLostImages() async {
    try {
      final files = await ImagePickerRecovery.retrieve('provider_completed_work');
      if (!mounted || files.isEmpty) return;
      setState(() => _images = files.take(6).toList());
    } catch (_) {
      // Ignore absent or invalid lost picker data.
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await ImagePickerRecovery.launch(
      context: 'provider_completed_work',
      picker: () => _picker.pickMultiImage(
        limit: 6,
        requestFullMetadata: false,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      ),
    );
    if (!mounted || selected.isEmpty) return;
    final limited = selected.take(6).toList(growable: false);
    setState(() => _images = limited);
    if (selected.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اختيار أول 6 صور فقط')),
      );
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _executedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'اختر تاريخ تنفيذ العمل',
      confirmText: 'اختيار',
      cancelText: 'إلغاء',
    );
    if (selected != null && mounted) setState(() => _executedOn = selected);
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _message('اكتب وصف العمل المنفذ');
      return;
    }
    if (_images.isEmpty) {
      _message('أضف صورة واحدة على الأقل للعمل المنفذ');
      return;
    }
    if (description.length > 1000) {
      _message('الوصف يجب ألا يتجاوز 1000 حرف');
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount < 0)) {
      _message('اكتب مبلغًا صحيحًا أو اتركه فارغًا');
      return;
    }

    setState(() => _saving = true);
    final uploaded = <String>[];
    try {
      for (var index = 0; index < _images.length; index++) {
        uploaded.add(await widget.repository.uploadPhoto(
          ownerUserId: widget.ownerUserId,
          image: _images[index],
          index: index,
        ));
      }
      await widget.repository.create(
        providerId: widget.providerId,
        executedOn: _executedOn,
        description: description,
        amount: amount,
        photoPaths: uploaded,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      try {
        await widget.repository.removePhotos(uploaded);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _saving = false);
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String get _dateLabel =>
      '${_executedOn.day}/${_executedOn.month}/${_executedOn.year}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'إضافة عمل منفذ',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          iconTheme: const IconThemeData(color: _ink),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish_rounded),
              label: Text(
                _saving ? 'جارٍ الحفظ...' : 'نشر العمل المنفذ',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _introCard(),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.event_available_rounded,
              title: 'متى تم تنفيذ العمل؟',
              child: InkWell(
                onTap: _saving ? null : _chooseDate,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _blue.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: _blue),
                      const SizedBox(width: 10),
                      Text(
                        _dateLabel,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'تغيير',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.description_rounded,
              title: 'تفاصيل العمل',
              child: Column(
                children: [
                  TextField(
                    controller: _descriptionController,
                    maxLength: 1000,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: _inputDecoration(
                      label: 'وصف العمل',
                      hint: 'اكتب ما الذي أنجزته، نوع الخدمة، والخامات أو التفاصيل المهمة.',
                      icon: Icons.edit_note_rounded,
                    ).copyWith(alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(
                      label: 'المبلغ (اختياري)',
                      hint: 'مثال: 500',
                      icon: Icons.payments_outlined,
                    ).copyWith(suffixText: 'ج.م'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.photo_library_rounded,
              title: 'صور العمل',
              trailing: Text(
                '${_images.length}/6',
                style: TextStyle(
                  color: _images.isEmpty ? Colors.red.shade700 : _green,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضف صورًا واضحة تساعد العميل على رؤية جودة شغلك.',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (_images.isEmpty)
                    _emptyImagePicker()
                  else
                    _imageGrid(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                      _images.isEmpty ? 'اختيار الصور' : 'تغيير الصور',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: BorderSide(color: _blue.withValues(alpha: 0.35)),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5F6EF), Color(0xFFF7FCFA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _green.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: _green),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اعرض خبرتك بشكل احترافي',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'أضف صورًا حقيقية ووصفًا مختصرًا ليظهر العمل في ملفك للزوار.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _green, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _green),
      filled: true,
      fillColor: const Color(0xFFF8FBF9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _ink.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _ink.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _green, width: 1.5),
      ),
    );
  }

  Widget _emptyImagePicker() {
    return Container(
      height: 150,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _blue.withValues(alpha: 0.25),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: _blue, size: 38),
          SizedBox(height: 8),
          Text(
            'لم تتم إضافة صور بعد',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'اختر صورة واحدة على الأقل',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _imageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, index) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(_images[index].path),
              cacheWidth: 320,
              cacheHeight: 320,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  static const _ink = Color(0xFF123F31);
  static const _blue = Color(0xFF3679C8);

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
          const SnackBar(content: Text('تمت إضافة العمل إلى أعمالك المنفذة')),
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
        backgroundColor: const Color(0xFFF4F8F6),
        appBar: AppBar(
          title: const Text('أعمالي المنفذة'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: _loading || _providerId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addWork,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة عمل منفذ'),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _works.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: const [
                              SizedBox(height: 90),
                              Icon(Icons.handyman_outlined,
                                  size: 58, color: _blue),
                              SizedBox(height: 14),
                              Center(
                                child: Text(
                                  'لم تضف أعمالًا منفذة بعد',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'أضف صورًا ووصفًا وسعرًا اختياريًا ليظهر العمل في ملفك.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                              SizedBox(height: 80),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _works.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) => _workCard(_works[index]),
                          ),
                  ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
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
    final amountText = amount == null
        ? null
        : '${_formatAmount(amount)} ج.م';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 17, color: _blue),
                const SizedBox(width: 6),
                Text(_date(work['executed_on']),
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (amountText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(amountText,
                        style: const TextStyle(
                            color: _green, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(work['description']?.toString() ?? '',
                style: const TextStyle(color: _ink, height: 1.5)),
            if (paths.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _workRepository.imageUrl(paths[index]),
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
  List<Uint8List> _previews = [];
  bool _saving = false;

  static const _green = Color(0xFF0B7650);

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await _picker.pickMultiImage(imageQuality: 82);
    if (!mounted || selected.isEmpty) return;
    final limited = selected.take(6).toList(growable: false);
    final previews = <Uint8List>[];
    for (final image in limited) {
      previews.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() {
      _images = limited;
      _previews = previews;
    });
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
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة عمل منفذ')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'سجّل عملًا أنجزته ليظهر للزوار في ملفك الشخصي.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text('تاريخ التنفيذ',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(
                  '${_executedOn.day}/${_executedOn.month}/${_executedOn.year}'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _descriptionController,
              maxLength: 1000,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'وصف العمل',
                hintText: 'ما الذي أنجزته؟',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ (اختياري)',
                hintText: 'مثال: 500',
                suffixText: 'ج.م',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('صور العمل (حتى 6 صور)',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('إضافة صور'),
                ),
              ],
            ),
            if (_images.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('أضف صورة واحدة على الأقل للعمل المنفذ.',
                    style: TextStyle(color: Colors.black54)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _images.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_previews[index], fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'نشر العمل المنفذ'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

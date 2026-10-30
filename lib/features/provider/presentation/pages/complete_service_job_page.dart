import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loqma/features/provider/data/repositories/service_job_repository.dart';

class CompleteServiceJobPage extends StatefulWidget {
  const CompleteServiceJobPage({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<CompleteServiceJobPage> createState() => _CompleteServiceJobPageState();
}

class _CompleteServiceJobPageState extends State<CompleteServiceJobPage> {
  final _descriptionController = TextEditingController();
  final _repository = ServiceJobRepository();
  final _picker = ImagePicker();
  DateTime _executedOn = DateTime.now();
  List<XFile> _images = [];
  List<Uint8List> _previewBytes = [];
  bool _submitting = false;

  static const _green = Color(0xFF0B7650);
  static const _ink = Color(0xFF123F31);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 82);
    if (!mounted || picked.isEmpty) return;
    final selected = picked.take(6).toList(growable: false);
    final previews = <Uint8List>[];
    for (final image in selected) {
      previews.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() {
      _images = selected;
      _previewBytes = previews;
    });
    if (picked.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اختيار أول 6 صور فقط')),
      );
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _message('اكتب وصفًا قصيرًا للشغلانة');
      return;
    }
    if (description.characters.length > 200) {
      _message('الوصف يجب ألا يتجاوز 200 حرف');
      return;
    }

    setState(() => _submitting = true);
    try {
      final requestId = widget.request['id'].toString();
      final paths = <String>[];
      for (var index = 0; index < _images.length; index++) {
        paths.add(await _repository.uploadPhoto(
          requestId: requestId,
          image: _images[index],
          index: index,
        ));
      }
      await _repository.submitCompletion(
        requestId: requestId,
        executedOn: _executedOn,
        description: description,
        photoPaths: paths,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.request['title']?.toString() ?? 'الشغلانة';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنهاء الشغلانة')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 18),
            const Text('تاريخ التنفيذ', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _executedOn,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null) setState(() => _executedOn = selected);
                    },
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text('${_executedOn.day}/${_executedOn.month}/${_executedOn.year}'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'وصف قصير للشغلانة',
                hintText: 'اكتب ما تم تنفيذه باختصار',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('تجنب تصوير الوجوه أو الأوراق أو الأرقام الخاصة')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Text('صور التنفيذ (حتى 6 صور)', style: TextStyle(fontWeight: FontWeight.w800))),
                TextButton.icon(
                  onPressed: _submitting ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('إضافة صور'),
                ),
              ],
            ),
            if (_images.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('يفضل إضافة صورة قبل وصورة بعد، ويمكن الإرسال بدون صور.'),
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
                itemBuilder: (_, index) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _previewBytes[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: Colors.black54,
                        child: Text(index == 0 ? 'قبل' : index == 1 ? 'بعد' : '${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_submitting ? 'جارٍ الإرسال...' : 'إرسال إنهاء الشغلانة'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

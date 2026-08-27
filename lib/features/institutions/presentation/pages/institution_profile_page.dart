import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../data/repositories/institutions_repository.dart';
import '../../domain/entities/institution.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class InstitutionProfilePage extends StatefulWidget {
  final Institution institution;
  final Future<Uint8List?> Function()? onPickLogo;
  final Future<Uint8List?> Function()? onPickCover;

  const InstitutionProfilePage({
    super.key,
    required this.institution,
    this.onPickLogo,
    this.onPickCover,
  });

  @override
  State<InstitutionProfilePage> createState() => _InstitutionProfilePageState();
}

class _InstitutionProfilePageState extends State<InstitutionProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = InstitutionsRepository();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late String _type;
  Uint8List? _logoBytes;
  Uint8List? _coverBytes;
  bool _saving = false;

  static const _types = <String, String>{
    'bakery': 'مخبز وحلويات',
    'grocery': 'بقالة',
    'game_store': 'محل ألعاب',
    'supermarket': 'سوبر ماركت',
    'cafe': 'كافيه',
    'hotel': 'فندق',
    'other': 'مؤسسة أخرى',
  };

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.institution.name);
    _phone = TextEditingController(text: widget.institution.phone ?? '');
    _city = TextEditingController(text: widget.institution.city ?? '');
    _address = TextEditingController(text: widget.institution.address ?? '');
    _description =
        TextEditingController(text: widget.institution.description ?? '');
    _type = _types.containsKey(widget.institution.type)
        ? widget.institution.type
        : 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (widget.onPickLogo == null) return;
    final bytes = await widget.onPickLogo!();
    if (mounted && bytes != null) setState(() => _logoBytes = bytes);
  }

  Future<void> _pickCover() async {
    if (widget.onPickCover == null) return;
    final bytes = await widget.onPickCover!();
    if (mounted && bytes != null) setState(() => _coverBytes = bytes);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسجيل الخروج. حاول مرة أخرى')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      var logoUrl = widget.institution.logoUrl;
      var coverUrl = widget.institution.coverImageUrl;
      if (_logoBytes != null) {
        logoUrl = await _repository.uploadInstitutionImage(
            bytes: _logoBytes!, fileExtension: 'jpg');
      }
      if (_coverBytes != null) {
        coverUrl = await _repository.uploadInstitutionImage(
            bytes: _coverBytes!, fileExtension: 'jpg', cover: true);
      }
      final updated = await _repository.updateMine(
        name: _name.text,
        institutionType: _type,
        phone: _phone.text,
        city: _city.text,
        address: _address.text,
        description: _description.text,
        logoUrl: logoUrl,
        coverImageUrl: coverUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ بيانات المؤسسة بنجاح')));
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر حفظ بيانات المؤسسة. حاول مرة أخرى')));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ملف المؤسسة'),
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                tooltip: 'المزيد',
                onSelected: (value) {
                  if (value == 'logout') _logout();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded),
                      title: Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _ImageBanner(
                    url: widget.institution.coverImageUrl,
                    bytes: _coverBytes,
                    onTap: widget.onPickCover == null ? null : _pickCover,
                    label: 'صورة الغلاف'),
                const SizedBox(height: 12),
                Center(
                    child: _LogoPicker(
                        url: widget.institution.logoUrl,
                        bytes: _logoBytes,
                        onTap: widget.onPickLogo == null ? null : _pickLogo)),
                const SizedBox(height: 18),
                _field(_name, 'اسم المؤسسة', Icons.business_outlined),
                DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: 'نوع النشاط',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16))),
                    items: _types.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _type = value ?? 'other')),
                const SizedBox(height: 12),
                _field(_phone, 'رقم الهاتف', Icons.phone_outlined),
                _field(_city, 'المدينة', Icons.location_city_outlined),
                _field(_address, 'العنوان', Icons.location_on_outlined),
                _field(_description, 'نبذة عن المؤسسة', Icons.notes_outlined,
                    maxLines: 4),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات')),
              ],
            ),
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16))),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'هذا الحقل مطلوب'
                  : null));
}

class _ImageBanner extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? onTap;
  final String label;
  const _ImageBanner(
      {required this.url,
      required this.bytes,
      required this.onTap,
      required this.label});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
              height: 150,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDEBE4),
                  image: bytes != null
                      ? DecorationImage(
                          image: MemoryImage(bytes!), fit: BoxFit.cover)
                      : (url != null && url!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(url!), fit: BoxFit.cover)
                          : null)),
              child: onTap == null
                  ? const Center(
                      child: Icon(Icons.image_outlined,
                          size: 42, color: Color(0xFF0B7650)))
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.black45,
                          child: Text('اضغط لتغيير $label',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)))))));
}

class _LogoPicker extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? onTap;
  const _LogoPicker(
      {required this.url, required this.bytes, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? imageProvider = bytes != null
        ? MemoryImage(bytes!) as ImageProvider<Object>
        : (url != null && url!.trim().isNotEmpty
            ? NetworkImage(url!.trim()) as ImageProvider<Object>
            : null);

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFDDEBE4),
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.business, size: 42, color: Color(0xFF0B7650))
            : null,
      ),
    );
  }
}

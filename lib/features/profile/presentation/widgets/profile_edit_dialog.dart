import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/storage_service.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';

class ProfileEditDialog extends StatefulWidget {
  final UserModel user;

  const ProfileEditDialog({super.key, required this.user});

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  XFile? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: height * .86),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تعديل الملف الشخصي',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _avatar(colors),
                const SizedBox(height: 22),
                if (_errorMessage != null) ...[
                  _errorBox(colors),
                  const SizedBox(height: 12),
                ],
                _field(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                  requiredField: true,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _cityController,
                  label: 'المدينة',
                  icon: Icons.location_city_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _addressController,
                  label: 'العنوان',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label:
                            Text(_isLoading ? 'جارٍ الحفظ' : 'حفظ التغييرات'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(ColorScheme colors) {
    final initial = widget.user.name.trim().isEmpty
        ? 'ل'
        : widget.user.name.trim().characters.first.toUpperCase();

    return GestureDetector(
      onTap: _isLoading ? null : _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: colors.primary.withAlpha(25),
            backgroundImage: widget.user.avatarUrl?.trim().isNotEmpty == true
                ? NetworkImage(widget.user.avatarUrl!.trim())
                : null,
            child: _selectedImage == null &&
                    widget.user.avatarUrl?.trim().isNotEmpty != true
                ? Text(
                    initial,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : (_selectedImage == null
                    ? null
                    : ClipOval(
                        child: FutureBuilder<List<int>>(
                          future: _selectedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            return Image.memory(
                              Uint8List.fromList(snapshot.data!),
                              width: 108,
                              height: 108,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      )),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: colors.primary,
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(ColorScheme colors) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _errorMessage!,
          style: TextStyle(color: colors.onErrorContainer),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: requiredField
          ? (value) =>
              value == null || value.trim().length < 3 ? '$label مطلوب' : null
          : null,
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (!mounted || image == null) return;
      setState(() {
        _selectedImage = image;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذر اختيار الصورة');
    }
  }

  Future<void> _handleSave() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await StorageService.instance.uploadAvatar(
          userId: widget.user.id,
          imageFile: _selectedImage!,
        );
        if (avatarUrl == null || avatarUrl.isEmpty) {
          throw StateError('avatar_upload_failed');
        }
      }

      if (!mounted) return;
      context.read<ProfileBloc>().add(ProfileUpdateUser(
            name: _nameController.text,
            phone: _phoneController.text,
            city: _cityController.text,
            address: _addressController.text,
            avatarUrl: avatarUrl,
          ));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر حفظ التغييرات حاليًا';
      });
    }
  }
}

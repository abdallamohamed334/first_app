import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CharityVolunteersManagementPage extends StatefulWidget {
  const CharityVolunteersManagementPage({super.key});

  @override
  State<CharityVolunteersManagementPage> createState() =>
      _CharityVolunteersManagementPageState();
}

class _CharityVolunteersManagementPageState
    extends State<CharityVolunteersManagementPage> {
  static const Color primary = Color(0xFF001E15);
  static const Color green = Color(0xFF006C48);
  static const Color mint = Color(0xFF97F2C3);
  static const Color background = Color(0xFFF8FAFA);

  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _volunteersFuture;
  String _filter = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _volunteersFuture = _loadVolunteers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _loadVolunteers() async {
    final authUserId = _client.auth.currentUser?.id;
    if (authUserId == null || authUserId.isEmpty) {
      throw StateError('انتهت جلسة الجمعية، يرجى تسجيل الدخول مرة أخرى');
    }

    final charity = await _client
        .from('charities')
        .select('id')
        .eq('user_id', authUserId)
        .maybeSingle();

    if (charity == null) {
      throw StateError('لا توجد جمعية مرتبطة بالحساب الحالي');
    }

    final response = await _client.rpc(
      'list_my_charity_volunteers_manage_with_identity',
      params: {'p_charity_id': charity['id']},
    );

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() async {
    final nextFuture = _loadVolunteers();
    if (!mounted) return;

    setState(() {
      _volunteersFuture = nextFuture;
    });

    await nextFuture;
  }

  List<Map<String, dynamic>> _filteredRows(
    List<Map<String, dynamic>> rows,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return rows.where((row) {
      final status = row['status']?.toString().toLowerCase() ?? 'inactive';
      final matchesFilter = _filter == 'all' ||
          (_filter == 'active' && status == 'active') ||
          (_filter == 'inactive' && status != 'active');

      final searchableText = [
        row['name'],
        row['phone'],
        row['national_id'],
        row['id_number'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');

      return matchesFilter && (query.isEmpty || searchableText.contains(query));
    }).toList();
  }

  Future<void> _showVolunteerForm({Map<String, dynamic>? volunteer}) async {
    final nameController = TextEditingController(
      text: volunteer?['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: volunteer?['phone']?.toString() ?? '',
    );
    final nationalIdController = TextEditingController(
      text: volunteer?['national_id']?.toString() ??
          volunteer?['id_number']?.toString() ??
          '',
    );
    final formKey = GlobalKey<FormState>();
    XFile? selectedAvatar;
    Uint8List? selectedAvatarBytes;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ImageProvider<Object>? avatarImage;
            if (selectedAvatarBytes != null) {
              avatarImage = MemoryImage(selectedAvatarBytes!);
            } else if (volunteer?['avatar_url']?.toString().isNotEmpty ??
                false) {
              avatarImage = NetworkImage(volunteer!['avatar_url'].toString());
            } else {
              avatarImage = null;
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: const BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC7D0CB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: mint.withAlpha(90),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded,
                                  color: green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    volunteer == null
                                        ? 'إضافة متطوع جديد'
                                        : 'تعديل بيانات المتطوع',
                                    style: const TextStyle(
                                        color: primary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text('أكمل البيانات الأساسية للفريق',
                                      style: TextStyle(
                                          color: Color(0xFF64756D),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(false),
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF64756D)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(48),
                            onTap: () async {
                              final image = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 82,
                                maxWidth: 900,
                              );
                              if (image != null) {
                                final bytes = await image.readAsBytes();
                                if (bytes.isNotEmpty) {
                                  setSheetState(() {
                                    selectedAvatar = image;
                                    selectedAvatarBytes = bytes;
                                  });
                                }
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 47,
                                  backgroundColor: const Color(0xFFE3F2EB),
                                  backgroundImage: avatarImage,
                                  child: selectedAvatarBytes == null &&
                                          !(volunteer?['avatar_url']
                                                  ?.toString()
                                                  .isNotEmpty ??
                                              false)
                                      ? const Icon(Icons.person_rounded,
                                          color: green, size: 44)
                                      : null,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                        color: primary, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: mint, size: 17),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                            child: Text(
                                selectedAvatar == null
                                    ? 'اضغط لاختيار صورة'
                                    : 'تم اختيار صورة جديدة',
                                style: const TextStyle(
                                    color: green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12))),
                        const SizedBox(height: 22),
                        _formLabel('البيانات الأساسية'),
                        const SizedBox(height: 10),
                        _formField(
                            controller: nameController,
                            label: 'الاسم الكامل',
                            icon: Icons.badge_outlined,
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                    ? 'اكتب اسمًا صحيحًا'
                                    : null),
                        const SizedBox(height: 12),
                        _formField(
                            controller: phoneController,
                            label: 'رقم الهاتف',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value == null || value.trim().length < 7
                                    ? 'اكتب رقم هاتف صحيحًا'
                                    : null),
                        const SizedBox(height: 12),
                        _formField(
                            controller: nationalIdController,
                            label: 'رقم البطاقة الشخصية',
                            hint: '14 رقمًا — يظهر للجمعية فقط',
                            icon: Icons.credit_card_outlined,
                            keyboardType: TextInputType.number,
                            maxLength: 14,
                            validator: (value) => !RegExp(r'^\d{14}$')
                                    .hasMatch(value?.trim() ?? '')
                                ? 'رقم البطاقة يجب أن يتكون من 14 رقمًا'
                                : null),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                                child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(false),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                        side: const BorderSide(
                                            color: Color(0xFFC0C8C3)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15))),
                                    child: const Text('إلغاء'))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: FilledButton.icon(
                                    onPressed: () {
                                      if (formKey.currentState?.validate() ??
                                          false) {
                                        Navigator.of(sheetContext).pop(true);
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: mint,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15))),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('حفظ البيانات'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      String? avatarUrl = volunteer?['avatar_url']?.toString();
      if (selectedAvatar != null && selectedAvatarBytes != null) {
        final bytes = selectedAvatarBytes!;
        if (bytes.isEmpty) throw Exception('الصورة المختارة فارغة');
        final extension =
            selectedAvatar!.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final authUserId = _client.auth.currentUser?.id;
        if (authUserId == null || authUserId.isEmpty) {
          throw Exception('انتهت جلسة الجمعية');
        }
        final charity = await _client
            .from('charities')
            .select('id')
            .eq('user_id', authUserId)
            .eq('status', 'active')
            .maybeSingle();
        final charityId = charity?['id']?.toString();
        if (charityId == null || charityId.isEmpty) {
          throw Exception('لا توجد جمعية نشطة مرتبطة بالحساب');
        }
        final path =
            'charity-volunteers/$charityId/${DateTime.now().microsecondsSinceEpoch}.$extension';
        await _client.storage.from('avatars').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );
        avatarUrl = _client.storage.from('avatars').getPublicUrl(path);
      }

      final params = <String, dynamic>{
        'p_name': nameController.text.trim(),
        'p_phone': phoneController.text.trim(),
        'p_national_id': nationalIdController.text.trim(),
        'p_avatar_url': avatarUrl,
      };
      if (volunteer == null) {
        await _client.rpc(
          'create_my_charity_volunteer_with_identity',
          params: params,
        );
      } else {
        await _client.rpc(
          'update_my_charity_volunteer_with_identity',
          params: {
            ...params,
            'p_volunteer_id': volunteer['id'],
            'p_status': volunteer['status'] ?? 'active',
          },
        );
      }

      _showMessage('تم حفظ بيانات المتطوع بنجاح');
      await _refresh();
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      nameController.dispose();
      phoneController.dispose();
      nationalIdController.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Widget _formLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: primary, fontSize: 13, fontWeight: FontWeight.w900),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(color: primary, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: green),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8E1DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8E1DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _toggleVolunteer(Map<String, dynamic> volunteer) async {
    final currentStatus = volunteer['status']?.toString() ?? 'inactive';
    final nextStatus = currentStatus == 'active' ? 'inactive' : 'active';

    setState(() {
      _busy = true;
    });

    try {
      await _client.rpc(
        'update_my_charity_volunteer',
        params: {
          'p_volunteer_id': volunteer['id'],
          'p_name': volunteer['name'],
          'p_phone': volunteer['phone'],
          'p_status': nextStatus,
        },
      );

      _showMessage(
          nextStatus == 'active' ? 'تم تنشيط المتطوع' : 'تم إيقاف المتطوع');
      await _refresh();
    } catch (error) {
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('row-level') ||
        raw.contains('42501') ||
        raw.contains('permission denied') ||
        raw.contains('not authorized')) {
      return 'لا تملك الجمعية صلاحية تنفيذ هذه العملية. تأكد من حساب الجمعية وحاول مرة أخرى.';
    }
    if (raw.contains('storage') ||
        raw.contains('upload') ||
        raw.contains('bucket') ||
        raw.contains('object')) {
      return 'تعذر رفع صورة المتطوع. اختر صورة أخرى وحاول مرة ثانية.';
    }
    if (raw.contains('national_id') || raw.contains('البطاقة')) {
      return 'رقم البطاقة غير صحيح أو مستخدم بالفعل.';
    }
    if (raw.contains('phone') || raw.contains('الهاتف')) {
      return 'رقم الهاتف غير صحيح.';
    }
    if (raw.contains('network') || raw.contains('timeout')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    return 'تعذر حفظ بيانات المتطوع حاليًا. حاول مرة أخرى.';
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: primary,
          surfaceTintColor: background,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: const Text('المتطوعون',
              style: TextStyle(
                  color: primary, fontSize: 22, fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _volunteersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: green));
            }
            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }

            final rows = snapshot.data ?? <Map<String, dynamic>>[];
            final visibleRows = _filteredRows(rows);
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontal = width >= 900
                    ? 32.0
                    : width >= 600
                        ? 24.0
                        : 16.0;
                final columns = width >= 1250
                    ? 4
                    : width >= 900
                        ? 3
                        : width >= 620
                            ? 2
                            : 1;
                final gap = width >= 600 ? 16.0 : 12.0;
                final cardWidth = columns == 1
                    ? width - (horizontal * 2)
                    : (width - (horizontal * 2) - (gap * (columns - 1))) /
                        columns;

                return Stack(
                  children: [
                    RefreshIndicator(
                      color: green,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            EdgeInsets.fromLTRB(horizontal, 6, horizontal, 110),
                        children: [
                          _referenceHeader(rows.length, width),
                          const SizedBox(height: 22),
                          _stats(rows),
                          const SizedBox(height: 24),
                          _searchField(),
                          const SizedBox(height: 12),
                          _filterChips(),
                          const SizedBox(height: 22),
                          if (visibleRows.isEmpty)
                            _emptyState()
                          else
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: visibleRows
                                  .map((row) => SizedBox(
                                      width: cardWidth,
                                      child: _volunteerCard(row)))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    if (_busy)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x33001E15),
                          child: Center(
                              child: CircularProgressIndicator(color: mint)),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _showVolunteerForm(),
          backgroundColor: primary,
          foregroundColor: mint,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة متطوع جديد',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _referenceHeader(int total, double width) {
    final compact = width < 520;
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [primary, Color(0xFF0B7650)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
              color: Color(0x18001E15), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _headerCopy(),
              const SizedBox(height: 18),
              _headerCount(total)
            ])
          : Row(
              children: [Expanded(child: _headerCopy()), _headerCount(total)]),
    );
  }

  Widget _headerCopy() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('فريق الجمعية',
            style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('إدارة فريق المتطوعين ومتابعة جاهزيتهم لمهام التوصيل بكفاءة.',
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13)),
      ],
    );
  }

  Widget _headerCount(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24)),
      child: Column(children: [
        const Text('إجمالي الفريق',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$total',
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))
      ]),
    );
  }

  Widget _header(int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primary, green]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فريق الجمعية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'أضف المتطوعين وتابع جاهزيتهم لمهام التبرع',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Text(
              '$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(List<Map<String, dynamic>> rows) {
    final active = rows.where((row) => row['status'] == 'active').length;
    final inactive = rows.length - active;

    return Row(
      children: [
        Expanded(
            child: _statCard(
                'الإجمالي', '${rows.length}', Icons.groups_rounded, primary)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard('نشط', '$active', Icons.verified_rounded, green)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard('متوقف', '$inactive',
                Icons.pause_circle_outline_rounded, Colors.redAccent)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 7),
          Text(value,
              style: const TextStyle(
                  color: primary, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: 'ابحث بالاسم أو الهاتف',
        prefixIcon: const Icon(Icons.search_rounded, color: green),
        suffixIcon: IconButton(
          onPressed: _busy ? null : () => _showVolunteerForm(),
          icon: const Icon(Icons.person_add_alt_1_rounded, color: green),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC0C8C3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC0C8C3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const filters = <String, String>{
      'all': 'الكل',
      'active': 'نشط',
      'inactive': 'غير نشط',
    };

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilterChip(
              selected: selected,
              label: Text(entry.value),
              onSelected: (_) => setState(() => _filter = entry.key),
              selectedColor: mint,
              checkmarkColor: green,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? green : const Color(0xFFC0C8C3),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _volunteerCard(Map<String, dynamic> volunteer) {
    final active = volunteer['status'] == 'active';
    final avatarUrl = volunteer['avatar_url']?.toString();
    final name = volunteer['name']?.toString() ?? 'متطوع بدون اسم';
    final phone = volunteer['phone']?.toString() ?? 'رقم غير متاح';
    final nationalId = volunteer['national_id']?.toString() ??
        volunteer['id_number']?.toString() ??
        'غير متاح';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D001E15), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statusBadge(active),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed:
                  _busy ? null : () => _showVolunteerForm(volunteer: volunteer),
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFF64756D), size: 19),
            ),
          ]),
          const SizedBox(height: 2),
          CircleAvatar(
            radius: 43,
            backgroundColor:
                active ? const Color(0xFFE0F5EA) : const Color(0xFFE7ECE9),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Icon(active ? Icons.person_rounded : Icons.person_off_rounded,
                    color: active ? green : Colors.black45, size: 38)
                : null,
          ),
          const SizedBox(height: 12),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: primary, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(phone,
              style: const TextStyle(
                  color: Color(0xFF64756D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFFF2F7F4),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.credit_card_outlined, color: green, size: 17),
              const SizedBox(width: 7),
              Expanded(
                  child: Text('رقم البطاقة: $nationalId',
                      style: const TextStyle(
                          color: Color(0xFF486159),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis))
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _showVolunteerForm(volunteer: volunteer),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: const BorderSide(color: Color(0xFFD4DFD9)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    child: const Text('تعديل'))),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton(
                    onPressed: _busy ? null : () => _toggleVolunteer(volunteer),
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            active ? const Color(0xFFB3261E) : green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    child: Text(active ? 'إيقاف' : 'تنشيط'))),
          ]),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE3F7EC) : const Color(0xFFF4E7E7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'نشط' : 'غير نشط',
        style: TextStyle(
          color: active ? green : Colors.red.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, color: green, size: 54),
          const SizedBox(height: 12),
          const Text(
            'لا يوجد متطوعون بهذا البحث أو الفلتر',
            style: TextStyle(color: primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : () => _showVolunteerForm(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة متطوع'),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 46),
            const SizedBox(height: 12),
            Text(error.replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _refresh,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

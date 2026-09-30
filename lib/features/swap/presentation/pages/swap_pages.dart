import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/swap/data/swap_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class SwapListingsPage extends StatefulWidget {
  const SwapListingsPage({super.key});
  @override State<SwapListingsPage> createState() => _SwapListingsPageState();
}
class _SwapListingsPageState extends State<SwapListingsPage> {
  final _repo = SwapRepository();
  final _search = TextEditingController();
  static const _governorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'الشرقية', 'القليوبية',
    'الغربية', 'المنوفية', 'البحيرة', 'كفر الشيخ', 'دمياط', 'بورسعيد',
    'الإسماعيلية', 'السويس', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط',
    'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'مطروح', 'شمال سيناء', 'جنوب سيناء',
  ];
  late Future<List<Map<String, dynamic>>> _future;
  String? _governorate;
  @override void initState() { super.initState(); _future = _repo.listOpenListings(); }
  @override void dispose() { _search.dispose(); super.dispose(); }
  void _reload() => setState(() => _future = _repo.listOpenListings(search: _search.text, governorate: _governorate));
  @override Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('عروض الاستبدال'), actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySwapsPage())), icon: const Icon(Icons.swap_horizontal_circle_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () async { final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSwapListingPage())); if (ok == true) _reload(); }, icon: const Icon(Icons.add_rounded), label: const Text('إضافة استبدال')),
      body: RefreshIndicator(onRefresh: () async => _reload(), child: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: c.primary));
        if (snap.hasError) return _StateMessage(title: 'تعذر تحميل الاستبدالات', onRetry: _reload);
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          _IntroCard(color: c.primary), const SizedBox(height: 12),
          TextField(controller: _search, onSubmitted: (_) => _reload(), textInputAction: TextInputAction.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن شيء مطلوب...')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _governorate,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined), labelText: 'فلترة بالمحافظة', hintText: 'كل المحافظات'),
            items: [const DropdownMenuItem<String>(value: null, child: Text('كل المحافظات')), ..._governorates.map((g) => DropdownMenuItem(value: g, child: Text(g)))],
            onChanged: (value) { _governorate = value; _reload(); },
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('عروض الاستبدال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('${rows.length} عرض', style: TextStyle(color: c.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const _StateMessage(title: 'لا توجد استبدالات منشورة حاليًا')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: .68,
              ),
              itemBuilder: (context, index) {
                final r = rows[index];
                return _ListingCard(row: r, onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => SwapDetailsPage(listingId: r['id'].toString())));
                  if (mounted) _reload();
                });
              },
            ),
        ]);
      })),
    ));
  }
}

class CreateSwapListingPage extends StatefulWidget {
  const CreateSwapListingPage({super.key});
  @override
  State<CreateSwapListingPage> createState() => _CreateSwapListingPageState();
}

class _CreateSwapListingPageState extends State<CreateSwapListingPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _category = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _repo = SwapRepository();
  final _picker = ImagePicker();
  XFile? _image;
  String? _governorate;
  String _condition = 'any';
  bool _busy = false;

  static const _governorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'الشرقية', 'القليوبية',
    'الغربية', 'المنوفية', 'البحيرة', 'كفر الشيخ', 'دمياط', 'بورسعيد',
    'الإسماعيلية', 'السويس', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط',
    'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'مطروح', 'شمال سيناء', 'جنوب سيناء',
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _category.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final imageUrl = _image == null ? null : await _repo.uploadListingImage(_image!);
      await _repo.createListing(
        wantedTitle: _title.text,
        description: _desc.text,
        category: _category.text,
        wantedCondition: _condition,
        contactPhone: _phone.text,
        contactWhatsapp: _whatsapp.text,
        images: imageUrl == null ? const [] : [imageUrl],
        governorate: _governorate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
    if (image != null && mounted) setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة استبدال')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('اطلب الشيء الذي تريد الحصول عليه', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('مثال: أريد استبدال لابتوب قديم بآيفون 11. سيظهر إعلانك لكل المستخدمين.'),
              const SizedBox(height: 22),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'ما الشيء المطلوب؟', hintText: 'مثال: iPhone 11'),
                validator: (v) => v == null || v.trim().length < 3 ? 'اكتب الشيء المطلوب' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'التفاصيل', hintText: 'اشرح ما الذي ستقدمه أو حالة الشيء الذي تريد استبداله...'),
                validator: (v) => v == null || v.trim().length < 10 ? 'اكتب تفاصيل أكثر' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'التصنيف', hintText: 'إلكترونيات، ملابس، أثاث...')),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل', hintText: '01012345678'),
                validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رقم الهاتف' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم واتساب', hintText: '01012345678'),
                validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رقم الواتساب' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _governorate,
                decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.location_on_outlined)),
                items: _governorates.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => _governorate = value),
                validator: (value) => value == null ? 'اختار المحافظة' : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _busy ? null : _pickImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _image == null
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, size: 38),
                          SizedBox(height: 8),
                          Text('إضافة صورة للشيء المراد استبداله'),
                        ])
                      : Image.file(File(_image!.path), fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'الحالة المطلوبة'),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('أي حالة')),
                  DropdownMenuItem(value: 'new', child: Text('جديد')),
                  DropdownMenuItem(value: 'like_new', child: Text('شبه جديد')),
                  DropdownMenuItem(value: 'good', child: Text('جيد')),
                  DropdownMenuItem(value: 'used', child: Text('مستعمل')),
                ],
                onChanged: (v) => setState(() => _condition = v ?? 'any'),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_rounded),
                label: const Text('نشر الاستبدال'),
                style: FilledButton.styleFrom(backgroundColor: c.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwapDetailsPage extends StatefulWidget {
  final String listingId;
  const SwapDetailsPage({super.key, required this.listingId});
  @override
  State<SwapDetailsPage> createState() => _SwapDetailsPageState();
}

class _SwapDetailsPageState extends State<SwapDetailsPage> {
  final _repo = SwapRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getListing(widget.listingId);
  }

  void _reload() => setState(() => _future = _repo.getListing(widget.listingId));

  Future<void> _addProposal() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProposalSheet(listingId: widget.listingId, repo: _repo),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الاستبدال')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(child: snap.hasError ? const Text('تعذر تحميل التفاصيل') : CircularProgressIndicator(color: c.primary));
            }
            final r = snap.data!;
            final proposals = (r['proposals'] as List? ?? []).cast<Map<String, dynamic>>();
            final owner = r['owner_id']?.toString() == _repo.currentUserId;
            final images = (r['images'] as List? ?? []).map((e) => e.toString()).toList();
            final user = r['users'] as Map?;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                _SwapImageStrip(images: images),
                const SizedBox(height: 16),
                Text(r['wanted_title']?.toString() ?? '', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 18, color: c.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${r['city'] ?? r['governorate'] ?? 'الموقع غير محدد'} • قريب منك', style: TextStyle(color: c.onSurfaceVariant, fontSize: 15)),
                ]),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      CircleAvatar(radius: 27, backgroundColor: c.primary, child: Icon(Icons.person_rounded, color: c.onPrimary, size: 30)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?['name']?.toString() ?? 'صاحب الإعلان', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        Text(r['city']?.toString() ?? r['governorate']?.toString() ?? 'مستخدم', style: TextStyle(color: c.onSurfaceVariant)),
                      ])),
                      if (!owner) IconButton(onPressed: () => _ContactCard.showContact(context, phone: r['contact_phone']?.toString(), whatsapp: r['contact_whatsapp']?.toString()), icon: const Icon(Icons.chat_bubble_outline_rounded)),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                _DetailsSection(title: 'وصف المنتج', child: Text(r['description']?.toString() ?? '', style: const TextStyle(fontSize: 16, height: 1.55))),
                _DetailsSection(title: 'حالة المنتج', child: Text(_conditionLabel(r['wanted_condition']?.toString()), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                _DetailsSection(title: 'القسم', child: Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(r['category']?.toString() ?? 'أخرى')), Chip(label: Text('استبدال'))])),
                _ContactCard(phone: r['contact_phone']?.toString(), whatsapp: r['contact_whatsapp']?.toString()),
                const SizedBox(height: 18),
                Text('العروض المقترحة (${proposals.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (proposals.isEmpty) const _StateMessage(title: 'لم يضف أحد عرضًا مقابلًا بعد') else ...proposals.map((p) => _ProposalCard(proposal: p, isOwner: owner, repo: _repo, onChanged: _reload)),
                if (!owner && r['status'] == 'open') ...[
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _addProposal, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('تبديل'))),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SwapImageStrip extends StatelessWidget {
  final List<String> images;
  const _SwapImageStrip({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: images.first,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: 1080,
          maxWidthDiskCache: 1080,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 42)),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String? phone;
  final String? whatsapp;
  const _ContactCard({this.phone, this.whatsapp});

  static Future<void> showContact(BuildContext context, {String? phone, String? whatsapp}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: _ContactCard(phone: phone, whatsapp: whatsapp))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    final hasWhatsapp = whatsapp != null && whatsapp!.trim().isNotEmpty;
    if (!hasPhone && !hasWhatsapp) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تواصل مع صاحب الإعلان', style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (hasPhone) OutlinedButton.icon(onPressed: () => _launchPhone(phone!), icon: const Icon(Icons.phone_rounded), label: Text(phone!)),
        if (hasWhatsapp) FilledButton.icon(onPressed: () => _launchWhatsapp(whatsapp!), icon: const Icon(Icons.chat_rounded), label: Text('واتساب ${whatsapp!}')),
      ]),
    ])));
  }
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      child,
    ]),
  );
}

Future<void> _launchPhone(String value) async {
  final phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> _launchWhatsapp(String value) async {
  var phone = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.startsWith('0')) phone = '20${phone.substring(1)}';
  if (!phone.startsWith('20') && phone.length == 10) phone = '20$phone';
  final uri = Uri.parse('https://wa.me/$phone');
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ProposalSheet extends StatefulWidget {
  final String listingId;
  final SwapRepository repo;
  const _ProposalSheet({required this.listingId, required this.repo});
  @override
  State<_ProposalSheet> createState() => _ProposalSheetState();
}

class _ProposalSheetState extends State<_ProposalSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _condition = 'good';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repo.createProposal(
        listingId: widget.listingId,
        offeredTitle: _title.text,
        offeredDescription: _desc.text,
        offeredCondition: _condition,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ماذا ستقدم في المقابل؟', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'اسم الشيء'), validator: (v) => v == null || v.trim().length < 3 ? 'مطلوب' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _desc, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'تفاصيل الشيء وحالته'), validator: (v) => v == null || v.trim().length < 10 ? 'اكتب تفاصيل أكثر' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _condition,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'like_new', child: Text('شبه جديد')),
                DropdownMenuItem(value: 'good', child: Text('جيد')),
                DropdownMenuItem(value: 'used', child: Text('مستعمل')),
                DropdownMenuItem(value: 'needs_repair', child: Text('يحتاج إصلاح')),
              ],
              onChanged: (v) => setState(() => _condition = v ?? 'good'),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'جارٍ الإرسال...' : 'إرسال العرض'))),
          ],
        ),
      ),
    );
  }
}

class MySwapsPage extends StatefulWidget {
  const MySwapsPage({super.key});
  @override State<MySwapsPage> createState() => _MySwapsPageState();
}

class _MySwapsPageState extends State<MySwapsPage> with SingleTickerProviderStateMixin {
  final _repo = SwapRepository();
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _proposals;
  late Future<List<Map<String, dynamic>>> _listings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  void _load() {
    _proposals = _repo.myProposals();
    _listings = _repo.myListings();
    if (mounted) setState(() {});
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استبدالاتي', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'عروضي'), Tab(text: 'النشطة'), Tab(text: 'المنتهية')]),
        ),
        body: TabBarView(controller: _tabs, children: [
          _ProposalList(future: _proposals, repo: _repo, reload: _load),
          _MyListingList(future: _listings, ended: false, repo: _repo, reload: _load),
          _MyListingList(future: _listings, ended: true, repo: _repo, reload: _load),
        ]),
      ),
    );
  }
}

class _ProposalList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final SwapRepository repo;
  final VoidCallback reload;
  const _ProposalList({required this.future, required this.repo, required this.reload});

  @override
  Widget build(BuildContext context) => _asyncList(future, (r) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.call_made_rounded)),
      title: Text(r['offered_title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('على: ${(r['swap_listings'] as Map?)?['wanted_title'] ?? ''}\n${_statusLabel(r['status'])}'),
      isThreeLine: true,
      trailing: r['status'] == 'pending' ? IconButton(onPressed: () async { await repo.updateProposalStatus(proposalId: r['id'].toString(), status: 'withdrawn'); reload(); }, icon: const Icon(Icons.cancel_outlined)) : null,
    ),
  ));
}

class _MyListingList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MyListingList({required this.future, required this.ended, required this.repo, required this.reload});

  bool _isEnded(Map<String, dynamic> row) {
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    return row['status'] != 'open' || (expires != null && !expires.isAfter(DateTime.now().toUtc()));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _StateMessage(title: 'تعذر تحميل استبدالاتك');
      final rows = (snapshot.data ?? []).where((r) => _isEnded(r) == ended).toList();
      if (rows.isEmpty) return _StateMessage(title: ended ? 'لا توجد استبدالات منتهية' : 'لا توجد استبدالات نشطة');
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _MySwapCard(row: row, ended: ended, repo: repo, reload: reload);
        },
      );
    },
  );
}

class _MySwapCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MySwapCard({required this.row, required this.ended, required this.repo, required this.reload});

  Future<bool> _confirm(BuildContext context, {required String title, required String message, required String action}) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images = (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (images.isNotEmpty)
          SizedBox(height: 190, width: double.infinity, child: CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, memCacheWidth: 900, maxWidthDiskCache: 900, placeholder: (_, __) => Center(child: CircularProgressIndicator(color: c.primary)), errorWidget: (_, __, ___) => Icon(Icons.image_not_supported_outlined, size: 44, color: c.onSurfaceVariant)))
        else
          SizedBox(height: 120, child: Center(child: Icon(Icons.swap_horiz_rounded, size: 54, color: c.onSurfaceVariant))),
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: Text(row['wanted_title']?.toString() ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${row['governorate'] ?? 'المحافظة غير محددة'} • ${_statusLabel(ended ? 'expired' : row['status'])}', style: TextStyle(color: c.onSurfaceVariant, fontWeight: FontWeight.w700))),
        Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (!ended) TextButton.icon(onPressed: () async { if (await _confirm(context, title: 'إلغاء الاستبدال؟', message: 'سيتم إغلاق الإعلان ولن يستطيع أحد إرسال عرض جديد عليه.', action: 'إلغاء الاستبدال')) { await repo.closeListing(row['id'].toString()); reload(); } }, icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء')),
          if (ended) TextButton.icon(onPressed: () async { if (await _confirm(context, title: 'إخفاء الاستبدال؟', message: 'سيختفي الإعلان من استبدالاتك فقط ولن يتم حذفه من قاعدة البيانات.', action: 'إخفاء')) { await repo.hideListing(row['id'].toString()); reload(); } }, icon: const Icon(Icons.visibility_off_outlined), label: const Text('إخفاء')),
          const SizedBox(width: 4),
          OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwapDetailsPage(listingId: row['id'].toString()))), child: const Text('التفاصيل')),
        ])),
      ]),
    );
  }
}

Widget _asyncList(Future<List<Map<String, dynamic>>> future, Widget Function(Map<String, dynamic>) item) => FutureBuilder<List<Map<String, dynamic>>>(
  future: future,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return const _StateMessage(title: 'تعذر تحميل البيانات');
    final rows = snapshot.data ?? [];
    return rows.isEmpty ? const _StateMessage(title: 'لا توجد استبدالات هنا') : ListView(padding: const EdgeInsets.all(16), children: rows.map(item).toList());
  },
);

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final bool isOwner;
  final SwapRepository repo;
  final VoidCallback onChanged;
  const _ProposalCard({required this.proposal, required this.isOwner, required this.repo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final user = proposal['users'] as Map?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(proposal['offered_title']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(proposal['offered_description']?.toString() ?? ''),
          const SizedBox(height: 6),
          Text('من: ${user?['name'] ?? 'مستخدم'} • ${_statusLabel(proposal['status'])}', style: TextStyle(color: c.onSurfaceVariant)),
          if (isOwner && proposal['status'] == 'pending')
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () async { await repo.updateProposalStatus(proposalId: proposal['id'].toString(), status: 'rejected'); onChanged(); }, child: const Text('رفض')),
              FilledButton(onPressed: () async { await repo.updateProposalStatus(proposalId: proposal['id'].toString(), status: 'accepted'); onChanged(); }, child: const Text('قبول')),
            ]),
        ]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _ListingCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images = (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              images.isNotEmpty
                  ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, memCacheWidth: 720, maxWidthDiskCache: 720, fadeInDuration: const Duration(milliseconds: 120), placeholder: (_, __) => _imageFallback(c), errorWidget: (_, __, ___) => _imageFallback(c))
                  : _imageFallback(c),
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 20),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 9),
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xDD000000)])),
                  child: Text('مطلوب: ${row['wanted_title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: c.primaryContainer, child: Icon(Icons.person_rounded, size: 14, color: c.onPrimaryContainer)),
              const SizedBox(width: 6),
              Expanded(child: Text('${row['governorate'] ?? 'المحافظة'} • ${_conditionLabel(row['wanted_condition']?.toString())}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _imageFallback(ColorScheme c) => Container(color: c.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.swap_horiz_rounded, size: 52, color: c.onSurfaceVariant));
}

class _IntroCard extends StatelessWidget {
  final Color color;
  const _IntroCard({required this.color});
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: const Padding(
      padding: EdgeInsets.all(20),
      child: Row(children: [
        Icon(Icons.swap_horizontal_circle_rounded, color: Colors.white, size: 42),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('استبدل بدل ما تشتري', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('انشر ما تريد، واستقبل عروضًا من المجتمع.', style: TextStyle(color: Colors.white70)),
        ])),
      ]),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final String title;
  final VoidCallback? onRetry;
  const _StateMessage({required this.title, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Icon(Icons.swap_horizontal_circle_outlined, size: 52, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
    ]),
  );
}

String _conditionLabel(String? v) => {'any': 'أي حالة', 'new': 'جديد', 'like_new': 'شبه جديد', 'good': 'جيد', 'used': 'مستعمل', 'needs_repair': 'يحتاج إصلاح'}[v] ?? 'غير محدد';
String _statusLabel(Object? v) => {'pending': 'في الانتظار', 'accepted': 'مقبول', 'rejected': 'مرفوض', 'withdrawn': 'مسحوب', 'open': 'مفتوح', 'closed': 'مغلق', 'cancelled': 'ملغي', 'expired': 'منتهي'}[v?.toString()] ?? 'غير معروف';
void _toast(BuildContext context, Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));

import 'package:flutter/material.dart';
import 'package:loqma/features/services/data/repositories/service_providers_repository.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/presentation/pages/service_provider_details_page.dart';

class SharedServiceProviderPage extends StatefulWidget {
  final String providerId;

  const SharedServiceProviderPage({
    super.key,
    required this.providerId,
  });

  @override
  State<SharedServiceProviderPage> createState() =>
      _SharedServiceProviderPageState();
}

class _SharedServiceProviderPageState extends State<SharedServiceProviderPage> {
  final _repository = ServiceProvidersRepository();
  bool _loading = true;
  String? _error;
  ServiceProvider? _provider;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = await _repository.getById(widget.providerId);
      if (!mounted) return;
      setState(() {
        _provider = provider;
        _loading = false;
        if (provider == null) _error = 'مقدم الخدمة غير موجود أو لم يعد متاحًا';
      });
    } catch (error) {
      debugPrint('❌ [SharedProvider] load error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بروفايل مقدم الخدمة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_provider != null) {
      return ServiceProviderDetailsPage(provider: _provider!);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('بروفايل مقدم الخدمة')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'تعذر فتح الرابط'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadProvider,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
      ),
    );
  }
}

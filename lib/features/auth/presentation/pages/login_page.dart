import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/features/home/presentation/bloc/home_bloc.dart';
import 'package:loqma/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:loqma/features/map/presentation/bloc/map_bloc.dart';
import 'package:loqma/features/volunteer/presentation/bloc/volunteer_bloc.dart';
import 'package:loqma/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_workspace_page.dart';
import 'package:loqma/features/institutions/presentation/pages/institutions_home_page.dart';

import 'package:loqma/features/home/presentation/pages/home_page.dart';
import 'package:loqma/core/services/firebase_messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

const Set<String> _businessUserTypes = {
  'restaurant',
  'business',
  'hotel',
  'supermarket',
  'bakery',
  'cafe',
};

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository(SupabaseService());

  final FirebaseMessagingService _fcmService =
      FirebaseMessagingService.instance;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _isCheckingAutoLogin = true;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) return _buildCheckingScreen();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F6),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 28),
                        _buildBrand(),
                        const SizedBox(height: 26),
                        _buildLoginCard(),
                        const SizedBox(height: 20),
                        _buildRegisterLink(),
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

  Widget _buildCheckingScreen() {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color(0xFFF4F8F6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LoginLogo(size: 86),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFF0B7650)),
              SizedBox(height: 16),
              Text('جاري التحقق من الجلسة...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _glowCircle(220, const Color(0xFF8DD6B4)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _glowCircle(250, const Color(0xFFC9EBDD)),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(75),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(55),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Loqma',
          style: TextStyle(
            color: Color(0xFF0B7650),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildBrand() {
    return const Column(
      children: [
        _LoginLogo(size: 82),
        SizedBox(height: 16),
        Text(
          'مرحبًا بعودتك',
          style: TextStyle(
            color: Color(0xFF123F31),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'سجّل دخولك واستكمل رحلتك مع لقمة',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 21, 19, 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE1ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(11),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تسجيل الدخول',
            style: TextStyle(
              color: Color(0xFF153F31),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'أدخل بياناتك للوصول إلى حسابك',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'example@domain.com',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            hint: 'أدخل كلمة المرور',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFF159666),
                    onChanged: (value) => setState(
                      () => _rememberMe = value ?? false,
                    ),
                  ),
                  const Text(
                    'تذكرني',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResetPasswordPage(),
                          ),
                        ),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AuthButton(
            text: 'تسجيل الدخول',
            isLoading: _isLoading,
            onPressed: _handleLogin,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ليس لديك حساب؟',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  ),
          child: const Text(
            'إنشاء حساب جديد',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAutoLogin() async {
    try {
      final result = await _authRepo.getSessionWithUserType();
      result.fold(
        (error) {
          debugPrint('ℹ️ No auto-login: $error');
          if (mounted) setState(() => _isCheckingAutoLogin = false);
        },
        (data) async {
          final user = data['user'] as UserModel;
          if (!mounted) return;
          setState(() => _isCheckingAutoLogin = false);
          await _navigateToHome(user);
        },
      );
    } catch (e) {
      debugPrint('❌ Auto-login error: $e');
      if (mounted) setState(() => _isCheckingAutoLogin = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    if (password.isEmpty) {
      _showError('يرجى إدخال كلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authRepo.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      result.fold(
        (error) => _showError(error),
        (user) async {
          try {
            await _fcmService.initialize();
          } catch (e) {
            debugPrint('⚠️ FCM initialization failed: ${e.runtimeType}');
          }

          // ✅ تسجيل الجهاز بعد نجاح تسجيل الدخول
          await _registerDevice();

          if (mounted) await _navigateToHome(user);
        },
      );
    } catch (e) {
      if (mounted) _showError('تعذر تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ دالة تسجيل الجهاز
  Future<void> _registerDevice() async {
    try {
      final supabase = SupabaseService();
      await supabase.registerCurrentDevice();
      debugPrint('✅ Device registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  Future<void> _navigateToHome(UserModel user) async {
    if (!mounted) return;

    // AuthRepository already loaded and validated users.user_type.
    // Reuse that exact role instead of running a second query that can fail
    // because of RLS and incorrectly reject a valid institution account.
    final type = user.type.value.trim().toLowerCase();
    if (type.isEmpty) {
      _showError('نوع الحساب غير معروف. تواصل مع الإدارة للتحقق من الحساب.');
      return;
    }

    // المستخدم العادي فقط يدخل Home. أي مؤسسة لا تمر من هذا الفرع.
    if (type == 'user') {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
              BlocProvider<ProfileBloc>(create: (_) => ProfileBloc()),
              BlocProvider<MapBloc>(create: (_) => MapBloc(SupabaseService())),
              BlocProvider<VolunteerBloc>(
                create: (_) => VolunteerBloc(SupabaseService()),
              ),
              BlocProvider<NotificationBloc>(
                  create: (_) => sl<NotificationBloc>()),
              BlocProvider<BookingBloc>(
                create: (_) =>
                    BookingBloc(BookingRepository(SupabaseService())),
              ),
            ],
            child: const HomePage(),
          ),
        ),
        (route) => false,
      );
      return;
    }

    // Charity routing is allowed only when users.user_type is charity.
    if (type == 'charity') {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CharityWorkspacePage()),
        (route) => false,
      );
      return;
    }

    // Isolated institution accounts use only the new institutions module.
    if (type == 'institution') {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InstitutionsHomePage()),
        (route) => false,
      );
      return;
    }

    // Commercial institutions route only when users.user_type is a business type.
    if (_businessUserTypes.contains(type)) {
      final businessId = await _authoritativeBusinessId();
      if (!mounted) return;
      if (businessId == null || businessId.isEmpty) {
        _showError('حساب المؤسسة غير مرتبط بنشاط تجاري فعال');
        return;
      }

      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => BusinessRestaurantPage(businessId: businessId)),
        (route) => false,
      );
      return;
    }

    // لا يوجد fallback إلى Home للأنواع غير المعروفة.
    _showError('نوع الحساب غير معروف. تواصل مع الإدارة للتحقق من الحساب.');
  }

  Future<String> _authoritativeIdentityType() async {
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authUserId == null || authUserId.trim().isEmpty) return 'unknown';

    final row = await Supabase.instance.client
        .from('users')
        .select('user_type')
        .eq('id', authUserId)
        .maybeSingle();

    final userType = (row?['user_type']?.toString() ?? '').trim().toLowerCase();

    if (userType == 'user') return 'user';
    if (userType == 'charity') return 'charity';
    if (userType == 'institution') return 'institution';
    if (_businessUserTypes.contains(userType)) return 'restaurant';

    // Never infer a role from businesses, restaurants, charities,
    // organizations, cached values, names, or linked IDs.
    return 'unknown';
  }

  Future<String?> _authoritativeInstitutionId() async {
    try {
      final authUserId = Supabase.instance.client.auth.currentUser?.id;
      if (authUserId == null || authUserId.trim().isEmpty) return null;

      final row = await Supabase.instance.client
          .from('institutions')
          .select('id')
          .eq('user_id', authUserId)
          .eq('status', 'active')
          .maybeSingle();
      return row?['id']?.toString().trim();
    } catch (error) {
      debugPrint('Institution profile lookup failed: $error');
      return null;
    }
  }

  Future<String?> _authoritativeBusinessId() async {
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authUserId == null || authUserId.trim().isEmpty) return null;

    final row = await Supabase.instance.client
        .from('users')
        .select('user_type')
        .eq('id', authUserId)
        .maybeSingle();
    final role = (row?['user_type']?.toString() ?? '').trim().toLowerCase();
    if (!_businessUserTypes.contains(role)) return null;

    final business = await Supabase.instance.client
        .from('businesses')
        .select('id')
        .eq('user_id', authUserId)
        .maybeSingle();
    final businessId = business?['id']?.toString().trim();
    if (businessId != null && businessId.isNotEmpty) return businessId;

    final restaurant = await Supabase.instance.client
        .from('restaurants')
        .select('id')
        .eq('user_id', authUserId)
        .maybeSingle();
    final restaurantId = restaurant?['id']?.toString().trim();
    return restaurantId == null || restaurantId.isEmpty ? null : restaurantId;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _LoginLogo extends StatelessWidget {
  final double size;

  const _LoginLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF25B77C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B7650).withAlpha(55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.volunteer_activism_rounded,
        size: size * .48,
        color: Colors.white,
      ),
    );
  }
}

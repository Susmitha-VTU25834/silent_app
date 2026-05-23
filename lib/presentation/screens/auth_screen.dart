import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/auth_provider.dart';
import '../theme/design_system.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isVerifyingOtp = false;
  String? _serverOtp;
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || (!_isLogin && _nameController.text.isEmpty)) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (_isLogin) {
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);
      if (!success) {
        _showErrorSnackBar('Login Failed. Check your credentials and connection.');
      }
    } else {
      final otpResult = await authProvider.sendOtp(_emailController.text.trim());
      setState(() => _isLoading = false);
      
      if (otpResult['success']) {
        setState(() {
          _isVerifyingOtp = true;
          _serverOtp = otpResult['otp'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        _showErrorSnackBar(otpResult['message'] ?? 'Failed to send verification code.');
      }
    }
  }

  Future<void> _verifyOtpAndRegister() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      _showErrorSnackBar('Please enter the 4-digit verification code.');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await authProvider.signup(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      otp,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created and logged in!'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _showErrorSnackBar(result['message'] ?? 'Registration failed.');
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final otpResult = await authProvider.sendOtp(_emailController.text.trim());
    setState(() => _isLoading = false);

    if (otpResult['success']) {
      setState(() {
        _serverOtp = otpResult['otp'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A new verification code was sent!'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _showErrorSnackBar(otpResult['message'] ?? 'Failed to resend code.');
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _isVerifyingOtp = false;
      _serverOtp = null;
    });
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle();
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Successfully authenticated with Google!'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _showErrorSnackBar('Google Sign-In Failed. Check your connection.');
    }
  }

  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.7),
          width: 1.5,
        ),
        color: AppColors.surface.withOpacity(0.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleLogoWidget(size: 22),
              const SizedBox(width: 12),
              Text(
                "Continue with Google",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 55,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: AppColors.surface.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 3) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              _otpFocusNodes[index].unfocus();
            }
          } else {
            if (index > 0) {
              _otpFocusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  Widget _buildOtpVerificationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.accent, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verify Your Email',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 4-digit code to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        if (_serverOtp != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: Text(
              'Verification Code: $_serverOtp',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        
        // 4-Digit Inputs
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) => _buildOtpField(index)),
        ),
        const SizedBox(height: 32),
        
        // Verify Button
        _isLoading
            ? CircularProgressIndicator(color: AppColors.accent)
            : Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _verifyOtpAndRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'VERIFY & REGISTER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 24),
        
        // Resend Code
        TextButton(
          onPressed: _isLoading ? null : _resendOtp,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: Text(
            "Didn't receive the code? Resend Code",
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        
        // Back link
        TextButton(
          onPressed: () {
            setState(() {
              _isVerifyingOtp = false;
              for (var c in _otpControllers) {
                c.clear();
              }
            });
          },
          child: Text(
            "Change Email / Go Back",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMainAuthView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.map_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        
        // Title
        Text(
          _isLogin ? 'Welcome Back' : 'Join Smart Silent',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          _isLogin ? 'Sign in to sync your zones' : 'Create an account to backup data',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 40),
        
        // Form Fields
        if (!_isLogin)
          _buildTextField(
            controller: _nameController,
            hint: 'Full Name',
            icon: Icons.person_outline_rounded,
          ),
        _buildTextField(
          controller: _emailController,
          hint: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 32),
        
        // Submit Button
        _isLoading
            ? CircularProgressIndicator(color: AppColors.primary)
            : Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isLogin ? 'LOG IN' : 'SIGN UP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 24),
        
        // Toggle Mode
        TextButton(
          onPressed: _toggleAuthMode,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: RichText(
            text: TextSpan(
              text: _isLogin ? "Don't have an account? " : "Already have an account? ",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              children: [
                TextSpan(
                  text: _isLogin ? "Sign Up" : "Log In",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border.withOpacity(0.5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "OR",
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border.withOpacity(0.5))),
          ],
        ),
        const SizedBox(height: 16),
        
        // Google Sign In Button
        _buildGoogleButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.background.withOpacity(0.8),
                  AppColors.primary.withOpacity(0.15),
                  AppColors.background,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),
          
          // Decorative Blurred Shapes
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _isVerifyingOtp 
                              ? _buildOtpVerificationView()
                              : _buildMainAuthView(),
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
          filled: true,
          fillColor: AppColors.surface.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({Key? key, this.size = 24}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final length = size.width;
    final arcThickness = length / 4.5;
    final double padding = arcThickness / 2;
    
    // Bounds rect inset by half stroke width to avoid clipping at outer boundaries
    final bounds = Rect.fromLTWH(padding, padding, length - arcThickness, length - arcThickness);
    final center = bounds.center;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcThickness
      ..strokeCap = StrokeCap.butt;

    // Red arc: top-left area
    canvas.drawArc(bounds, 3.5, 1.85, false, paint..color = const Color(0xFFEA4335));
    
    // Yellow arc: left-bottom area
    canvas.drawArc(bounds, 2.45, 1.05, false, paint..color = const Color(0xFFFBBC05));
    
    // Green arc: bottom-right area
    canvas.drawArc(bounds, 0.9, 1.55, false, paint..color = const Color(0xFF34A853));
    
    // Blue arc: right-top area
    canvas.drawArc(bounds, -0.93, 1.83, false, paint..color = const Color(0xFF4285F4));

    // Draw the horizontal bar to complete the "G" shape
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - (arcThickness / 2),
        bounds.right + (arcThickness / 2),
        center.dy + (arcThickness / 2),
      ),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
  }
}

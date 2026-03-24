import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/locale_provider.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool isFromSettings;

  const LanguageSelectionScreen({super.key, this.isFromSettings = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLangCode = 'en';

  final List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ'},
    {'code': 'te', 'name': 'తెలుగు'},
    {'code': 'ta', 'name': 'தமிழ்'},
    {'code': 'ml', 'name': 'മലയാളം'},
    {'code': 'mr', 'name': 'मराठी'},
    {'code': 'bn', 'name': 'বাংলা'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      setState(() {
        _selectedLangCode = localeProvider.locale.languageCode;
      });
    });
  }

  Future<void> _saveLanguageAndContinue() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    await localeProvider.setLocale(Locale(_selectedLangCode));
    
    if (!mounted) return;

    if (widget.isFromSettings) {
      Navigator.pop(context);
    } else {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => session != null ? const DashboardScreen() : const AuthScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: widget.isFromSettings 
          ? AppBar(
              title: const Text('Change Language'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isFromSettings) ...[
                FadeInDown(
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryStatusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language, size: 60, color: AppTheme.primaryStatusColor),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'FarmGuard AI',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppTheme.primaryStatusColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select Your Language',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
              Expanded(
                child: FadeInUp(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final lang = languages[index];
                      final isSelected = _selectedLangCode == lang['code'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLangCode = lang['code']!;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryStatusColor : AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryStatusColor : AppTheme.surfaceVariantColor,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryStatusColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            lang['name']!,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    onPressed: _saveLanguageAndContinue,
                    child: Text(widget.isFromSettings ? 'Save' : 'Continue / आगे बढ़ें'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

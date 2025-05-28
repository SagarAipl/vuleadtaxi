import 'package:flutter/material.dart';
import 'package:vuleadtaxi/LoginScreen.dart';

// Constants for reusability
class AppConstants {
  static const Color backgroundColor = Color(0xFF333333);
  static const Color accentColor = Color(0xFFF5A623);
  static const Color skipButtonColor = Color(0xFF8EACC1);
  static const Color textColor = Colors.white;
  static const Color subtitleColor = Colors.white70;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'asstes/images/G.png',
      'title': 'Locate the Destination',
      'subtitle': 'Your destination is at your fingertips. Open the app & enter where you want to go.',
      'buttonText': 'Next',
      'dotPosition': '0',
    },
    {
      'image': 'asstes/images/pngwing (1).png',
      'title': 'Choose Your Ride',
      'subtitle': 'Select from a variety of vehicles that suit your needs and budget.',
      'buttonText': 'Next',
      'dotPosition': '1',
    },
    {
      'image': 'asstes/images/pngwing.png',
      'title': 'Ride with Ease',
      'subtitle': 'Enjoy a seamless and comfortable ride with our trusted drivers.',
      'buttonText': 'Get Started',
      'dotPosition': '2',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppConstants.skipButtonColor,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),

            // Page view for onboarding slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(
                    image: _onboardingData[index]['image']!,
                    title: _onboardingData[index]['title']!,
                    subtitle: _onboardingData[index]['subtitle']!,
                  );
                },
              ),
            ),

            // Bottom content (title, subtitle, dots, button)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Title with underline
                  Column(
                    children: [
                      Text(
                        _onboardingData[_currentPage]['title']!,
                        style: const TextStyle(
                          color: AppConstants.textColor,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 120,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppConstants.accentColor,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    _onboardingData[_currentPage]['subtitle']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppConstants.subtitleColor,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Pagination dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                          (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppConstants.accentColor
                              : AppConstants.textColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _navigateToLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _onboardingData[_currentPage]['buttonText']!,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;

  const OnboardingPage({
    Key? key,
    required this.image,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding page with $title',
      child: Center(
        child: Image.asset(
          image,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error,
              color: AppConstants.textColor,
              size: 50,
            );
          },
        ),
      ),
    );
  }
}
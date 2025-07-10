import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'Screens/splash_screen.dart';
import 'Screens/login_page.dart';
import 'package:reading_comprehension/about_page.dart';

// Global notifier for theme mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.transparent,
            textTheme: GoogleFonts.lexendDecaTextTheme(),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: GoogleFonts.lexendDecaTextTheme(),
          ),
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}


class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
        
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/images/logo.png",
                    height: 300,
                    width: 400,
                    fit: BoxFit.fill,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome to CISC KIDS APP!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexendDeca(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Mobile Reading Comprehension",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexendDeca(
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "We believe in the power of education to transform lives. Our mission is to empower learners and educators through innovative assessments that foster meaningful learning. Assessment is not just about testing it's about understanding, growth, and continuous improvement.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.w300,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // GET STARTED Button
                  Container(
                    height: 50,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: const Color(0xFF15A323),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignIn()),
                        );
                      },
                      child: const Text(
                        "GET STARTED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // ABOUT US Button
                Container(
                  height: 50,
                  width: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.transparent,
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AboutPage()),
                      );
                    },
                    child: const Text(
                      "ABOUT US",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 50,
                  width: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.transparent,
                  ),
                 
                    
                ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
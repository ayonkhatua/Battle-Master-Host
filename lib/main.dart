import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🌟 APNA SUPABASE URL AUR KEY YAHAN DAALNA
  await Supabase.initialize(
    url: 'https://nkzbwljelpcceeqepaha.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5remJ3bGplbHBjY2VlcWVwYWhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwOTMzNzcsImV4cCI6MjA4OTY2OTM3N30.icbVxfAsB55NavjS45ANWL3nKeMGYn4oBnhblRM-TkY',
  );

  runApp(const HostPanelApp());
}

final supabase = Supabase.instance.client;

class HostPanelApp extends StatelessWidget {
  const HostPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BM Host Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617), // Deep Dark Blue
        primaryColor: Colors.indigoAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      // App start hote hi Login par jayegi
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/waiting_screen': (context) => const WaitingScreen(),
        '/host_dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
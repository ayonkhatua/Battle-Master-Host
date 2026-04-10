import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🌟 ENV IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🌟 ENV file load karna
  await dotenv.load(fileName: ".env");

  // 🌟 ENV se keys fetch karna (Hardcode URL aur Key hata di)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
      // 🌟 initialRoute HATA KAR SEEDHA AuthGate LAGAYA 🌟
      home: const AuthGate(),
      routes: {
        // '/' hata diya kyunki AuthGate automatically handle karega
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/waiting_screen': (context) => const WaitingScreen(),
        '/host_dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

// 🛡️ SECURITY GATE (Host Panel Ke Liye Smart Login)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // ❌ Agar login nahi hai toh seedha Login Screen dikhao
      return const LoginScreen();
    }

    // ✅ Agar login hai, toh database se check karo Admin ne approve kiya ya nahi
    return FutureBuilder(
      future: Supabase.instance.client
          .from('host_profiles')
          .select('status')
          .eq('id', session.user.id)
          .single(),
      builder: (context, snapshot) {
        // Jab tak status load ho raha hai, loading animation dikhao
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF020617),
            body: Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
          );
        }

        // Agar error aaye (Profile delete ho gayi ho, etc.)
        if (snapshot.hasError || !snapshot.hasData) {
          return const LoginScreen();
        }

        final status = snapshot.data!['status'];

        // 🌟 DECISION MAKER 🌟
        if (status == 'approved') {
          return const DashboardScreen(); // Admin ne approve kar diya!
        } else {
          return const WaitingScreen(); // Abhi waiting ya rejected hai
        }
      },
    );
  }
}
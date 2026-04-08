import 'package:flutter/material.dart';
import '../main.dart'; // Ensure supabase client is accessible here

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  bool _isRefreshing = false;

  // 🌟 NAYA LOGIC: Bina logout kiye status check karna
  Future<void> _checkStatus() async {
    setState(() => _isRefreshing = true);
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _logout();
        return;
      }

      final data = await supabase
          .from('host_profiles')
          .select('status')
          .eq('id', user.id)
          .single();

      final String status = data['status'];

      if (!mounted) return;

      if (status == 'approved') {
        // Approve ho gaya! Seedha Dashboard bhejo
        Navigator.pushReplacementNamed(context, '/host_dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Granted! Welcome to Host Panel.'), backgroundColor: Colors.green),
        );
      } else if (status == 'rejected') {
        // Block ho gaya
        await supabase.auth.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been rejected by the Admin.'), backgroundColor: Colors.red),
        );
      } else {
        // Abhi bhi waiting mein hai
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account is still under review...'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep Esports Dark
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: _logout,
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 Premium Glowing Icon Design
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orangeAccent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded, 
                  size: 80, 
                  color: Colors.orangeAccent
                ),
              ),
              const SizedBox(height: 40),
              
              // 🌟 Typography
              const Text(
                'APPROVAL PENDING',
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your host application is currently under review by the Super Admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 40),

              // 🌟 Refresh Status Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A), // Dark surface color
                    side: const BorderSide(color: Colors.indigoAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isRefreshing ? null : _checkStatus,
                  icon: _isRefreshing 
                      ? const SizedBox(
                          width: 20, height: 20, 
                          child: CircularProgressIndicator(color: Colors.indigoAccent, strokeWidth: 2)
                        )
                      : const Icon(Icons.refresh, color: Colors.indigoAccent),
                  label: Text(
                    _isRefreshing ? 'CHECKING...' : 'REFRESH STATUS',
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.indigoAccent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🌟 Subtle Cancel Note
              TextButton(
                onPressed: _logout,
                child: const Text(
                  'Cancel & Logout',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
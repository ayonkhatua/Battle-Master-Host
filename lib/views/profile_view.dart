import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'transaction_history_view.dart';
import 'manage_upi_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _isLoading = true;
  String _userEmail = 'Loading...';
  String _hostStatus = 'waiting';
  
  // 🌟 Real Backend Variables 🌟
  double _availableBalance = 0.0;
  double _pendingBalance = 0.0; 

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _userEmail = user.email ?? 'Unknown Host';
      _isLoading = true;
    });

    try {
      // 🌟 Supabase se live data fetch karna 🌟
      final data = await Supabase.instance.client
          .from('host_profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _availableBalance = (data['available_balance'] ?? 0).toDouble();
        _pendingBalance = (data['pending_balance'] ?? 0).toDouble();
        _hostStatus = data['status'] ?? 'waiting';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile update pending/Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("HOST PROFILE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
            onPressed: _loadUserProfile, // Refresh button added
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 🌟 1. PROFILE HEADER 🌟
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.indigoAccent, Colors.deepPurpleAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(_userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'H', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Battle Host', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            if (_hostStatus == 'approved')
                              const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_userEmail, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _hostStatus == 'approved' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _hostStatus == 'approved' ? Colors.green : Colors.orange),
                          ),
                          child: Text('Status: ${_hostStatus.toUpperCase()}', style: TextStyle(color: _hostStatus == 'approved' ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🌟 2. WALLET & EARNINGS CARD 🌟
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      Icon(Icons.account_balance_wallet, color: Colors.white54),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🪙 $_availableBalance', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pending_actions, color: Colors.orangeAccent, size: 18),
                            SizedBox(width: 8),
                            Text('Pending Verification:', style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                          ],
                        ),
                        Text('🪙 $_pendingBalance', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_availableBalance <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance for payout!')));
                          return;
                        }
                        // Payout Request Logic yahan aayega
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested! It will be processed by Sunday.')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('REQUEST PAYOUT (SUNDAY)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 🌟 3. MENU OPTIONS 🌟
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("ACCOUNT SETTINGS", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildMenuTile(Icons.history, 'Transaction History', 'View past match earnings', () {
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryView()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming Soon!')));
                  }),
                  _buildDivider(),
                  _buildMenuTile(Icons.qr_code_scanner, 'Manage UPI Details', 'For receiving payouts', () {
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUpiView()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming Soon!')));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("SUPPORT & ABOUT", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildMenuTile(Icons.help_outline, 'Battle Master Support', 'Contact Super Admin', () {}),
                  _buildDivider(),
                  _buildMenuTile(Icons.policy_outlined, 'Hosting Guidelines', 'Rules & Regulations', () {}),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 🌟 4. LOGOUT BUTTON 🌟
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('SIGN OUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.indigoAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.indigoAccent),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 60, endIndent: 20);
  }
}
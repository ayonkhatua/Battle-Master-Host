import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUpiView extends StatefulWidget {
  const ManageUpiView({super.key});

  @override
  State<ManageUpiView> createState() => _ManageUpiViewState();
}

class _ManageUpiViewState extends State<ManageUpiView> {
  final _upiController = TextEditingController();
  bool _isLoading = true;
  String? _currentUpi;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _fetchUpiDetails();
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  // 🌟 Backend se current UPI ID lao 🌟
  Future<void> _fetchUpiDetails() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('host_profiles')
          .select('upi_id')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _currentUpi = data['upi_id'];
          if (_currentUpi != null) {
            _upiController.text = _currentUpi!;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = "❌ Error loading UPI details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 Naya UPI ID Database me Save karo 🌟
  Future<void> _saveUpiDetails() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final newUpi = _upiController.text.trim();

    if (userId == null) return;

    // Basic Validation: UPI id mein '@' hona zaroori hai
    if (newUpi.isEmpty || !newUpi.contains('@')) {
      setState(() => _message = "⚠️ Please enter a valid UPI ID (e.g., 9876543210@ybl)");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "🔄 Saving UPI Details...";
    });

    try {
      await Supabase.instance.client
          .from('host_profiles')
          .update({'upi_id': newUpi})
          .eq('id', userId);

      setState(() {
        _currentUpi = newUpi;
        _message = "✅ UPI Details Saved Successfully! Payouts will be sent here.";
      });
    } catch (e) {
      setState(() => _message = "❌ Error saving details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Tap to dismiss keyboard
      child: Scaffold(
        backgroundColor: const Color(0xFF020617), // Deep Esports Dark
        appBar: AppBar(
          title: const Text("MANAGE PAYOUT METHOD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading && _currentUpi == null
            ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Message Alert ---
                    if (_message.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: _message.startsWith('❌') || _message.startsWith('⚠️') ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _message.startsWith('❌') || _message.startsWith('⚠️') ? Colors.redAccent : Colors.greenAccent),
                        ),
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _message.startsWith('❌') || _message.startsWith('⚠️') ? Colors.redAccent : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // --- Info Card ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.indigoAccent, size: 28),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Sunday Payouts will be directly transferred to the UPI ID provided below. Make sure it is active and correct.",
                              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- UPI Input Field ---
                    const Text("YOUR UPI ID", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _upiController,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "e.g., yournumber@paytm",
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentUpi != null)
                      Text("Currently Active: $_currentUpi", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 40),

                    // --- Save Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveUpiDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: Colors.indigoAccent.withOpacity(0.5),
                        ),
                        icon: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.verified_user, color: Colors.white),
                        label: Text(
                          _currentUpi == null ? 'LINK UPI ACCOUNT' : 'UPDATE UPI ACCOUNT',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
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
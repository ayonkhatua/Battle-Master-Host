import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TransactionHistoryView extends StatefulWidget {
  const TransactionHistoryView({super.key});

  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  // 🌟 Backend se Transactions Fetch Karna 🌟
  Future<void> _fetchTransactions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('host_transactions')
          .select()
          .eq('host_id', userId)
          .order('created_at', ascending: false); // Sabse naya upar dikhega

      if (mounted) {
        setState(() {
          _transactions = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep Esports Dark
      appBar: AppBar(
        title: const Text("TRANSACTION HISTORY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
            onPressed: _fetchTransactions,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : _transactions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
    );
  }

  // Khali hone par UI
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "No Transactions Yet",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Complete matches to earn rewards!",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Har ek Transaction ka Card
  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final bool isReward = transaction['transaction_type'] == 'reward';
    final DateTime date = DateTime.parse(transaction['created_at']).toLocal();
    final String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    
    // Status colors
    Color statusColor;
    String statusText = transaction['status'].toString().toUpperCase();
    if (statusText == 'COMPLETED' || statusText == 'AVAILABLE') {
      statusColor = Colors.green;
    } else if (statusText == 'FAILED') {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Colors.orangeAccent; // Pending
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isReward ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReward ? Icons.sports_esports : Icons.account_balance,
              color: isReward ? Colors.greenAccent : Colors.orangeAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReward 
                      ? 'Match Reward (#${transaction['match_id'] ?? 'N/A'})' 
                      : 'Payout Withdrawal',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Text(
            isReward ? '+ 🪙${transaction['amount']}' : '- 🪙${transaction['amount']}',
            style: TextStyle(
              color: isReward ? Colors.greenAccent : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
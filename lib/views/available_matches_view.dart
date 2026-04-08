import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AvailableMatchesView extends StatefulWidget {
  const AvailableMatchesView({super.key});

  @override
  State<AvailableMatchesView> createState() => _AvailableMatchesViewState();
}

class _AvailableMatchesViewState extends State<AvailableMatchesView> {
  bool _isLoading = true;
  List<dynamic> _availableMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableMatches();
  }

  // 🌟 1. FETCH OPEN MATCHES (Jinka host_id NULL hai) 🌟
  Future<void> _fetchAvailableMatches() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('tournaments')
          .select()
          .isFilter('host_id', null) // Sirf "Open" matches lao
          .order('time', ascending: true);

      setState(() {
        _availableMatches = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matches: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 2. CLAIM / BOOK MATCH LOGIC 🌟
  Future<void> _claimMatch(int matchId, String title) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in!')),
      );
      return;
    }

    // Confirmation Dialog (Galti se click hone par bachane ke liye)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Claim Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to host "$title"? Once claimed, you must manage it.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Claim it!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Backend Update Logic
    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({'host_id': userId}) // Null hata kar is Host ki ID daal di
          .eq('id', matchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Match Claimed Successfully! Check "Manage" tab.'), backgroundColor: Colors.green),
        );
        _fetchAvailableMatches(); // List ko turant refresh karo
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim match: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Dashboard ka theme inherit karega
      appBar: AppBar(
        title: const Text("AVAILABLE MATCHES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
            tooltip: 'Refresh Board',
            onPressed: _fetchAvailableMatches,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : _availableMatches.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Colors.indigoAccent,
                  backgroundColor: const Color(0xFF0F172A),
                  onRefresh: _fetchAvailableMatches,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableMatches.length,
                    itemBuilder: (context, index) {
                      final match = _availableMatches[index];
                      return _buildMatchCard(match);
                    },
                  ),
                ),
    );
  }

  // Khali hone par UI
  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.event_busy, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            "No Matches Available",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "Check back later or wait for Admin to create more.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // Har ek match ka Card Design
  Widget _buildMatchCard(Map<String, dynamic> match) {
    final DateTime matchTime = DateTime.parse(match['time']).toLocal();
    final String formattedDate = DateFormat('dd MMM, hh:mm a').format(matchTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          if (match['image_url'] != null && match['image_url'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                match['image_url'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
              ),
            )
          else
            _buildPlaceholderImage(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        match['title'] ?? 'Unknown Tournament',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match['mode'] ?? 'N/A',
                        style: const TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Match Details (Time, Slots, Entry Fee)
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.grey, size: 16),
                    const SizedBox(width: 6),
                    Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.people_alt_outlined, color: Colors.grey, size: 16),
                    const SizedBox(width: 6),
                    Text('${match['slots']} Slots', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('Entry: 🪙${match['entry_fee']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Icon(Icons.emoji_events, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('Prize: 🪙${match['prize_pool']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),

                // Claim Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _claimMatch(match['id'], match['title']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.front_hand, color: Colors.white, size: 20),
                    label: const Text('CLAIM THIS MATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Center(
        child: Icon(Icons.sports_esports, color: Colors.white24, size: 50),
      ),
    );
  }
}
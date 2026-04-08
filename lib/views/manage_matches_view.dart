import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantState {
  final Map<String, dynamic> participantData;
  final TextEditingController killsController;
  final TextEditingController coinsController;
  bool isWinner;

  ParticipantState(this.participantData)
    : killsController = TextEditingController(text: '0'),
      coinsController = TextEditingController(text: '0'),
      isWinner = false;

  String get ign =>
      participantData['user_ign'] ?? participantData['users']?['ign'] ?? 'N/A';

  String get userId => participantData['user_id'].toString();
}

class ManageMatchesView extends StatefulWidget {
  const ManageMatchesView({super.key});

  @override
  State<ManageMatchesView> createState() => _ManageMatchesViewState();
}

class _ManageMatchesViewState extends State<ManageMatchesView> {
  final _searchController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _roomPassController = TextEditingController();
  
  // 🌟 NAYE CONTROLLERS ECONOMY EDIT KARNE KE LIYE 🌟
  final _editPrizePoolController = TextEditingController();
  final _editPerKillController = TextEditingController();

  Map<String, dynamic>? _tournament;
  List<ParticipantState> _participants = [];
  bool _isLoading = false;
  String _message = "";

  @override
  void dispose() {
    _searchController.dispose();
    _roomIdController.dispose();
    _roomPassController.dispose();
    _editPrizePoolController.dispose();
    _editPerKillController.dispose();
    super.dispose();
  }

  Future<void> _loadTournament() async {
    final tid = int.tryParse(_searchController.text);
    if (tid == null) {
      setState(() => _message = "⚠️ Please enter a valid Tournament ID");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
      _tournament = null;
      _participants = [];
    });

    try {
      final tResponse = await Supabase.instance.client
          .from('tournaments')
          .select()
          .eq('id', tid)
          .single();

      final pResponse = await Supabase.instance.client
          .from('user_tournaments')
          .select('*, users(ign)')
          .eq('tournament_id', tid);

      setState(() {
        _tournament = tResponse;
        _participants = (pResponse as List)
            .map((p) => ParticipantState(p))
            .toList();
            
        // Load Room Details
        _roomIdController.text = _tournament!['room_id'] ?? '';
        _roomPassController.text = _tournament!['room_password'] ?? '';
        
        // 🌟 LOAD ECONOMY DETAILS 🌟
        _editPrizePoolController.text = _tournament!['prize_pool']?.toString() ?? '';
        _editPerKillController.text = _tournament!['per_kill']?.toString() ?? '';
      });
    } catch (e) {
      setState(() => _message = "❌ Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 NAYA FUNCTION: TOURNAMENT ECONOMY UPDATE KARNE KE LIYE 🌟
  Future<void> _updateTournamentEconomy() async {
    if (_tournament == null) return;
    setState(() {
      _isLoading = true;
      _message = "🔄 Updating Prize Pool...";
    });

    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'prize_pool': _editPrizePoolController.text.trim(),
            'per_kill': _editPerKillController.text.trim(),
          })
          .eq('id', _tournament!['id']);

      setState(() {
        _message = "✅ Economy updated successfully! No losses today.";
        // Local state update so UI reflects the new numbers
        _tournament!['prize_pool'] = _editPrizePoolController.text.trim();
        _tournament!['per_kill'] = _editPerKillController.text.trim();
      });
    } catch (e) {
      setState(() => _message = "❌ Error updating economy: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setRoomDetails() async {
    if (_tournament == null) return;
    setState(() {
      _isLoading = true;
      _message = "🔄 Updating room details...";
    });

    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'room_id': _roomIdController.text.trim(),
            'room_password': _roomPassController.text.trim(),
          })
          .eq('id', _tournament!['id']);

      setState(() => _message = "✅ Room details updated successfully!");
    } catch (e) {
      setState(() => _message = "❌ Error updating room: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveResults() async {
    if (_tournament == null) return;
    final tid = _tournament!['id'];
    setState(() {
      _isLoading = true;
      _message = "🔄 Saving results & calculating coins...";
    });

    try {
      Map<String, Map<String, dynamic>> consolidatedResults = {};

      for (var p in _participants) {
        String uId = p.userId;
        int currentKills = int.tryParse(p.killsController.text) ?? 0;
        int currentCoins = int.tryParse(p.coinsController.text) ?? 0;
        bool isWinner = p.isWinner;

        if (consolidatedResults.containsKey(uId)) {
          consolidatedResults[uId]!['kills'] += currentKills;
          consolidatedResults[uId]!['winnings'] += currentCoins;
          if (isWinner) consolidatedResults[uId]!['is_winner'] = true;
        } else {
          consolidatedResults[uId] = {
            'tournament_id': tid,
            'user_id': uId,
            'kills': currentKills,
            'winnings': currentCoins,
            'is_winner': isWinner,
          };
        }
      }

      final resultsToUpsert = consolidatedResults.values.toList();

      await Supabase.instance.client
          .from('game_results')
          .upsert(
            resultsToUpsert,
            onConflict: 'tournament_id, user_id',
          );

      final winners = _participants
          .where((p) => p.isWinner)
          .map((p) => p.ign)
          .toSet()
          .toList();
      final winnerNames = winners.join(", ");

      await Supabase.instance.client
          .from('tournaments')
          .update({
            'status': 'completed',
            'winner': winnerNames,
            'end_time': DateTime.now().toIso8601String(),
          })
          .eq('id', tid);

      await _updateStatistics(tid, consolidatedResults);

      setState(
        () => _message = "🏆 Results saved! Match Completed.",
      );
    } on PostgrestException catch (e) {
      setState(() => _message = "❌ Database Error: ${e.message}");
    } catch (e) {
      setState(
        () => _message = "❌ An unexpected error occurred: ${e.toString()}",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatistics(int tid, Map<String, Map<String, dynamic>> consolidatedResults) async {
    final entryFeeString = _tournament!['entry_fee']?.toString() ?? '0';
    final entryFee = double.tryParse(entryFeeString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final title = _tournament!['title'];

    final statsToUpsert = consolidatedResults.values.map((res) {
      return {
        'user_id': res['user_id'],
        'tournament_id': tid,
        'title': title,
        'paid': entryFee.toInt(),
        'won': res['winnings'],
      };
    }).toList();

    if (statsToUpsert.isNotEmpty) {
      await Supabase.instance.client
          .from('statistics')
          .upsert(statsToUpsert, onConflict: 'user_id, tournament_id');
    }
  }

  // Helper for Input Decoration
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF020617), // Darker inner fill
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigoAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("MANAGE MATCH", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Search Section ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Tournament ID', Icons.numbers),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadTournament,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.search, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Message & Loading state ---
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.indigoAccent))),
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

              // --- Tournament Content Section ---
              if (_tournament != null && !_isLoading) ...[
                Text(
                  '${_tournament!['title']} (#${_tournament!['id']})',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Players Joined: ${_tournament!['filled']} / ${_tournament!['slots']}',
                  style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // 🌟 NAYA SECTION: EDIT ECONOMY 🌟
                _buildEditEconomyBox(),
                const SizedBox(height: 20),
                
                _buildRoomBox(),
                const SizedBox(height: 20),
                
                _buildParticipantsTable(),
                const SizedBox(height: 24),
                
                // --- Save Results Button ---
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.teal],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveResults,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text(
                      'FINISH & PAYOUT COINS',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 WIDGET: ECONOMY EDIT BOX 🌟
  Widget _buildEditEconomyBox() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Adjust Economy (Prevent Loss)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editPrizePoolController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Win Prize', Icons.emoji_events),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _editPerKillController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Per Kill', Icons.my_location),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _updateTournamentEconomy,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orangeAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save_as, color: Colors.orangeAccent, size: 18),
              label: const Text('Update Payouts', style: TextStyle(color: Colors.orangeAccent)),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: ROOM DETAILS BOX
  Widget _buildRoomBox() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Room Credentials', style: TextStyle(color: Colors.indigoAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _roomIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Room ID', Icons.meeting_room),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _roomPassController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Password', Icons.lock),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _setRoomDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent.withOpacity(0.2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send, color: Colors.indigoAccent, size: 18),
              label: const Text('Send to Players', style: TextStyle(color: Colors.indigoAccent)),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: PARTICIPANTS TABLE
  Widget _buildParticipantsTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Player Results & Kills', style: TextStyle(color: Colors.indigoAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 25,
              headingTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 14),
              dataTextStyle: const TextStyle(color: Colors.white),
              columns: const [
                DataColumn(label: Text('Player IGN')),
                DataColumn(label: Text('Kills')),
                DataColumn(label: Text('Coins Won')),
                DataColumn(label: Text('Booyah?')),
              ],
              rows: _participants.map((p) {
                return DataRow(
                  cells: [
                    DataCell(Text(p.ign, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: p.killsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            filled: true,
                            fillColor: const Color(0xFF020617),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: p.coinsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            filled: true,
                            fillColor: const Color(0xFF020617),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Checkbox(
                        value: p.isWinner,
                        activeColor: Colors.green,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        onChanged: (val) {
                          setState(() {
                            p.isWinner = val ?? false;
                          });
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
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
  final _roomIdController = TextEditingController();
  final _roomPassController = TextEditingController();
  
  final _editPrizePoolController = TextEditingController();
  final _editPerKillController = TextEditingController();

  // 🌟 NAYE VARIABLES: Dropdown aur Booked Matches ke liye 🌟
  List<Map<String, dynamic>> _myClaimedMatches = [];
  int? _selectedMatchId;

  Map<String, dynamic>? _tournament;
  List<ParticipantState> _participants = [];
  bool _isLoading = false;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _fetchMyMatches(); // Screen khulte hi host ke matches load honge
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _roomPassController.dispose();
    _editPrizePoolController.dispose();
    _editPerKillController.dispose();
    super.dispose();
  }

  // 🌟 NAYA FUNCTION: Sirf wahi matches lao jo IS host ne claim kiye hain 🌟
  Future<void> _fetchMyMatches() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('tournaments')
          .select('id, title, time')
          .eq('host_id', userId)
          .neq('status', 'completed') // Jo khatam ho gaye wo mat dikhao
          .order('time', ascending: true);

      setState(() {
        _myClaimedMatches = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() => _message = "❌ Error loading your matches: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 UPDATE: Ab id direct Dropdown se aayegi 🌟
  Future<void> _loadTournament(int tid) async {
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
            
        _roomIdController.text = _tournament!['room_id'] ?? '';
        _roomPassController.text = _tournament!['room_password'] ?? '';
        
        _editPrizePoolController.text = _tournament!['prize_pool']?.toString() ?? '';
        _editPerKillController.text = _tournament!['per_kill']?.toString() ?? '';
      });
    } catch (e) {
      setState(() => _message = "❌ Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

      setState(() => _message = "✅ Room credentials sent to players!");
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

      // Match ko completed mark karna
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'status': 'completed',
            'winner': winnerNames,
            'end_time': DateTime.now().toIso8601String(),
          })
          .eq('id', tid);

      await _updateStatistics(tid, consolidatedResults);

      setState(() {
        _message = "🏆 Results saved! Match Completed & Sent for Verification.";
        _tournament = null; // Form clear kar do
        _selectedMatchId = null;
      });
      
      _fetchMyMatches(); // List refresh karo (Completed match hat jayega)
      
    } on PostgrestException catch (e) {
      setState(() => _message = "❌ Database Error: ${e.message}");
    } catch (e) {
      setState(() => _message = "❌ An unexpected error occurred: ${e.toString()}");
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF020617),
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
          title: const Text("MY BOOKED MATCHES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
              onPressed: _fetchMyMatches,
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🌟 NAYA DROPDOWN SELECTION UI 🌟
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a Match to Manage', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedMatchId,
                      hint: const Text('Tap to select your match', style: TextStyle(color: Colors.grey)),
                      decoration: _buildInputDecoration('', Icons.sports_esports).copyWith(labelText: null),
                      dropdownColor: const Color(0xFF020617),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: _myClaimedMatches.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Text('${m['title']} (#${m['id']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMatchId = val);
                          _loadTournament(val); // Select karte hi data load
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                  '${_tournament!['title']}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Players Joined: ${_tournament!['filled']} / ${_tournament!['slots']}',
                  style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
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
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text(
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
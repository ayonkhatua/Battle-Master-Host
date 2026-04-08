import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTournamentView extends StatefulWidget {
  const CreateTournamentView({super.key});

  @override
  State<CreateTournamentView> createState() => _CreateTournamentViewState();
}

class _CreateTournamentViewState extends State<CreateTournamentView> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Controllers & Variables
  final _titleController = TextEditingController();
  String? _mode;
  DateTime? _time;
  
  // 🌟 IMAGE VARIABLES 🌟
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final ImagePicker _picker = ImagePicker();

  final _prizePoolController = TextEditingController();
  final _perKillController = TextEditingController();
  final _entryFeeController = TextEditingController();
  String? _type;
  final _slotsController = TextEditingController();
  final _prizeDescriptionController = TextEditingController();

  String? _version;
  String? _map;

  final List<String> _modeOptions = [
    'Battle Royale', 'Clash Squad', 'Lone Wolf', 'BR Survival',
    'HS Clash Squad', 'HS Lone Wolf', 'Daily Special', 'Mega Special', 'Grand Special',
  ];
  final List<String> _typeOptions = ['Solo', 'Duo', 'Squad'];
  final List<String> _versionOptions = ['TPP']; 
  final List<String> _mapOptions = ['Bermuda', 'IRON CAGE'];

  @override
  void dispose() {
    _titleController.dispose();
    _prizePoolController.dispose();
    _perKillController.dispose();
    _entryFeeController.dispose();
    _slotsController.dispose();
    _prizeDescriptionController.dispose();
    super.dispose();
  }

  // 🌟 IMAGE PICKER FUNCTION 🌟
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error selecting image: $e');
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigoAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigoAccent,
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _time = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createTournament() async {
    if (_formKey.currentState!.validate()) {
      if (_time == null) {
        _showErrorSnackBar('Please select a match time.');
        return;
      }

      if (_selectedImageBytes == null) {
        _showErrorSnackBar('Please select a tournament image!');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final utcTime = _time!.toUtc().toIso8601String();
        String finalImageUrl = '';

        // 🌟 1. UPLOAD IMAGE TO SUPABASE STORAGE 🌟
        final fileExtension = (_selectedImageName != null && _selectedImageName!.contains('.'))
            ? _selectedImageName!.split('.').last
            : 'jpg';
        final fileName = 'tourney_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = 'tournaments/$fileName';

        await Supabase.instance.client.storage
            .from('Battle Master Banner')
            .uploadBinary(
              filePath,
              _selectedImageBytes!,
              fileOptions: FileOptions(contentType: 'image/$fileExtension', upsert: true),
            );

        finalImageUrl = Supabase.instance.client.storage
            .from('Battle Master Banner')
            .getPublicUrl(filePath);

        // 🌟 2. INSERT DATA INTO TOURNAMENTS TABLE 🌟
        await Supabase.instance.client.from('tournaments').insert({
          'title': _titleController.text.trim(),
          'mode': _mode,
          'time': utcTime,
          'image_url': finalImageUrl,
          'prize_pool': _prizePoolController.text.trim(),
          'per_kill': _perKillController.text.trim(),
          'entry_fee': _entryFeeController.text.trim(),
          'type': _type,
          'version': _version, 
          'map': _map,         
          'slots': int.parse(_slotsController.text.trim()),
          'filled': 0, 
          'prize_description': _prizeDescriptionController.text.trim().isNotEmpty 
                               ? _prizeDescriptionController.text.trim() 
                               : null,
          // NAYA LOGIC: Yahan hum match ko 'Open' status de sakte hain agar tumne DB me status column banaya hai.
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Tournament created successfully in $_mode!'), 
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Form Clear Logic
        _formKey.currentState!.reset();
        _titleController.clear();
        _prizePoolController.clear();
        _perKillController.clear();
        _entryFeeController.clear();
        _slotsController.clear();
        _prizeDescriptionController.clear(); 
        
        setState(() {
          _time = null;
          _mode = null;
          _type = null;
          _version = null;
          _map = null;
          _selectedImageBytes = null; 
          _selectedImageName = null;
        });
      } on PostgrestException catch (e) {
        if (mounted) _showErrorSnackBar('Database Error: ${e.message}');
      } catch (e) {
        if (mounted) _showErrorSnackBar('An unexpected error occurred: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Helper for Input Decoration to keep code clean
  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigoAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Tap anywhere to hide keyboard
      child: Scaffold(
        backgroundColor: Colors.transparent, // Inherits from Dashboard
        appBar: AppBar(
          title: const Text("CREATE TOURNAMENT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 IMAGE UPLOAD SECTION 🌟
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _selectedImageBytes == null ? Colors.grey.shade800 : Colors.indigoAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      if (_selectedImageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_selectedImageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617), 
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade800, style: BorderStyle.solid)
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("No Banner Selected", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.indigoAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _pickImage,
                          icon: const Icon(Icons.cloud_upload_outlined, color: Colors.indigoAccent),
                          label: const Text("Upload Banner Image", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 🌟 BASIC DETAILS 🌟
                const Text("MATCH DETAILS", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Match Title', hint: 'E.g. Sunday Grand Battle'),
                  validator: (v) => v!.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  hint: const Text('-- Select Mode --', style: TextStyle(color: Colors.white54)),
                  decoration: _buildInputDecoration('Game Mode'),
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white),
                  items: _modeOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _mode = v),
                  validator: (v) => v == null ? 'Mode is required' : null,
                ),
                const SizedBox(height: 16),

                InkWell(
                  onTap: _selectDateTime,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _buildInputDecoration('Match Date & Time'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _time == null ? 'Tap to select' : DateFormat('dd MMM yyyy, hh:mm a').format(_time!),
                          style: TextStyle(color: _time == null ? Colors.white54 : Colors.white, fontSize: 16),
                        ),
                        Icon(Icons.calendar_month, color: _time == null ? Colors.grey : Colors.indigoAccent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 🌟 ECONOMY & SLOTS 🌟
                const Text("ECONOMY & SLOTS", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prizePoolController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Total Prize (🪙)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _perKillController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Per Kill (🪙)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _entryFeeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Entry Fee (🪙)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _slotsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Total Slots'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _prizeDescriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3, 
                  decoration: _buildInputDecoration(
                    'Prize Distribution Details (Optional)', 
                    hint: '1st Team: 20 Coins\nTop Fragger: 5 Coins'
                  ),
                ),
                const SizedBox(height: 24),

                // 🌟 GAME SETTINGS 🌟
                const Text("GAME SETTINGS", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        hint: const Text('Type', style: TextStyle(color: Colors.white54)),
                        decoration: _buildInputDecoration('Team Type'),
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white),
                        items: _typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _type = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _version,
                        hint: const Text('Version', style: TextStyle(color: Colors.white54)),
                        decoration: _buildInputDecoration('Version'),
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white),
                        items: _versionOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (v) => setState(() => _version = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _map,
                  hint: const Text('-- Select Map --', style: TextStyle(color: Colors.white54)),
                  decoration: _buildInputDecoration('Map'),
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white),
                  items: _mapOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _map = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 40),

                // 🌟 SUBMIT BUTTON 🌟
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Colors.indigoAccent, Colors.deepPurpleAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTournament,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('LAUNCH TOURNAMENT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
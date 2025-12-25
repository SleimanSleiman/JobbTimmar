import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/work_entry.dart';
import '../models/report.dart';
import '../services/report_service.dart';
import '../utils/pdf_generator.dart';
import 'add_entry_screen.dart';
import 'customer_history_screen.dart';
import 'admin_reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DbHelper _dbHelper = DbHelper.instance;
  final ReportService _reportService = ReportService.instance;
  
  ActiveReportData? _activeReportData;
  bool _isLoading = true;
  int _adminTapCount = 0;
  DateTime? _lastAdminTap;

  // Svenska veckodagar
  final List<String> _weekDays = [
    'Mån', 'Tis', 'Ons', 'Tor', 'Fre', 'Lör', 'Sön'
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveReport();
  }

  Future<void> _loadActiveReport() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _reportService.getActiveReportData();

    setState(() {
      _activeReportData = data;
      _isLoading = false;
    });
  }

  List<WorkEntry> get _entries => _activeReportData?.entries ?? [];

  double get _totalHours => _activeReportData?.totalHours ?? 0;

  String get _dateRange => _activeReportData?.dateRange ?? 'Inga arbetspass';

  bool get _canSubmit => _entries.isNotEmpty;

  Future<void> _navigateToAddEntry({WorkEntry? entry}) async {
    // Check if report is submitted (shouldn't happen but safety check)
    if (_activeReportData?.report.isSubmitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kan inte redigera en skickad rapport'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryScreen(entryToEdit: entry),
      ),
    );

    if (result == true) {
      _loadActiveReport();
    }
  }

  Future<void> _deleteEntry(WorkEntry entry) async {
    // Check if report is submitted
    if (_activeReportData?.report.isSubmitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kan inte ta bort från en skickad rapport'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ta bort arbetspass?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Vill du ta bort arbetspasset hos ${entry.customer}?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ta bort', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );

    if (confirmed == true && entry.id != null) {
      await _dbHelper.deleteWorkEntry(entry.id!);
      _loadActiveReport();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arbetspasset borttaget', style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lägg till arbetspass innan du skickar rapporten',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Skicka rapport?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'När rapporten skickas låses den och kan inte ändras.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sammanfattning:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• $_dateRange',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '• ${_entries.length} arbetspass',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '• ${_totalHours.toStringAsFixed(1)} timmar totalt',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text('Skicka', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Generate and share PDF first
        await PdfGenerator.generateAndSendReportEmail(_entries);

        // Mark report as submitted and create new one
        await _reportService.submitActiveReport();

        // Reload to show the new empty report
        await _loadActiveReport();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rapport skickad! En ny rapport har skapats.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte skicka rapport: $e',
                  style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    
    // Reset counter if more than 2 seconds since last tap
    if (_lastAdminTap != null && now.difference(_lastAdminTap!).inSeconds > 2) {
      _adminTapCount = 0;
    }
    
    _lastAdminTap = now;
    _adminTapCount++;
    
    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _openAdminPanel();
    }
  }

  Future<void> _openAdminPanel() async {
    // Show PIN dialog first
    final pinController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Admin-åtkomst'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ange PIN-kod för att öppna admin-panelen'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN-kod',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () {
              // PIN is 1234 (simple for now, can be changed)
              if (pinController.text == '1234') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fel PIN-kod'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Öppna'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminReportsScreen(),
        ),
      ).then((_) => _loadActiveReport());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', 'sv_SE');

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text(
            'JobbTimmar',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 32),
            onPressed: () => _navigateToAddEntry(),
            tooltip: 'Lägg till arbetspass',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 28),
            onSelected: (value) {
              if (value == 'customers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerHistoryScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'customers',
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Hantera kunder', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Report Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Aktiv rapport',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _dateRange,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_entries.length} pass • ${_totalHours.toStringAsFixed(1)} timmar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Lista med arbetspass
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.work_off,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Inga arbetspass i rapporten',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tryck på + för att lägga till',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final weekDay = _weekDays[entry.date.weekday - 1];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _navigateToAddEntry(entry: entry),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Datum och veckodag
                                    Container(
                                      width: 70,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${entry.date.day}/${entry.date.month}',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                          Text(
                                            weekDay,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Kund och timmar
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.customer,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time,
                                                  size: 18,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${entry.hours.toStringAsFixed(1)} timmar',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Ta bort knapp
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red.shade400, size: 28),
                                      onPressed: () => _deleteEntry(entry),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Submit button at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Summering (only show if there are entries)
                  if (_entries.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Totalt i rapporten',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                '${_entries.length} arbetspass',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_totalHours.toStringAsFixed(1)} tim',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _canSubmit ? _submitReport : null,
                      icon: const Icon(Icons.send, size: 28),
                      label: const Text(
                        'Skicka rapport',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSubmit 
                            ? Colors.green.shade600 
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _canSubmit ? 3 : 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

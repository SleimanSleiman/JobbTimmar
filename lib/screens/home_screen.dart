import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/work_entry.dart';
import '../utils/pdf_generator.dart';
import 'add_entry_screen.dart';
import 'customer_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DbHelper _dbHelper = DbHelper.instance;
  List<WorkEntry> _entries = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  // Svenska veckodagar
  final List<String> _weekDays = [
    'Mån',
    'Tis',
    'Ons',
    'Tor',
    'Fre',
    'Lör',
    'Sön'
  ];

  // Svenska månader
  final List<String> _monthNames = [
    '',
    'Januari',
    'Februari',
    'Mars',
    'April',
    'Maj',
    'Juni',
    'Juli',
    'Augusti',
    'September',
    'Oktober',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    final entries = await _dbHelper.getWorkEntriesForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  double get _totalHours {
    return _entries.fold(0, (sum, entry) => sum + entry.hours);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadEntries();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadEntries();
  }

  Future<void> _navigateToAddEntry({WorkEntry? entry}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryScreen(entryToEdit: entry),
      ),
    );

    if (result == true) {
      _loadEntries();
    }
  }

  Future<void> _deleteEntry(WorkEntry entry) async {
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
      _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arbetspasset borttaget',
                style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Inga arbetspass att exportera för denna månad',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    try {
      await PdfGenerator.generateAndSharePdf(
        _entries,
        _selectedMonth.year,
        _selectedMonth.month,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte skapa PDF: $e',
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Inga arbetspass att skicka för denna månad',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    try {
      await PdfGenerator.generateAndSendEmail(
        _entries,
        _selectedMonth.year,
        _selectedMonth.month,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte skicka e-post: $e',
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', 'sv_SE');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JobbTimmar',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
              } else if (value == 'pdf') {
                _generatePdf();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Skapa PDF', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
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
          // Månadsväljare
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      size: 40, color: Colors.blue.shade700),
                  onPressed: _previousMonth,
                ),
                Column(
                  children: [
                    Text(
                      '${_monthNames[_selectedMonth.month]} ${_selectedMonth.year}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
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
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      size: 40, color: Colors.blue.shade700),
                  onPressed: _nextMonth,
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
                              'Inga arbetspass denna månad',
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
                                            entry.date.day.toString(),
                                            style: TextStyle(
                                              fontSize: 24,
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

          // Sammanställning och PDF-knapp
          if (_entries.isNotEmpty)
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
                    // Summering
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
                                'Totalt denna månad',
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

                    // PDF-knapp
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generatePdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 28),
                        label: const Text(
                          'Skapa & dela PDF-rapport',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
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

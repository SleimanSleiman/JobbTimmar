import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/work_entry.dart';

class AddEntryScreen extends StatefulWidget {
  final WorkEntry? entryToEdit;

  const AddEntryScreen({super.key, this.entryToEdit});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _hoursController = TextEditingController();
  final _dbHelper = DbHelper.instance;

  DateTime _selectedDate = DateTime.now();
  List<String> _customerSuggestions = [];
  bool _showSuggestions = false;
  final FocusNode _customerFocusNode = FocusNode();

  // Svenska veckodagar
  final List<String> _weekDays = [
    'Måndag',
    'Tisdag',
    'Onsdag',
    'Torsdag',
    'Fredag',
    'Lördag',
    'Söndag'
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerHistory();

    // Om vi redigerar ett befintligt pass
    if (widget.entryToEdit != null) {
      _selectedDate = widget.entryToEdit!.date;
      _customerController.text = widget.entryToEdit!.customer;
      _hoursController.text = widget.entryToEdit!.hours.toString();
    }

    _customerController.addListener(_onCustomerChanged);
    _customerFocusNode.addListener(() {
      if (_customerFocusNode.hasFocus) {
        // Visa senaste kunder när fältet fokuseras
        _showRecentCustomers();
      } else {
        setState(() {
          _showSuggestions = false;
        });
      }
    });
  }

  Future<void> _loadCustomerHistory() async {
    final customers = await _dbHelper.getAllCustomers();
    setState(() {
      _customerSuggestions = customers.map((c) => c.name).toList();
    });
  }

  Future<void> _showRecentCustomers() async {
    if (_customerController.text.isEmpty) {
      // Visa senast använda kunder om fältet är tomt
      final recent = await _dbHelper.getRecentCustomers(limit: 8);
      if (recent.isNotEmpty && _customerFocusNode.hasFocus) {
        setState(() {
          _customerSuggestions = recent;
          _showSuggestions = true;
        });
      }
    }
  }

  void _onCustomerChanged() {
    final query = _customerController.text;
    if (query.isEmpty) {
      _showRecentCustomers();
      return;
    }

    _dbHelper.searchCustomers(query).then((results) {
      setState(() {
        _customerSuggestions = results;
        _showSuggestions = results.isNotEmpty && _customerFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _hoursController.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  String _getWeekDay(DateTime date) {
    return _weekDays[date.weekday - 1];
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('sv', 'SE'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final customer = _customerController.text.trim();
    final hours = double.tryParse(_hoursController.text.replaceAll(',', '.')) ?? 0;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final weekDay = _weekDays[_selectedDate.weekday - 1];

    final entry = WorkEntry(
      id: widget.entryToEdit?.id,
      date: _selectedDate,
      customer: customer,
      hours: hours,
    );

    if (widget.entryToEdit != null) {
      await _dbHelper.updateWorkEntry(entry);
    } else {
      await _dbHelper.insertWorkEntry(entry);
    }

    if (mounted) {
      // Visa bekräftelse-dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
            size: 60,
          ),
          title: Text(
            widget.entryToEdit != null ? 'Uppdaterat!' : 'Sparat!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          '${dateFormat.format(_selectedDate)} ($weekDay)',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            customer,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          '${hours.toStringAsFixed(1)} timmar',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Stäng dialogen
                  Navigator.pop(context, true); // Gå tillbaka
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _setHours(double hours) {
    _hoursController.text = hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entryToEdit != null ? 'Redigera arbetspass' : 'Lägg till arbetspass',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Datumväljare
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Colors.blue.shade700, size: 28),
                            const SizedBox(width: 12),
                            const Text(
                              'Datum',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dateFormat.format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getWeekDay(_selectedDate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Kund/Arbetsplats med autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _customerController,
                    focusNode: _customerFocusNode,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Kund / Arbetsplats',
                      labelStyle: const TextStyle(fontSize: 18),
                      prefixIcon: Icon(Icons.business,
                          color: Colors.blue.shade700, size: 28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ange kund eller arbetsplats';
                      }
                      return null;
                    },
                    onTap: () {
                      if (_customerController.text.isNotEmpty) {
                        _onCustomerChanged();
                      } else {
                        _showRecentCustomers();
                      }
                    },
                  ),

                  // Autocomplete förslag
                  if (_showSuggestions && _customerSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_customerController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Senast använda:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _customerSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _customerSuggestions[index];
                                final isRecent = _customerController.text.isEmpty;
                                return ListTile(
                                  leading: Icon(
                                    isRecent ? Icons.schedule : Icons.business,
                                    color: isRecent ? Colors.blue.shade600 : Colors.grey.shade600,
                                  ),
                                  title: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  onTap: () {
                                    _customerController.text = suggestion;
                                    _customerController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(offset: suggestion.length),
                                    );
                                    setState(() {
                                      _showSuggestions = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Antal timmar
              TextFormField(
                controller: _hoursController,
                style: const TextStyle(fontSize: 20),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Antal timmar',
                  labelStyle: const TextStyle(fontSize: 18),
                  prefixIcon: Icon(Icons.access_time,
                      color: Colors.blue.shade700, size: 28),
                  suffixText: 'timmar',
                  suffixStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade700, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ange antal timmar';
                  }
                  final hours =
                      double.tryParse(value.replaceAll(',', '.'));
                  if (hours == null || hours < 0) {
                    return 'Ange ett giltigt antal timmar';
                  }
                  if (hours > 24) {
                    return 'Max 24 timmar per dag';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Snabbval för timmar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Snabbval:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickHourButton(2),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(3),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(4),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(5),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickHourButton(6),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(7),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(8),
                      const SizedBox(width: 8),
                      _buildQuickHourButton(7.5),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Spara-knapp
              ElevatedButton.icon(
                onPressed: _saveEntry,
                icon: const Icon(Icons.save, size: 28),
                label: Text(
                  widget.entryToEdit != null ? 'Uppdatera' : 'Spara arbetspass',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),

              const SizedBox(height: 16),

              // Avbryt-knapp
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
                child: Text(
                  'Avbryt',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickHourButton(double hours) {
    final isSelected = _hoursController.text == hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1);
    final label = hours.truncateToDouble() == hours 
        ? hours.toInt().toString() 
        : hours.toStringAsFixed(1);
    
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _setHours(hours),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
          foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: isSelected ? 2 : 0,
        ),
        child: Text(
          '$label h',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

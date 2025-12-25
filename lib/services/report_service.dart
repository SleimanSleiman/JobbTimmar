import '../database/db_helper.dart';
import '../models/report.dart';
import '../models/work_entry.dart';

/// Service for managing reports and their lifecycle.
/// Ensures there's always ONE active report.
class ReportService {
  static final ReportService instance = ReportService._init();
  final DbHelper _dbHelper = DbHelper.instance;

  ReportService._init();

  /// Get the current active report with its entries
  Future<ActiveReportData> getActiveReportData() async {
    final report = await _dbHelper.ensureActiveReport();
    final entries = await _dbHelper.getWorkEntriesForReport(report.id!);
    return ActiveReportData(report: report, entries: entries);
  }

  /// Submit the active report and create a new one
  /// Returns the new active report
  Future<Report> submitActiveReport() async {
    final activeReport = await _dbHelper.getActiveReport();
    if (activeReport == null || activeReport.id == null) {
      throw Exception('Ingen aktiv rapport att skicka');
    }

    // Mark as submitted
    await _dbHelper.submitReport(activeReport.id!);

    // Create new active report
    final newReport = await _dbHelper.createNewReport();
    return newReport;
  }

  /// Check if the active report can be submitted
  Future<bool> canSubmitActiveReport() async {
    final activeReport = await _dbHelper.getActiveReport();
    if (activeReport == null) return false;
    
    final entries = await _dbHelper.getWorkEntriesForReport(activeReport.id!);
    return entries.isNotEmpty;
  }

  /// Get all submitted reports for admin view
  Future<List<ReportWithEntries>> getSubmittedReports() async {
    final reports = await _dbHelper.getSubmittedReports();
    final List<ReportWithEntries> result = [];
    
    for (final report in reports) {
      final entries = await _dbHelper.getWorkEntriesForReport(report.id!);
      result.add(ReportWithEntries(report: report, entries: entries));
    }
    
    return result;
  }

  /// Unlock a submitted report (admin function)
  /// Warning: This can cause double reporting!
  Future<void> unlockReport(int reportId) async {
    await _dbHelper.unlockReport(reportId);
  }

  /// Calculate date range string for a list of entries
  static String getDateRangeString(List<WorkEntry> entries) {
    if (entries.isEmpty) return 'Inga arbetspass';
    
    final dates = entries.map((e) => e.date).toList()..sort();
    final firstDate = dates.first;
    final lastDate = dates.last;
    
    final months = <String>{};
    for (final entry in entries) {
      months.add(_getMonthName(entry.date.month));
    }
    
    if (months.length == 1) {
      return '${months.first} ${firstDate.year}';
    } else {
      return '${months.join(', ')} ${firstDate.year}';
    }
  }

  static String _getMonthName(int month) {
    const monthNames = [
      '', 'Januari', 'Februari', 'Mars', 'April', 'Maj', 'Juni',
      'Juli', 'Augusti', 'September', 'Oktober', 'November', 'December'
    ];
    return monthNames[month];
  }
}

/// Data class for active report with its entries
class ActiveReportData {
  final Report report;
  final List<WorkEntry> entries;

  ActiveReportData({
    required this.report,
    required this.entries,
  });

  double get totalHours => entries.fold(0, (sum, e) => sum + e.hours);
  
  String get dateRange => ReportService.getDateRangeString(entries);
}

/// Data class for a report with its entries
class ReportWithEntries {
  final Report report;
  final List<WorkEntry> entries;

  ReportWithEntries({
    required this.report,
    required this.entries,
  });

  double get totalHours => entries.fold(0, (sum, e) => sum + e.hours);
  
  String get dateRange => ReportService.getDateRangeString(entries);
}

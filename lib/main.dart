import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CRMApp());
}

// ============================================================
// APP
// ============================================================

class CRMApp extends StatelessWidget {
  const CRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Εργασίες Πελατών',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ClientListScreen(),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class Interaction {
  final String id;
  final String type;
  final DateTime date;
  final String notes;

  Interaction({
    required this.id,
    required this.type,
    required this.date,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Τηλεφώνημα',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class Client {
  final String id;
  final String fullName;
  final String phone;
  final String address;
  final DateTime createdDate;
  final List<Interaction> interactions;

  Client({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.createdDate,
    List<Interaction>? interactions,
  }) : interactions = interactions ?? [];

  Client copyWith({
    String? fullName,
    String? phone,
    String? address,
    DateTime? createdDate,
    List<Interaction>? interactions,
  }) {
    return Client(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdDate: createdDate ?? this.createdDate,
      interactions: interactions ?? this.interactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'createdDate': createdDate.toIso8601String(),
      'interactions':
          interactions.map((interaction) => interaction.toJson()).toList(),
    };
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    final interactionList = json['interactions'];

    return Client(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdDate: DateTime.tryParse(
            json['createdDate']?.toString() ?? '',
          ) ??
          DateTime.now(),
      interactions: interactionList is List
          ? interactionList
              .whereType<Map>()
              .map(
                (item) => Interaction.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : [],
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String removeAccents(String str) {
  const withAccents = 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΆΈΉΊΌΎΏ';
  const withoutAccents = 'αβγδεζηθικλμνξοπρστυφχψωαεηιουω';

  String result = str;

  for (int i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }

  return result.toLowerCase();
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();

  return '$day/$month/$year';
}

String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

String generateId() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

// ============================================================
// CLIENT LIST SCREEN
// ============================================================

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final List<Client> _clients = [];

  String _searchQuery = '';
  bool _loading = true;

  // ----------------------------------------------------------
  // STORAGE
  // ----------------------------------------------------------

  Future<File> _getStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/ergasies_pelaton.json');
  }

  Future<void> _loadClients() async {
    try {
      final file = await _getStorageFile();

      if (await file.exists()) {
        final content = await file.readAsString();

        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);

          if (decoded is List) {
            _clients.clear();

            for (final item in decoded) {
              if (item is Map) {
                _clients.add(
                  Client.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Σφάλμα φόρτωσης: $e');
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveClients() async {
    try {
      final file = await _getStorageFile();

      final data = _clients
          .map((client) => client.toJson())
          .toList();

      await file.writeAsString(
        jsonEncode(data),
        flush: true,
      );
    } catch (e) {
      debugPrint('Σφάλμα αποθήκευσης: $e');
    }
  }

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  // ----------------------------------------------------------
  // SEARCH
  // ----------------------------------------------------------

  List<Client> get _filteredClients {
    if (_searchQuery.trim().isEmpty) {
      return _clients;
    }

    final query = removeAccents(_searchQuery.trim());

    return _clients.where((client) {
      final name = removeAccents(client.fullName);
      final phone = client.phone;
      final address = removeAccents(client.address);

      return name.contains(query) ||
          phone.contains(query) ||
          address.contains(query);
    }).toList();
  }

  // ----------------------------------------------------------
  // CLIENT ACTIONS
  // ----------------------------------------------------------

  Future<void> _addClient(Client client) async {
    setState(() {
      _clients.add(client);
    });

    await _saveClients();
  }

  Future<void> _updateClient(Client updatedClient) async {
    final index = _clients.indexWhere(
      (client) => client.id == updatedClient.id,
    );

    if (index != -1) {
      setState(() {
        _clients[index] = updatedClient;
      });

      await _saveClients();
    }
  }

  Future<void> _deleteClient(String id) async {
    setState(() {
      _clients.removeWhere((client) => client.id == id);
    });

    await _saveClients();
  }

  // ----------------------------------------------------------
  // ADD CLIENT DIALOG
  // ----------------------------------------------------------

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Νέος Πελάτης'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ονοματεπώνυμο',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Τηλέφωνο',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Διεύθυνση',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Συμπλήρωσε το ονοματεπώνυμο.'),
                    ),
                  );
                  return;
                }

                final client = Client(
                  id: generateId(),
                  fullName: name,
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  createdDate: DateTime.now(),
                );

                Navigator.pop(dialogContext);

                await _addClient(client);
              },
              child: const Text('Αποθήκευση'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
  }

  // ----------------------------------------------------------
  // OPEN CLIENT
  // ----------------------------------------------------------

  Future<void> _openClient(Client client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailsScreen(
          client: client,
          onClientChanged: _updateClient,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // EXCEL EXPORT
  // ----------------------------------------------------------

  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();

      final clientsSheet = excel['Clients'];
      excel.setDefaultSheet('Clients');

      clientsSheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Ονοματεπώνυμο'),
        TextCellValue('Τηλέφωνο'),
        TextCellValue('Διεύθυνση'),
        TextCellValue('Ημερομηνία Δημιουργίας'),
      ]);

      for (final client in _clients) {
        clientsSheet.appendRow([
          TextCellValue(client.id),
          TextCellValue(client.fullName),
          TextCellValue(client.phone),
          TextCellValue(client.address),
          TextCellValue(formatDate(client.createdDate)),
        ]);
      }

      final interactionsSheet = excel['Interactions'];

      interactionsSheet.appendRow([
        TextCellValue('Client ID'),
        TextCellValue('Πελάτης'),
        TextCellValue('Τύπος'),
        TextCellValue('Ημερομηνία'),
        TextCellValue('Ώρα'),
        TextCellValue('Σχόλιο'),
      ]);

      for (final client in _clients) {
        for (final interaction in client.interactions) {
          interactionsSheet.appendRow([
            TextCellValue(client.id),
            TextCellValue(client.fullName),
            TextCellValue(interaction.type),
            TextCellValue(formatDate(interaction.date)),
            TextCellValue(formatTime(interaction.date)),
            TextCellValue(interaction.notes),
          ]);
        }
      }

      final fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/ergasies_pelaton.xlsx';

        final file = File(path);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(path)],
          text: 'Εργασίες Πελατών - Excel',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Σφάλμα εξαγωγής: $e'),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // EXCEL IMPORT
  // ----------------------------------------------------------

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null ||
          result.files.single.path == null) {
        return;
      }

      final bytes =
          await File(result.files.single.path!).readAsBytes();

      final excel = Excel.decodeBytes(bytes);

      int importedCount = 0;

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];

        if (sheet == null) {
          continue;
        }

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];

          if (row.isEmpty) {
            continue;
          }

          final name =
              row.length > 1
                  ? row[1]?.value?.toString().trim() ?? ''
                  : '';

          final phone =
              row.length > 2
                  ? row[2]?.value?.toString().trim() ?? ''
                  : '';

          final address =
              row.length > 3
                  ? row[3]?.value?.toString().trim() ?? ''
                  : '';

          if (name.isEmpty) {
            continue;
          }

          _clients.add(
            Client(
              id: generateId(),
              fullName: name,
              phone: phone,
              address: address,
              createdDate: DateTime.now(),
            ),
          );

          importedCount++;
        }
      }

      await _saveClients();

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Εισήχθησαν $importedCount πελάτες.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Σφάλμα εισαγωγής: $e'),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // DELETE CONFIRMATION
  // ----------------------------------------------------------

  Future<void> _confirmDelete(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Διαγραφή πελάτη'),
          content: Text(
            'Θέλεις να διαγράψεις τον πελάτη '
            '${client.fullName};\n\n'
            'Θα διαγραφεί και όλο το ιστορικό του.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Άκυρο

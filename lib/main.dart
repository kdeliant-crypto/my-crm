import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CRMApp());
}

class CRMApp extends StatelessWidget {
  const CRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My CRM',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ClientListScreen(),
    );
  }
}

class Interaction {
  final String type;
  final DateTime date;
  final String notes;

  Interaction({
    required this.type,
    required this.date,
    required this.notes,
  });
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
}

String _removeAccents(String str) {
  const withAccents = 'ΆΈΉΊΌΎΏάέήίόύώ';
  const withoutAccents = 'ΑΕΗΟΥΩαεηιουω';
  String result = str;
  for (int i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return result.toLowerCase();
}

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final List<Client> _clients = [
    Client(
      id: '1',
      fullName: 'Γιώργος Παπαδόπουλος',
      phone: '6912345678',
      address: 'Αθήνα',
      createdDate: DateTime.now().subtract(const Duration(days: 5)),
      interactions: [
        Interaction(
          type: 'Τηλεφώνημα',
          date: DateTime.now().subtract(const Duration(days: 2)),
          notes: 'Συζήτηση για προσφορά.',
        )
      ],
    ),
    Client(
      id: '2',
      fullName: 'Maria Kouveli',
      phone: '6987654321',
      address: 'Θεσσαλονίκη',
      createdDate: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  String _searchQuery = '';

  List<Client> get _filteredClients {
    if (_searchQuery.isEmpty) {
      return _clients;
    }
    final query = _removeAccents(_searchQuery);
    return _clients.where((client) {
      final name = _removeAccents(client.fullName);
      final phone = client.phone;
      final address = _removeAccents(client.address);
      return name.contains(query) || phone.contains(query) || address.contains(query);
    }).toList();
  }

  void _addClient(Client client) {
    setState(() {
      _clients.add(client);
    });
  }

  void _updateClient(Client updatedClient) {
    setState(() {
      final index = _clients.indexWhere((c) => c.id == updatedClient.id);
      if (index != -1) {
        _clients[index] = updatedClient;
      }
    });
  }

  void _deleteClient(String id) {
    setState(() {
      _clients.removeWhere((c) => c.id == id);
    });
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Clients'];
      excel.setDefaultSheet('Clients');

      sheetObject.appendRow([
        TextCellValue('ID'),
        TextCellValue('Ονοματεπώνυμο'),
        TextCellValue('Τηλέφωνο'),
        TextCellValue('Διεύθυνση'),
        TextCellValue('Ημερομηνία Δημιουργίας')
      ]);

      for (var client in _clients) {
        sheetObject.appendRow([
          TextCellValue(client.id),
          TextCellValue(client.fullName),
          TextCellValue(client.phone),
          TextCellValue(client.address),
          TextCellValue(client.createdDate.toIso8601String()),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/crm_clients.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([XFile(path)], text: 'Εξαγωγή Πελατών CRM');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα εξαγωγής: $e')),
        );
      }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        var bytes = await File(result.files.single.path!).readAsBytes();
        var excel = Excel.decodeBytes(bytes);

        int importedCount = 0;
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet == null) continue;

          for (var i = 1; i < sheet.rows.length; i++) {
            var row = sheet.rows[i];
            if (row.isNotEmpty && row[0] != null) {
              String name = row.length > 1 ? row[1]?.value?.toString() ?? '' : '';
              String phone = row.length > 2 ? row[2]?.value?.toString() ?? '' : '';
              String address = row.length > 3 ? row[3]?.value?.toString() ?? '' : '';

              if (name.isNotEmpty) {
                _clients.add(Client(
                  id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
                  fullName: name,
                  phone: phone,
                  address: address,
                  createdDate: DateTime.now(),
                ));
                importedCount++;
              }
            }
          }
        }

        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of

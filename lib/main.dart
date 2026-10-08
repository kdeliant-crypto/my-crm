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
      date: DateTime.tryParse(
            json['date']?.toString() ?? '',
          ) ??
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
    result = result.replaceAll(
      withAccents[i],
      withoutAccents[i],
    );
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

    return File(
      '${directory.path}/ergasies_pelaton.json',
    );
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
          .map(
            (client) => client.toJson(),
          )
          .toList();

      await file.writeAsString(
        jsonEncode(data),
        flush: true,
      );
    } catch (e) {
      debugPrint('Σφάλμα αποθήκευσης: $e');
    }
  }

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

    final query = removeAccents(
      _searchQuery.trim(),
    );

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
      _clients.removeWhere(
        (client) => client.id == id,
      );
    });

    await _saveClients();
  }

  // ----------------------------------------------------------
  // ADD CLIENT
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
                      content: Text(
                        'Συμπλήρωσε το ονοματεπώνυμο.',
                      ),
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
          TextCellValue(
            formatDate(client.createdDate),
          ),
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
            TextCellValue(
              formatDate(interaction.date),
            ),
            TextCellValue(
              formatTime(interaction.date),
            ),
            TextCellValue(interaction.notes),
          ]);
        }
      }

      final fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();

        final path =
            '${directory.path}/ergasies_pelaton.xlsx';

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
            content: Text(
              'Σφάλμα εξαγωγής: $e',
            ),
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

      final bytes = await File(
        result.files.single.path!,
      ).readAsBytes();

      final excel = Excel.decodeBytes(bytes);

      int importedCount = 0;
      int skippedCount = 0;

      // --------------------------------------------------------
      // ΔΙΑΒΑΖΟΥΜΕ ΟΛΑ ΤΑ ΦΥΛΛΑ ΤΟΥ EXCEL
      // --------------------------------------------------------

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];

        if (sheet == null || sheet.rows.isEmpty) {
          continue;
        }

        int headerRowIndex = -1;
        int nameColumn = -1;
        int phoneColumn = -1;
        int addressColumn = -1;

        bool hasInteractionType = false;
        bool hasInteractionDate = false;
        bool hasInteractionTime = false;
        bool hasInteractionComment = false;
        bool hasClientId = false;

        // ------------------------------------------------------
        // ΕΝΤΟΠΙΣΜΟΣ ΕΠΙΚΕΦΑΛΙΔΩΝ
        // ------------------------------------------------------

        for (int rowIndex = 0;
            rowIndex < sheet.rows.length;
            rowIndex++) {
          final row = sheet.rows[rowIndex];

          int foundNameColumn = -1;
          int foundPhoneColumn = -1;
          int foundAddressColumn = -1;

          bool foundInteractionType = false;
          bool foundInteractionDate = false;
          bool foundInteractionTime = false;
          bool foundInteractionComment = false;
          bool foundClientId = false;

          for (int columnIndex = 0;
              columnIndex < row.length;
              columnIndex++) {
            String value = row[columnIndex]
                    ?.value
                    ?.toString()
                    .trim() ??
                '';

            String header = value
                .toLowerCase()
                .replaceAll('ά', 'α')
                .replaceAll('έ', 'ε')
                .replaceAll('ή', 'η')
                .replaceAll('ί', 'ι')
                .replaceAll('ό', 'ο')
                .replaceAll('ύ', 'υ')
                .replaceAll('ώ', 'ω')
                .replaceAll('ϊ', 'ι')
                .replaceAll('ΐ', 'ι')
                .replaceAll('ϋ', 'υ')
                .replaceAll('ΰ', 'υ')
                .replaceAll(RegExp(r'\s+'), ' ');

            // Ονοματεπώνυμο / Όνομα / Πελάτης
            if (header == 'ονοματεπωνυμο' ||
                header == 'ονομα' ||
                header == 'πελατης' ||
                header == 'πελατησ') {
              foundNameColumn = columnIndex;
            }

            // Τηλέφωνο
            if (header == 'τηλεφωνο' ||
                header == 'κινητο' ||
                header == 'τηλεφωνο επικοινωνιας' ||
                header == 'τηλεφωνο επικοινωνιασ') {
              foundPhoneColumn = columnIndex;
            }

            // Διεύθυνση
            if (header == 'διευθυνση' ||
                header == 'διευθυνση κατοικιας' ||
                header == 'διευθυνση κατοικιασ') {
              foundAddressColumn = columnIndex;
            }

            // Στήλες ιστορικού αλληλεπιδράσεων
            if (header == 'τυπος') {
              foundInteractionType = true;
            }

            if (header == 'ημερομηνια') {
              foundInteractionDate = true;
            }

            if (header == 'ωρα') {
              foundInteractionTime = true;
            }

            if (header == 'σχολιο') {
              foundInteractionComment = true;
            }

            if (header == 'client id') {
              foundClientId = true;
            }
          }

          if (foundNameColumn != -1) {
            headerRowIndex = rowIndex;
            nameColumn = foundNameColumn;
            phoneColumn = foundPhoneColumn;
            addressColumn = foundAddressColumn;

            hasInteractionType = foundInteractionType;
            hasInteractionDate = foundInteractionDate;
            hasInteractionTime = foundInteractionTime;
            hasInteractionComment = foundInteractionComment;
            hasClientId = foundClientId;

            break;
          }
        }

        if (headerRowIndex == -1 ||
            nameColumn == -1) {
          continue;
        }

        // ------------------------------------------------------
        // ΔΕΝ ΕΙΣΑΓΟΥΜΕ ΦΥΛΛΑ ΙΣΤΟΡΙΚΟΥ
        // ------------------------------------------------------

        final isInteractionSheet =
            hasClientId ||
            (hasInteractionType &&
                (hasInteractionDate ||
                    hasInteractionTime ||
                    hasInteractionComment));

        if (isInteractionSheet) {
          continue;
        }

        // ------------------------------------------------------
        // ΕΙΣΑΓΩΓΗ ΠΕΛΑΤΩΝ
        // ------------------------------------------------------

        for (int rowIndex = headerRowIndex + 1;
            rowIndex < sheet.rows.length;
            rowIndex++) {
          final row = sheet.rows[rowIndex];

          if (row.isEmpty ||
              nameColumn >= row.length) {
            continue;
          }

          final name = row[nameColumn]
                  ?.value
                  ?.toString()
                  .trim() ??
              '';

          if (name.isEmpty) {
            continue;
          }

          String phone = '';

          if (phoneColumn != -1 &&
              phoneColumn < row.length) {
            phone = row[phoneColumn]
                    ?.value
                    ?.toString()
                    .trim() ??
                '';
          }

          String address = '';

          if (addressColumn != -1 &&
              addressColumn < row.length) {
            address = row[addressColumn]
                    ?.value
                    ?.toString()
                    .trim() ??
                '';
          }

          final normalizedName = removeAccents(name);

          // ----------------------------------------------------
          // ΕΛΕΓΧΟΣ ΔΙΠΛΟΤΥΠΩΝ
          // ----------------------------------------------------

          final alreadyExists = _clients.any((client) {
            final existingName =
                removeAccents(client.fullName);

            final sameName =
                existingName == normalizedName;

            if (phone.isNotEmpty) {
              final samePhone =
                  client.phone.trim() == phone;

              return sameName && samePhone;
            }

            return sameName;
          });

          if (alreadyExists) {
            skippedCount++;
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

        String message =
            'Εισήχθησαν $importedCount πελάτες.';

        if (skippedCount > 0) {
          message +=
              ' Παραλείφθηκαν $skippedCount διπλότυπα.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Σφάλμα εισαγωγής: $e',
            ),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // DELETE CLIENT
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
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Διαγραφή'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteClient(client.id);
    }
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Εργασίες Πελατών'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportToExcel();
              }

              if (value == 'import') {
                _importFromExcel();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: Text('Εξαγωγή Excel'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Εισαγωγή Excel'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Αναζήτηση Πελάτη',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredClients.isEmpty
                      ? const Center(
                          child: Text(
                            'Δεν υπάρχουν πελάτες.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            final client =
                                _filteredClients[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  client.fullName,
                                ),
                                subtitle: Text(
                                  [
                                    if (client.phone.isNotEmpty)
                                      client.phone,
                                    if (client.address.isNotEmpty)
                                      client.address,
                                    'Ιστορικό: ${client.interactions.length}',
                                  ].join('\n'),
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  _openClient(client);
                                },
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                  ),
                                  onPressed: () {
                                    _confirmDelete(client);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClientDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Νέος Πελάτης'),
      ),
    );
  }
}

// ============================================================
// CLIENT DETAILS
// ============================================================

class ClientDetailsScreen extends StatefulWidget {
  final Client client;
  final Future<void> Function(Client client) onClientChanged;

  const ClientDetailsScreen({
    super.key,
    required this.client,
    required this.onClientChanged,
  });

  @override
  State<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState
    extends State<ClientDetailsScreen> {
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  // ----------------------------------------------------------
  // ADD INTERACTION
  // ----------------------------------------------------------

  Future<void> _addInteraction({
    required String initialType,
  }) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    String selectedType = initialType;

    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                initialType == 'Επίσκεψη'
                    ? 'Νέα Επίσκεψη'
                    : 'Νέο Τηλεφώνημα',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Τύπος',
                        prefixIcon: Icon(
                          Icons.category,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Τηλεφώνημα',
                          child: Text('Τηλεφώνημα'),
                        ),
                        DropdownMenuItem(
                          value: 'Επίσκεψη',
                          child: Text('Επίσκεψη'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today,
                      ),
                      title: const Text('Ημερομηνία'),
                      subtitle: Text(
                        formatDate(selectedDate),
                      ),
                      onTap: () async {
                        final picked =
                            await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            );
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.access_time,
                      ),
                      title: const Text('Ώρα'),
                      subtitle: Text(
                        selectedTime.format(context),
                      ),
                      onTap: () async {
                        final picked =
                            await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Σχόλιο / Εργασία',
                        hintText:
                            'Τι ζήτησε ο πελάτης ή τι εργασία έγινε;',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
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
                    final interactionDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final interaction = Interaction(
                      id: generateId(),
                      type: selectedType,
                      date: interactionDate,
                      notes: notesController.text.trim(),
                    );

                    final updatedInteractions = [
                      ..._client.interactions,
                      interaction,
                    ];

                    final updatedClient =
                        _client.copyWith(
                      interactions: updatedInteractions,
                    );

                    Navigator.pop(dialogContext);

                    setState(() {
                      _client = updatedClient;
                    });

                    await widget.onClientChanged(
                      updatedClient,
                    );
                  },
                  child: const Text('Αποθήκευση'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
  }

  // ----------------------------------------------------------
  // DELETE INTERACTION
  // ----------------------------------------------------------

  Future<void> _deleteInteraction(
    Interaction interaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Διαγραφή εγγραφής'),
          content: const Text(
            'Θέλεις να διαγράψεις αυτή την εγγραφή '
            'από το ιστορικό;',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Διαγραφή'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final updatedInteractions =
        _client.interactions
            .where(
              (item) => item.id != interaction.id,
            )
            .toList();

    final updatedClient = _client.copyWith(
      interactions: updatedInteractions,
    );

    setState(() {
      _client = updatedClient;
    });

    await widget.onClientChanged(
      updatedClient,
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sortedInteractions =
        List<Interaction>.from(
      _client.interactions,
    );

    sortedInteractions.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_client.fullName),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _client.fullName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (_client.phone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone),
                        const SizedBox(width: 8),
                        Text(_client.phone),
                      ],
                    ),
                  if (_client.address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _client.address,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _addInteraction(
                        initialType: 'Τηλεφώνημα',
                      );
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text(
                      'Τηλεφώνημα',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _addInteraction(
                        initialType: 'Επίσκεψη',
                      );
                    },
                    icon: const Icon(
                      Icons.location_on,
                    ),
                    label: const Text(
                      'Επίσκεψη',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              16,
              12,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ιστορικό',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Expanded(
            child: sortedInteractions.isEmpty
                ? const Center(
                    child: Text(
                      'Δεν υπάρχει ιστορικό για αυτόν τον πελάτη.',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        sortedInteractions.length,
                    itemBuilder: (context, index) {
                      final interaction =
                          sortedInteractions[index];

                      final isPhone =
                          interaction.type ==
                              'Τηλεφώνημα';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              isPhone
                                  ? Icons.phone
                                  : Icons.location_on,
                            ),
                          ),
                          title: Text(
                            interaction.type,
                          ),
                          subtitle: Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 6,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${formatDate(interaction.date)}  '
                                  '${formatTime(interaction.date)}',
                                ),
                                if (interaction
                                    .notes
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    interaction.notes,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          isThreeLine:
                              interaction.notes.isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () {
                              _deleteInteraction(
                                interaction,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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
  const withAccents = 'ΆΈΉΊΌΎΏάέήίόύώϊϋΐΰ';
  const withoutAccents = 'ΑΕΗΙΟΥΩαεηιουωιυιυ';

  String result = str;
  for (int i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return result.toLowerCase();
}

String _formatDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '$day/$month/${dt.year}';
}

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
      address: 'Σταδίου 10, Αθήνα',
      createdDate: DateTime(2026, 10, 1),
      interactions: [
        Interaction(
          type: 'Τηλεφωνική επικοινωνία',
          date: DateTime(2026, 10, 2, 11, 5),
          notes: 'Επιβεβαίωση ραντεβού',
        ),
      ],
    ),
    Client(
      id: '2',
      fullName: 'Μαρία Κωνσταντίνου',
      phone: '6987654321',
      address: 'Τσιμισκή 45, Θεσσαλονίκη',
      createdDate: DateTime(2026, 10, 3),
    ),
  ];

  String _searchQuery = '';

  List<Client> get _filteredClients {
    if (_searchQuery.trim().isEmpty) return _clients;

    final query = _removeAccents(_searchQuery);
    return _clients.where((client) {
      final nameMatch = _removeAccents(client.fullName).contains(query);
      final addressMatch = _removeAccents(client.address).contains(query);
      final phoneMatch = client.phone.contains(query);
      final dateMatch = _formatDate(client.createdDate).contains(query);

      return nameMatch || addressMatch || phoneMatch || dateMatch;
    }).toList();
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Πελάτες'];
      excel.setDefaultSheet('Πελάτες');

      sheetObject.appendRow([
        TextCellValue('Ονοματεπώνυμο'),
        TextCellValue('Τηλέφωνο'),
        TextCellValue('Διεύθυνση'),
        TextCellValue('Ημερομηνία Εγγραφής'),
      ]);

      for (var client in _clients) {
        sheetObject.appendRow([
          TextCellValue(client.fullName),
          TextCellValue(client.phone),
          TextCellValue(client.address),
          TextCellValue(_formatDate(client.createdDate)),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/clients_crm.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([XFile(filePath)], text: 'Εξαγωγή Πελατών CRM');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα κατά την εξαγωγή: $e')),
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
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        int importedCount = 0;
        for (var table in excel.tables.keys) {
          final rows = excel.tables[table]!.rows;
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.isEmpty || row[0] == null) continue;

            String name = row[0]?.value?.toString() ?? '';
            String phone = row.length > 1 ? row[1]?.value?.toString() ?? '' : '';
            String address = row.length > 2 ? row[2]?.value?.toString() ?? '' : '';

            if (name.isNotEmpty) {
              _clients.add(
                Client(
                  id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
                  fullName: name,
                  phone: phone,
                  address: address,
                  createdDate: DateTime.now(),
                ),
              );
              importedCount++;
            }
          }
        }

        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Εισήχθησαν $importedCount πελάτες επιτυχώς!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα κατά την εισαγωγή: $e')),
        );
      }
    }
  }

  void _addClient(Client client) {
    setState(() {
      _clients.add(client);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My CRM'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportToExcel();
              } else if (value == 'import') {
                _importFromExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Εξαγωγή σε Excel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Εισαγωγή από Excel'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Αναζήτηση (Όνομα, Διεύθυνση, Τηλέφωνο, Ημ/νία)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text('Δεν βρέθηκαν πελάτες.'))
                : ListView.builder(
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(
                            client.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '📞 ${client.phone}\n📍 ${client.address}\n📅 ${_formatDate(client.createdDate)}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ClientDetailScreen(client: client),
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClientDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Νέος Πελάτης'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ονοματεπώνυμο'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Υποχρεωτικό πεδίο' : null,
                ),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Τηλέφωνο'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Υποχρεωτικό πεδίο' : null,
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Διεύθυνση'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Υποχρεωτικό πεδίο' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ακύρωση'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newClient = Client(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  fullName: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  createdDate: DateTime.now(),
                );
                _addClient(newClient);
                Navigator.pop(context);
              }
            },
            child: const Text('Αποθήκευση'),
          ),
        ],
      ),
    );
  }
}

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  void _addInteraction(String type, String notes) {
    setState(() {
      widget.client.interactions.add(
        Interaction(
          type: type,
          date: DateTime.now(),
          notes: notes,
        ),
      );
    });
  }

  void _showAddInteractionDialog() {
    final typeController = TextEditingController(text: 'Τηλεφωνική επικοινωνία');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Νέα Επικοινωνία / Σημείωση'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: typeController.text,
                  items: const [
                    DropdownMenuItem(
                      value: 'Τηλεφωνική επικοινωνία',
                      child: Text('Τηλεφωνική επικοινωνία'),
                    ),
                    DropdownMenuItem(
                      value: 'Συνάντηση / Ραντεβού',
                      child: Text('Συνάντηση / Ραντεβού'),
                    ),
                    DropdownMenuItem(
                      value: 'Email / Μήνυμα',
                      child: Text('Email / Μήνυμα'),
                    ),
                    DropdownMenuItem(
                      value: 'Γενική Σημείωση',
                      child: Text('Γενική Σημείωση'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) typeController.text = val;
                  },
                  decoration: const InputDecoration(labelText: 'Τύπος'),
                ),
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Σημειώσεις / Λεπτομέρειες',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Υποχρεωτικό πεδίο' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ακύρωση'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addInteraction(
                  typeController.text,
                  notesController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Προσθήκη'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.fullName),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      Text(
                        'Στοιχεία Πελάτη',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('📞 Τηλέφωνο: ${widget.client.phone}'),
                      const SizedBox(height: 4),
                      Text('📍 Διεύθυνση: ${widget.client.address}'),
                      const SizedBox(height: 4),
                      Text(
                        '📅 Ημ/νία Εγγραφής: ${_formatDate(widget.client.createdDate)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ιστορικό Επικοινωνίας',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment),
                    onPressed: _showAddInteractionDialog,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              widget.client.interactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text('Δεν υπάρχουν καταγεγραμμένες επικοινωνίες.'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.client.interactions.length,
                      itemBuilder: (context, index) {
                        final interaction = widget.client.interactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(interaction.type),
                            subtitle: Text(
                              '${interaction.notes}\n'
                              '${_formatDate(interaction.date)} - ${_formatTime(interaction.date)}',
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddInteractionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Νέα Σημείωση'),
      ),
    );
  }
}

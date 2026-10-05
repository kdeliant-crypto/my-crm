import 'package:flutter/material.dart';

void main() {
  runApp(const CRMApp());
}

class CRMApp extends StatelessWidget {
  const CRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ιστορικό Εργασίας',
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
  }) : interactions = [];
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

  void _addClient(Client client) {
    setState(() {
      _clients.add(client);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ιστορικό Εργασίας'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Αναζήτηση (Όνομα, Διεύθυνση, Τηλέφωνο)',
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
        onPressed: () => _

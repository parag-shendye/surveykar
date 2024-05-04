import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:surveryor/utils.dart';
import 'main.dart';
import 'projectmanagement_page.dart';

class Part {
  final String name;
  final int qa;
  final int qe;
  final double unitPrice;
  final String material;
  final String? comment;
  final double? totalCost;

  Part({
    required this.name,
    this.qa = 1,
    this.qe = 1,
    required this.unitPrice,
    required this.material,
    this.comment,
    this.totalCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'qa': qa,
      'qe': qe,
      'unit_price': unitPrice,
      'material': material,
      'comment': comment,
      'total_cost': totalCost,
    };
  }
}

class PartPage extends StatefulWidget {
  final String projectId;

  PartPage({required this.projectId});

  @override
  _PartPageState createState() => _PartPageState();
}

class _PartPageState extends State<PartPage> {
  String appBarTitle = 'Loading...';
  bool found = false;
  late String projectId;
  final _formKey = GlobalKey<FormState>();
  late Future<List<Part>> _partsFuture;
  TextEditingController totalCostController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController qaController = TextEditingController();

  Future<void> _fetchProjectData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final response =
        await supabase.from('projects').select().eq('id', projectId);
    if (response.isEmpty) {
      throw Exception('Failed to fetch projects: $response');
    }
    final p = response.first;
    try {
      if (p != null) {
        setState(() {
          appBarTitle = p['vehicle_id'];
        });
      } else {
        setState(() {
          appBarTitle = 'not found';
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<List<Part>> _fetchParts() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final response =
        await supabase.from('parts').select().eq('project_id', projectId);
    if (response.isEmpty) {
      return [];
    }
    final List<Part> parts = [];
    for (final row in response) {
      final part = Part(
          name: row['name'] as String,
          comment: row['comment'] as String,
          qa: row['qa'] as int,
          qe: row['qe'] as int,
          material: getKeyFromValue(
              MaterialTypeToNumberMap, row['material_id'] as int) as String,
          unitPrice: row['unit_price'] as double,
          totalCost: row['total_cost'] as double);
      parts.add(part);
    }
    return parts;
  }

  @override
  void initState() {
    super.initState();
    projectId = widget.projectId;
    print('Project ID: $projectId');
    _fetchProjectData();
    _partsFuture = _fetchParts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Part Management for $appBarTitle'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed("/account");
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed("/project");
              },
            ),
          ]),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                    labelText: 'Quantity Available'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  qaController.text = v;
                                  double? up =
                                      double.tryParse(unitPriceController.text);
                                  totalCostController.text =
                                      (double.tryParse(v)! * up!).toString();
                                },
                              ),
                            ),
                            SizedBox(
                                width: 16), // Add spacing between the fields
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                    labelText: 'Quantity Expected'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: TextFormField(
                              decoration: const InputDecoration(
                                  labelText: 'Unit Price'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (v) {
                                unitPriceController.text = v;
                                double? qa = double.tryParse(qaController.text);
                                totalCostController.text =
                                    (double.tryParse(v)! * qa!).toString();
                              },
                            )),
                            SizedBox(
                                width: 16), // Add spacing between the fields
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration:
                                    InputDecoration(labelText: 'Material'),
                                items: ['metal', 'rubber', 'fiber', 'glass']
                                    .map((material) => DropdownMenuItem<String>(
                                          value: material,
                                          child: Text(material),
                                        ))
                                    .toList(),
                                onChanged: (value) {},
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Comment'),
                      maxLines: null,
                    ),
                    TextFormField(
                      controller: totalCostController,
                      decoration: InputDecoration(labelText: 'Total Cost'),
                      maxLines: null,
                      readOnly: true,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: () {}, child: Text('Add'))
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18.0),
          Expanded(
              child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  scrollDirection:
                      Axis.vertical, // Scroll horizontally if needed
                  child: FutureBuilder<List<Part>>(
                    future: _partsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error: ${snapshot.error} ${snapshot.data}'));
                      } else {
                        final List<Part> parts = snapshot.data!;
                        if (parts == null || parts.isEmpty) {
                          return const Text("Data Not Available");
                        } else {
                          return DataTable(
                            columns: const [
                              DataColumn(label: Text('Part Name')),
                              DataColumn(label: Text('Quantity Ava.')),
                              DataColumn(label: Text('Quantity Exp.')),
                              DataColumn(label: Text('Comment')),
                              DataColumn(label: Text('Material')),
                              DataColumn(label: Text('Unit Price')),
                              DataColumn(label: Text('Total Cost')),
                              DataColumn(label: Text('Edit')),
                            ],
                            rows: parts.map((part) {
                              print(part);
                              return DataRow(cells: [
                                DataCell(Text(part.name)),
                                DataCell(Text('${part.qa}')),
                                DataCell(Text('${part.qe}')),
                                DataCell(Text(part.comment ?? '')),
                                DataCell(Text(part.material)),
                                DataCell(Text('${part.unitPrice}')),
                                DataCell(Text('${part.totalCost}')),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    print(part.name);
                                  },
                                )),
                              ]);
                            }).toList(),
                          );
                        }
                      }
                    },
                  ))),
        ],
      ),
    );
  }
}

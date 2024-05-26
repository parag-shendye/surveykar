import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surveryor/utils.dart';
import 'main.dart';
import 'projectmanagement_page.dart';

class Part {
  final String? id;
  final String name;
  final int qa;
  final int qe;
  final double unitPrice;
  final String gst;
  final String material;
  final String? comment;
  final double? totalCost;

  Part({
    this.id,
    required this.name,
    this.qa = 1,
    this.qe = 1,
    required this.unitPrice,
    required this.gst,
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
      'gst': gst,
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
  bool _loading = false;
  bool found = false;
  String? material;
  String? gst;
  String? partId;
  double? amount;
  double? payableAmount;
  late String projectId;
  final _formKey = GlobalKey<FormState>();
  late Future<List<Part>> _partsFuture;
  TextEditingController nameController = TextEditingController();
  TextEditingController totalCostController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController qaController = TextEditingController();
  TextEditingController qeController = TextEditingController();
  TextEditingController materialController = TextEditingController();
  TextEditingController gstController = TextEditingController();
  TextEditingController commentController = TextEditingController();

  Future<void> _updatePart(BuildContext context) async {
    setState(() {
      _loading = true;
    });
    final partName = nameController.text.trim();
    final comment = commentController.text.trim();
    final qa = qaController.text.isNotEmpty
        ? int.tryParse(qaController.text.trim())
        : 1;
    final qe = qeController.text.isNotEmpty
        ? int.tryParse(qeController.text.trim())
        : 1;
    final unitPrice = double.tryParse(unitPriceController.text.trim());
    final totalCost = double.tryParse(totalCostController.text.trim());
    final user = supabase.auth.currentUser;

    final updates = {
      'name': partName,
      'comment': comment,
      'qa': qa,
      'qe': qe,
      'unit_price': unitPrice,
      'gst  ': gstTypeToNumberMap[gst],
      'total_cost': unitPrice! * qa!,
      'material_id': materialTypeToNumberMap[material],
      'project_id': projectId
    };
    if (partId != null) {
      updates["id"] = partId;
      partId = null;
    }
    if (partName == '' || qa < 1 || qe! < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Invalid Data",
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
      ));
      return;
    }
    try {
      await supabase.from('parts').upsert(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Part Updated',
              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
          backgroundColor: Color.fromARGB(141, 50, 241, 11),
        ));
      }
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.message,
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: const Color.fromARGB(141, 235, 80, 80),
      ));
    } catch (error) {
      print('Error: $error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unexpected Error',
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
      ));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _partsFuture = _fetchParts();
        });
      }
    }
  }

  Future<void> _editPart(String id) async {
    var part = await supabase.from('parts').select().eq('id', id);
    var selectedPart = part.toList()[0];
    partId = selectedPart['id'];
    nameController.text = selectedPart['name'];
    commentController.text = selectedPart['comment'];
    qaController.text = selectedPart['qa'].toString();
    qeController.text = selectedPart['qe'].toString();
    totalCostController.text = selectedPart['total_cost'].toString();
    unitPriceController.text = selectedPart['unit_price'].toString();
    setState(() {
      material =
          getKeyFromValue(materialTypeToNumberMap, selectedPart['material_id']);
      gst = getKeyFromValue(gstTypeToNumberMap, selectedPart['gst_id']);
    });
  }

  Future<void> _deletePart(String id) async {
    var res = await supabase.from('parts').delete().eq('id', id).select();
    if (res.isNotEmpty) {
      print(res);
      if (mounted) {
        setState(() {
          _loading = false;
          _partsFuture = _fetchParts();
        });
      }
    }
  }

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
    payableAmount = 0.0;
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
          id: row['id'],
          name: row['name'] as String,
          comment: row['comment'] as String,
          qa: row['qa'] as int,
          qe: row['qe'] as int,
          material: getKeyFromValue(
                  materialTypeToNumberMap, row['material_id'] as int) ??
              'None',
          unitPrice: row['unit_price'].toDouble(),
          gst: getKeyFromValue(gstTypeToNumberMap, row['gst'] as int) ?? 'None',
          totalCost: row['total_cost'].toDouble());
      parts.add(part);
      setState(() {
        payableAmount = payableAmount! + row["total_cost"].toDouble();
      });
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
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    ScaffoldMessenger.of(
                                            context as BuildContext)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Quantity available cannot be null',
                                          style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255))),
                                      backgroundColor:
                                          Color.fromARGB(141, 235, 80, 80),
                                    ));
                                  }
                                  return;
                                },
                                controller: qaController,
                                decoration: const InputDecoration(
                                    labelText: 'Quantity Available'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        signed: false, decimal: false),
                                onChanged: (v) {
                                  var qVal = int.tryParse(v.trim());
                                  var vVal = double.tryParse(
                                      unitPriceController.text.trim());
                                  if (vVal == null || qVal == null) {
                                    return;
                                  }
                                  var tc = vVal * qVal;
                                  totalCostController.text = tc.toString();
                                },
                              ),
                            ),
                            const SizedBox(
                                width: 16), // Add spacing between the fields
                            Expanded(
                              child: TextFormField(
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    ScaffoldMessenger.of(
                                            context as BuildContext)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Quantity expected cannot be null',
                                          style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255))),
                                      backgroundColor:
                                          Color.fromARGB(141, 235, 80, 80),
                                    ));
                                  }
                                  return;
                                },
                                controller: qeController,
                                decoration: const InputDecoration(
                                    labelText: 'Quantity Expected'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        signed: false, decimal: false),
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
                              controller: unitPriceController,
                              decoration: const InputDecoration(
                                  labelText: 'Unit Price'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (v) {
                                var vVal = double.tryParse(v.trim());
                                var qVal =
                                    int.tryParse(qaController.text.trim());
                                if (vVal == null || qVal == null) {
                                  return;
                                }
                                var tc = (vVal * qVal);
                                totalCostController.text = tc.toString();
                              },
                            )),
                            const SizedBox(
                                width: 16), // Add spacing between the fields
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: material,
                                decoration: const InputDecoration(
                                    labelText: 'Material'),
                                items: ['metal', 'rubber', 'fiber', 'glass']
                                    .map((material) => DropdownMenuItem<String>(
                                          value: material,
                                          child: Text(material),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    material = value;
                                  });
                                },
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
                              child: DropdownButtonFormField<String>(
                                value: '0',
                                decoration:
                                    const InputDecoration(labelText: 'GST'),
                                items: ['0', '5', '10', '12', '18', '28']
                                    .map((gst) => DropdownMenuItem<String>(
                                          value: gst,
                                          child: Text(gst + '%'),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    gst = '0';
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    TextFormField(
                      controller: commentController,
                      decoration: const InputDecoration(labelText: 'Comment'),
                      maxLines: null,
                    ),
                    TextFormField(
                      controller: totalCostController,
                      decoration: InputDecoration(labelText: 'Total Cost'),
                      maxLines: null,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (qaController.text.isNotEmpty &&
                                qeController.text.isNotEmpty &&
                                unitPriceController.text.isNotEmpty &&
                                totalCostController.text.isNotEmpty &&
                                nameController.text.isNotEmpty &&
                                gst != null &&
                                material != null) {
                              _updatePart(context);
                              qaController.clear();
                              qeController.clear();
                              unitPriceController.clear();
                              totalCostController.clear();
                              nameController.clear();
                              commentController.clear();
                              materialController.clear();
                              gstController.clear();
                              material = null;
                              gst = null;
                            } else {
                              // Show error message or handle invalid input
                            }
                          });
                        },
                        child: const Text('Add')),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Added Parts',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                Expanded(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 12),
                        scrollDirection:
                            Axis.vertical, // Scroll horizontally if needed
                        child: FutureBuilder<List<Part>>(
                          future: _partsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(
                                  child: Text(
                                      'Error: ${snapshot.error} ${snapshot.data}'));
                            } else {
                              final List<Part> parts = snapshot.data!;
                              if (parts == null || parts.isEmpty) {
                                return const Text("Data Not Available");
                              } else {
                                return Wrap(
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                          columns: const [
                                            DataColumn(
                                                label: Text('Part Name')),
                                            DataColumn(
                                                label: Text('Quantity Ava.')),
                                            DataColumn(
                                                label: Text('Quantity Exp.')),
                                            DataColumn(label: Text('Comment')),
                                            DataColumn(label: Text('Material')),
                                            DataColumn(
                                                label: Text('Unit Price')),
                                            DataColumn(label: Text('GST')),
                                            DataColumn(
                                                label: Text('Total Cost')),
                                            DataColumn(label: Text('Edit')),
                                            DataColumn(label: Text('Delete')),
                                          ],
                                          rows: parts.map((part) {
                                            print(part);
                                            return DataRow(cells: [
                                              DataCell(Text(part.name)),
                                              DataCell(Text('${part.qa}')),
                                              DataCell(Text('${part.qe}')),
                                              DataCell(
                                                  Text(part.comment ?? '')),
                                              DataCell(Text(part.material)),
                                              DataCell(
                                                  Text('${part.unitPrice}')),
                                              DataCell(Text('${part.gst}')),
                                              DataCell(
                                                  Text('${part.totalCost}')),
                                              DataCell(IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () {
                                                  _editPart(part.id!);
                                                },
                                              )),
                                              DataCell(IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red.shade700,
                                                ),
                                                onPressed: () {
                                                  _deletePart(part.id!);
                                                },
                                              )),
                                            ]);
                                          }).toList(),
                                          headingRowColor: WidgetStateProperty
                                              .resolveWith<Color?>(
                                                  (Set<WidgetState> states) {
                                            if (states.contains(
                                                WidgetState.hovered)) {
                                              return Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.08);
                                            }
                                            return const Color.fromARGB(
                                                255,
                                                255,
                                                0,
                                                0); // Use the default value.
                                          })),
                                    )
                                  ],
                                );
                              }
                            }
                          },
                        )))
              ],
            ),
          )),
          Expanded(
              child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payable Amount : ${payableAmount}',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                )
              ],
            ),
          )),
          Container(
            child: Text('©2024 Parag Shendye. All rights reserved'),
          )
        ],
      ),
    );
  }
}

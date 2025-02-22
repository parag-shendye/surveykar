import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'part_page.dart';
import 'utils.dart';

class Project {
  final String? id;
  final String typeOfPolicy;
  final DateTime dateOfRegistration;
  final DateTime dateOfAccident;
  final String vehicleId;
  final String? title;

  Project(
      {this.id,
      required this.typeOfPolicy,
      required this.dateOfRegistration,
      required this.dateOfAccident,
      required this.vehicleId,
      this.title});

  @override
  String toString() {
    return '${this.dateOfRegistration}  | ${this.dateOfAccident} | ${this.vehicleId} | ${this.title} | ${this.typeOfPolicy}';
  }
}

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  _ProjectManagementPageState createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  List<Project> projects = [];
  late Future<List<Project>> _projectsFuture;
  final TextEditingController vehicleIdController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  String? selectedPolicy;
  DateTime? selectedDate;
  DateTime? dateOfRegistration;
  String? projectId;
  var _loading = true;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null &&
        picked != selectedDate &&
        picked.difference(DateTime.now()) <= Duration.zero) {
      setState(() {
        selectedDate = picked;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Selected date should not be in future",
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
      ));
    }
  }

  Future<void> _selectDateOfRegistration(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null &&
        picked != dateOfRegistration &&
        picked.difference(DateTime.now()) <= Duration.zero) {
      setState(() {
        dateOfRegistration = picked;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Date of registration cannot be in future",
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
      ));
    }
  }

  Future<void> _editProject(String id) async {
    var proj = await supabase.from('projects').select().eq('id', id);
    var selectedProject = proj.toList()[0];
    projectId = selectedProject['id'];
    vehicleIdController.text = selectedProject['vehicle_id'];
    titleController.text = selectedProject['title'];
    setState(() {
      selectedPolicy = getKeyFromValue(
          policyTypeToNumberMap, selectedProject['type_of_policy_id']);
      selectedDate = DateTime.parse(selectedProject["date_of_accident"]);
      dateOfRegistration =
          DateTime.parse(selectedProject["date_of_registration"]);
    });
    // print(selectedDate);
  }

  Future<void> _updateProject() async {
    setState(() {
      _loading = true;
    });
    final vehicleId = vehicleIdController.text.trim();
    final title = titleController.text.isNotEmpty ? titleController.text : null;
    final policy_type = policyTypeToNumberMap[selectedPolicy];
    final user = supabase.auth.currentUser;
    final updates = {
      'user_id': user!.id,
      'vehicle_id': vehicleId,
      'type_of_policy_id': policy_type,
      'date_of_registration': dateOfRegistration!.toIso8601String(),
      'date_of_accident': selectedDate!.toIso8601String(),
      'title': title
    };
    if (projectId != null) {
      updates["id"] = projectId;
    }
    if (dateOfRegistration!.difference(selectedDate!) > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Date of registration should be before selected date",
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
      ));
      return;
    }
    try {
      await supabase.from('projects').upsert(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile Updated',
              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
          backgroundColor: Color.fromARGB(141, 50, 241, 11),
        ));
      }
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.message,
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: Color.fromARGB(141, 235, 80, 80),
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
          _projectsFuture = fetchProjects();
        });
      }
    }
  }

  Future<void> _goToParts(String id) async {
    if (id == null) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => PartPage(projectId: id),
      ));
    }
  }

  Future<List<Project>> fetchProjects() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final response = await supabase
        .from('projects')
        .select()
        .eq('user_id', user.id)
        .order('date_of_accident', ascending: false)
        .limit(5);

    if (response.isEmpty) {
      throw Exception('Failed to fetch projects: $response');
    }
    final List<Project> projects = [];
    for (final row in response) {
      final project = Project(
        id: row['id'] as String,
        title: row['title'] as String?,
        typeOfPolicy: getKeyFromValue(
            policyTypeToNumberMap, row['type_of_policy_id'] as int)!,
        dateOfRegistration:
            DateTime.parse(row['date_of_registration'] as String),
        dateOfAccident: DateTime.parse(row['date_of_accident'] as String),
        vehicleId: row['vehicle_id'] as String,
      );
      projects.add(project);
    }
    return projects;
  }

  @override
  void initState() {
    super.initState();
    _projectsFuture = fetchProjects(); // Call your method to fetch projects
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Management'), actions: <Widget>[
        IconButton(
          icon: const Icon(
            Icons.account_circle,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed("/account");
          },
        )
      ]),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                scrollDirection: Axis.vertical,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Project',
                      style: TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedPolicy,
                      onChanged: (value) {
                        setState(() {
                          selectedPolicy = value;
                        });
                      },
                      items: policyTypeToNumberMap.keys.toList().map((policy) {
                        return DropdownMenuItem<String>(
                          value: policy,
                          child: Text(policy),
                        );
                      }).toList(),
                      decoration:
                          const InputDecoration(labelText: 'Type of Policy'),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: () {
                        _selectDate(context);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Accident',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(selectedDate == null
                                ? 'Select Date'
                                : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: () {
                        _selectDateOfRegistration(context);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Registration',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(dateOfRegistration == null
                                ? 'Select Registration Date'
                                : '${dateOfRegistration!.day}/${dateOfRegistration!.month}/${dateOfRegistration!.year}'),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: vehicleIdController,
                      decoration:
                          const InputDecoration(labelText: 'Vehicle ID'),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (selectedPolicy != null &&
                              selectedDate != null &&
                              dateOfRegistration != null &&
                              vehicleIdController.text.isNotEmpty) {
                            _updateProject();
                            dateOfRegistration = null;
                            selectedPolicy = null;
                            selectedDate = null;
                            vehicleIdController.clear();
                            titleController.clear();
                          } else {
                            // Show error message or handle invalid input
                          }
                        });
                      },
                      child: const Text('Add Project'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Previous Projects',
                    style:
                        TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      scrollDirection:
                          Axis.vertical, // Scroll horizontally if needed
                      child: FutureBuilder<List<Project>>(
                        future: _projectsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          } else {
                            final List<Project> projects = snapshot.data!;
                            return Wrap(children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Type of Policy')),
                                    DataColumn(
                                        label: Text('Date of Registration')),
                                    DataColumn(label: Text('Date of Accident')),
                                    DataColumn(label: Text('Vehicle ID')),
                                    DataColumn(label: Text('Edit')),
                                  ],
                                  rows: projects.map((project) {
                                    return DataRow(
                                        onLongPress: () {
                                          _goToParts(project.id!);
                                        },
                                        cells: [
                                          DataCell(Text(project.typeOfPolicy)),
                                          DataCell(Text(
                                              '${project.dateOfRegistration.day}/${project.dateOfRegistration.month}/${project.dateOfRegistration.year}')),
                                          DataCell(Text(
                                              '${project.dateOfAccident.day}/${project.dateOfAccident.month}/${project.dateOfAccident.year}')),
                                          DataCell(Text(
                                              project.vehicleId.toString())),
                                          DataCell(IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () {
                                              _editProject(
                                                  project.id as String);
                                            },
                                          )),
                                        ]);
                                  }).toList(),
                                  headingRowColor:
                                      WidgetStateProperty.resolveWith<Color?>(
                                          (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.08);
                                    }
                                    return const Color.fromARGB(255, 255, 0,
                                        0); // Use the default value.
                                  }),
                                ),
                              )
                            ]);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            child: Text('©2024 Parag Shendye. All rights reserved'),
          )
        ],
      ),
    );
  }
}

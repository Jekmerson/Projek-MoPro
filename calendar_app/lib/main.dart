import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DateTime today = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TextEditingController _eventController = TextEditingController();
  String? _selectedEvent;
  Set<DateTime> _eventDays = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllEvents();
  }

  Future<void> _addEventToFirestore(String event) async {
    try {
      await FirebaseFirestore.instance.collection('event_kalender').add({
        'event_name': event,
        'date': Timestamp.fromDate(_selectedDay!),
      });

      setState(() {
        _eventDays.add(DateTime(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day));
      });
    } catch (e) {
      print("Error menyimpan event: $e");
    }
  }

  Future<void> _loadAllEvents() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('event_kalender').get();
      final allEvents = snapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        _eventDays = allEvents
            .map((event) => (event['date'] as Timestamp).toDate())
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet();
      });
    } catch (e) {
      print("Error memuat event: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getEventsForDayFromFirestore(
      DateTime day) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('event_kalender')
          .where('date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(DateTime(day.year, day.month, day.day)))
          .where('date',
              isLessThan: Timestamp.fromDate(
                  DateTime(day.year, day.month, day.day)
                      .add(const Duration(days: 1))))
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();
    } catch (e) {
      print("Error mengambil event: $e");
      return [];
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      today = selectedDay;
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final events = await _getEventsForDayFromFirestore(selectedDay);
    if (events.isNotEmpty) {
      setState(() {
        _selectedEvent = events.first['data']['event_name'];
      });
    } else {
      setState(() {
        _selectedEvent = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Table Calendar")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  scrollable: true,
                  title: const Text("Event Name"),
                  content: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _eventController,
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                        onPressed: () async {
                          final eventText = _eventController.text.trim();
                          if (eventText.isNotEmpty) {
                            await _addEventToFirestore(eventText);
                            setState(() {
                              _selectedEvent = eventText;
                            });
                            _eventController.clear();
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text("Submit"))
                  ],
                );
              });
        },
        child: const Icon(Icons.add),
      ),
      body: content(),
    );
  }

  Widget content() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Text(today.toString().split(" ")[0]),
          TableCalendar(
            locale: "en_US",
            rowHeight: 43,
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true),
            availableGestures: AvailableGestures.all,
            selectedDayPredicate: (day) => isSameDay(day, today),
            focusedDay: today,
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            onDaySelected: _onDaySelected,
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (_eventDays
                    .contains(DateTime(date.year, date.month, date.day))) {
                  return Positioned(
                    bottom: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          if (_selectedEvent != null) ...[
            Row(
              children: [
                Text('Event: $_selectedEvent'),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          _eventController.text = _selectedEvent!;
                          return AlertDialog(
                            title: const Text("Edit Event"),
                            content: TextField(
                              controller: _eventController,
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () async {
                                  final updatedEvent =
                                      _eventController.text.trim();
                                  if (updatedEvent.isNotEmpty) {
                                    final events =
                                        await _getEventsForDayFromFirestore(
                                            _selectedDay!);
                                    if (events.isNotEmpty) {
                                      await FirebaseFirestore.instance
                                          .collection('event_kalender')
                                          .doc(events.first['id'])
                                          .update({'event_name': updatedEvent});
                                      setState(() {
                                        _selectedEvent = updatedEvent;
                                      });
                                    }
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text("Update"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final events =
                                      await _getEventsForDayFromFirestore(
                                          _selectedDay!);
                                  if (events.isNotEmpty) {
                                    await FirebaseFirestore.instance
                                        .collection('event_kalender')
                                        .doc(events.first['id'])
                                        .delete();

                                    setState(() {
                                      _selectedEvent = null;
                                      _eventDays.remove(DateTime(
                                          _selectedDay!.year,
                                          _selectedDay!.month,
                                          _selectedDay!.day));
                                    });
                                  }
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text("Delete"),
                              ),
                            ],
                          );
                        });
                  },
                  child: const Text("Edit"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'camera_screen.dart';

class DatePickerScreen extends StatefulWidget {
  const DatePickerScreen({super.key});

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  DateTime? _selectedDate;
  bool _opening = false;
  bool _envLoaded = false;

  @override
  void initState() {
    super.initState();

    // Load .env AFTER first frame so UI is not blocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEnvSilently();
    });
  }

  Future<void> _loadEnvSilently() async {
    if (_envLoaded) return;
    try {
      await dotenv.load(fileName: ".env");
      _envLoaded = true;
    } catch (_) {}
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_opening) return;
    _opening = true;

    // Allow current frame to finish to remove lag
    await Future.delayed(Duration.zero);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        // Forces smoother rendering on some devices
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    _opening = false;

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Image.asset('assets/logo.png', height: 40),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Select Evidence Date',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'No date selected'
                      : DateFormat('EEEE, MMMM d, yyyy')
                          .format(_selectedDate!),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Pick Date'),
              ),
              const SizedBox(height: 32),
              if (_selectedDate != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CameraScreen(selectedDate: _selectedDate!),
                      ),
                    );
                  },
                  child: const Text('Continue to Camera'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

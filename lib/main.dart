import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dropdown/basic_dropdown_common.dart';
import 'dropdown/basic_dropdown_caller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure window size for desktop platforms
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 1300),
    minimumSize: Size(900, 1300),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SearchDropdown Tester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DropdownTestPage(),
    );
  }
}

class DropdownTestPage extends StatefulWidget {
  const DropdownTestPage({super.key});

  @override
  State<DropdownTestPage> createState() => _DropdownTestPageState();
}

class _DropdownTestPageState extends State<DropdownTestPage> {
  // Selected values for each dropdown
  DropDownItem<String>? selectedFruit;
  DropDownItem<int>? selectedNumber;
  DropDownItem<String>? selectedCountry;
  DropDownItem<int>? selectedLargeItem;

  // Generate dummy data
  late final List<DropDownItem<String>> fruits;
  late final List<DropDownItem<int>> numbers;
  late final List<DropDownItem<String>> countries;
  late final List<DropDownItem<int>> largeItemsList;

  @override
  void initState() {
    super.initState();

    // Dropdown 1: Small list of fruits
    fruits = const [
      DropDownItem(value: 'apple', label: 'Apple'),
      DropDownItem(value: 'banana', label: 'Banana'),
      DropDownItem(value: 'cherry', label: 'Cherry'),
      DropDownItem(value: 'date', label: 'Date'),
      DropDownItem(value: 'elderberry', label: 'Elderberry'),
      DropDownItem(value: 'fig', label: 'Fig'),
      DropDownItem(value: 'grape', label: 'Grape'),
      DropDownItem(value: 'honeydew', label: 'Honeydew'),
    ];

    // Dropdown 2: Numbers 1-50
    numbers = List.generate(
      50,
          (index) =>
          DropDownItem(
            value: index + 1,
            label: 'Number ${index + 1}',
          ),
    );

    // Dropdown 3: Countries
    countries = const [
      DropDownItem(value: 'us', label: 'United States'),
      DropDownItem(value: 'uk', label: 'United Kingdom'),
      DropDownItem(value: 'ca', label: 'Canada'),
      DropDownItem(value: 'au', label: 'Australia'),
      DropDownItem(value: 'de', label: 'Germany'),
      DropDownItem(value: 'fr', label: 'France'),
      DropDownItem(value: 'jp', label: 'Japan'),
      DropDownItem(value: 'cn', label: 'China'),
      DropDownItem(value: 'in', label: 'India'),
      DropDownItem(value: 'br', label: 'Brazil'),
      DropDownItem(value: 'mx', label: 'Mexico'),
      DropDownItem(value: 'es', label: 'Spain'),
      DropDownItem(value: 'it', label: 'Italy'),
      DropDownItem(value: 'ru', label: 'Russia'),
      DropDownItem(value: 'kr', label: 'South Korea'),
    ];

    // Dropdown 4: Large list with 5000 items to test performance
    largeItemsList = List.generate(
      5000,
          (index) =>
          DropDownItem(
            value: index,
            label: 'Item ${index.toString().padLeft(
                4, '0')} - ${_getRandomLabel(index)}',
          ),
    );
  }

  String _getRandomLabel(int seed) {
    final labels = [
      'Product',
      'Component',
      'Element',
      'Widget',
      'Module',
      'Entity',
      'Object',
      'Asset',
    ];
    return labels[seed % labels.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SearchDropdown Tester'),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dropdown Widget Test Suite',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test various dropdown scenarios with different data sizes and types',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Dropdown 1: Fruits (Small list)
                _buildDropdownSection(
                  title: '1. Fruits (8 items)',
                  description: 'Small list for basic functionality testing',
                  selectedValue: selectedFruit?.label,
                  dropdown: dropDown<String>(
                    width: 300,
                    listItems: fruits,
                    initiallySelected: selectedFruit,
                    onChanged: (item) {
                      setState(() {
                        selectedFruit = item;
                      });
                    },
                    hintText: 'Select a fruit...',
                    showKeyboard: true,
                  ),
                ),

                const SizedBox(height: 32),

                // Dropdown 2: Numbers (Medium list)
                _buildDropdownSection(
                  title: '2. Numbers (50 items)',
                  description: 'Medium-sized list with numeric values',
                  selectedValue: selectedNumber?.label,
                  dropdown: dropDown<int>(
                    width: 300,
                    listItems: numbers,
                    initiallySelected: selectedNumber,
                    onChanged: (item) {
                      setState(() {
                        selectedNumber = item;
                      });
                    },
                    hintText: 'Select a number...',
                    showKeyboard: true,
                  ),
                ),

                const SizedBox(height: 32),

                // Dropdown 3: Countries (Medium list)
                _buildDropdownSection(
                  title: '3. Countries (15 items)',
                  description: 'Test with real-world data',
                  selectedValue: selectedCountry?.label,
                  dropdown: dropDown<String>(
                    width: 300,
                    listItems: countries,
                    initiallySelected: selectedCountry,
                    onChanged: (item) {
                      setState(() {
                        selectedCountry = item;
                      });
                    },
                    hintText: 'Select a country...',
                    showKeyboard: true,
                    maxDropdownHeight: 250,
                  ),
                ),

                const SizedBox(height: 32),

                // Dropdown 4: Large list (Performance test)
                _buildDropdownSection(
                  title: '4. Large Dataset (5000 items) - Performance Test',
                  description: 'Stress test with large list and search functionality',
                  selectedValue: selectedLargeItem?.label,
                  dropdown: dropDown<int>(
                    width: 400,
                    listItems: largeItemsList,
                    initiallySelected: selectedLargeItem,
                    onChanged: (item) {
                      setState(() {
                        selectedLargeItem = item;
                      });
                    },
                    hintText: 'Search through 5000 items...',
                    showKeyboard: true,
                    maxDropdownHeight: 300,
                  ),
                ),

                const SizedBox(height: 48),

                // Display selected values
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Values:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildSelectionRow(
                          'Fruit:', selectedFruit?.label ?? 'None'),
                      _buildSelectionRow(
                          'Number:', selectedNumber?.label ?? 'None'),
                      _buildSelectionRow(
                          'Country:', selectedCountry?.label ?? 'None'),
                      _buildSelectionRow(
                          'Large Item:', selectedLargeItem?.label ?? 'None'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required String description,
    required String? selectedValue,
    required Widget dropdown,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          dropdown,
          if (selectedValue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Selected: $selectedValue',
                style: TextStyle(fontSize: 12, color: Colors.green.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

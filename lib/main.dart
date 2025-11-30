import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dropdown/common/item_dropper_common.dart';
import 'dropdown/item_dropper_caller.dart';
import 'dropdown/item_dropper_multi_caller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure window size for desktop platforms
  await windowManager.ensureInitialized();

  // Get screen size using PlatformDispatcher
  final screenSize = ui.PlatformDispatcher.instance.views.first.physicalSize /
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  
  // On macOS, account for menubar (~22px) and dock (varies, typically ~50-60px when visible)
  // We'll use a conservative estimate of 80px total for system UI
  final windowSize = Size(
    screenSize.width,
    screenSize.height - 80, // Account for menubar and dock
  );

  final windowOptions = WindowOptions(
    size: windowSize,
    minimumSize: const Size(800, 600),
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
  // Selected values for single-select dropdowns
  ItemDropperItem<String>? selectedFruit;
  ItemDropperItem<int>? selectedNumber;
  ItemDropperItem<String>? selectedCountry;
  ItemDropperItem<int>? selectedLargeItem;

  // Selected values for multi-select dropdown
  List<ItemDropperItem<String>> selectedFruits = [];
  List<ItemDropperItem<String>> selectedMaxItems = [];
  ItemDropperItem<String>? selectedCity;
  
  // Add-enabled dropdown (example)
  List<ItemDropperItem<String>> addEnabledItems = [];
  ItemDropperItem<String>? selectedAddItem;
  
  // Separate state for dropdown 9 (add-enabled multi-select fruits)
  late List<ItemDropperItem<String>> fruitsWithAdd;
  List<ItemDropperItem<String>> selectedFruitsWithAdd = [];

  // Generate dummy data
  late List<ItemDropperItem<String>> fruits;
  late final List<ItemDropperItem<int>> numbers;
  late final List<ItemDropperItem<String>> countries;
  late final List<ItemDropperItem<int>> largeItemsList;
  late final List<ItemDropperItem<String>> maxTestItems;
  late final List<ItemDropperItem<String>> citiesWithStates;

  @override
  void initState() {
    super.initState();

    // Dropdown 1: Small list of fruits
    fruits = const [
      ItemDropperItem(value: 'apple', label: 'Apple'),
      ItemDropperItem(value: 'banana', label: 'Banana'),
      ItemDropperItem(value: 'cherry', label: 'Cherry'),
      ItemDropperItem(value: 'date', label: 'Date'),
      ItemDropperItem(value: 'elderberry', label: 'Elderberry'),
      ItemDropperItem(value: 'fig', label: 'Fig'),
      ItemDropperItem(value: 'grape', label: 'Grape'),
      ItemDropperItem(value: 'honeydew', label: 'Honeydew'),
    ];
    
    // Separate copy for dropdown 9 (add-enabled multi-select)
    fruitsWithAdd = [
      ItemDropperItem(value: 'apple', label: 'Apple'),
      ItemDropperItem(value: 'banana', label: 'Banana'),
      ItemDropperItem(value: 'cherry', label: 'Cherry'),
      ItemDropperItem(value: 'date', label: 'Date'),
      ItemDropperItem(value: 'elderberry', label: 'Elderberry'),
      ItemDropperItem(value: 'fig', label: 'Fig'),
      ItemDropperItem(value: 'grape', label: 'Grape'),
      ItemDropperItem(value: 'honeydew', label: 'Honeydew'),
    ];

    // Dropdown 2: Numbers 1-50
    numbers = List.generate(
      50,
          (index) =>
          ItemDropperItem(
            value: index + 1,
            label: 'Number ${index + 1}',
          ),
    );

    // Dropdown 3: Countries
    countries = const [
      ItemDropperItem(value: 'us', label: 'United States'),
      ItemDropperItem(value: 'uk', label: 'United Kingdom'),
      ItemDropperItem(value: 'ca', label: 'Canada'),
      ItemDropperItem(value: 'au', label: 'Australia'),
      ItemDropperItem(value: 'de', label: 'Germany'),
      ItemDropperItem(value: 'fr', label: 'France'),
      ItemDropperItem(value: 'jp', label: 'Japan'),
      ItemDropperItem(value: 'cn', label: 'China'),
      ItemDropperItem(value: 'in', label: 'India'),
      ItemDropperItem(value: 'br', label: 'Brazil'),
      ItemDropperItem(value: 'mx', label: 'Mexico'),
      ItemDropperItem(value: 'es', label: 'Spain'),
      ItemDropperItem(value: 'it', label: 'Italy'),
      ItemDropperItem(value: 'ru', label: 'Russia'),
      ItemDropperItem(value: 'kr', label: 'South Korea'),
    ];

    // Dropdown 4: Large list with 5000 items to test performance
    largeItemsList = List.generate(
      5000,
          (index) =>
          ItemDropperItem(
            value: index,
            label: 'Item ${index.toString().padLeft(
                4, '0')} - ${_getRandomLabel(index)}',
          ),
    );

    // Dropdown 6: 10 items with maxSelected of 4
    maxTestItems = const [
      ItemDropperItem(value: 'item1', label: 'Item 1'),
      ItemDropperItem(value: 'item2', label: 'Item 2'),
      ItemDropperItem(value: 'item3', label: 'Item 3'),
      ItemDropperItem(value: 'item4', label: 'Item 4'),
      ItemDropperItem(value: 'item5', label: 'Item 5'),
      ItemDropperItem(value: 'item6', label: 'Item 6'),
      ItemDropperItem(value: 'item7', label: 'Item 7'),
      ItemDropperItem(value: 'item8', label: 'Item 8'),
      ItemDropperItem(value: 'item9', label: 'Item 9'),
      ItemDropperItem(value: 'item10', label: 'Item 10'),
    ];

    // Dropdown 7: Cities grouped by states
    citiesWithStates = const [
      // New York group
      ItemDropperItem(value: 'ny_header', label: 'New York', isGroupHeader: true),
      ItemDropperItem(value: 'nyc', label: 'New York City'),
      ItemDropperItem(value: 'buffalo', label: 'Buffalo'),
      ItemDropperItem(value: 'rochester', label: 'Rochester'),
      ItemDropperItem(value: 'albany', label: 'Albany'),
      ItemDropperItem(value: 'syracuse', label: 'Syracuse'),
      // Connecticut group
      ItemDropperItem(value: 'ct_header', label: 'Connecticut', isGroupHeader: true),
      ItemDropperItem(value: 'hartford', label: 'Hartford'),
      ItemDropperItem(value: 'new_haven', label: 'New Haven'),
      ItemDropperItem(value: 'stamford', label: 'Stamford'),
      ItemDropperItem(value: 'bridgeport', label: 'Bridgeport'),
      ItemDropperItem(value: 'waterbury', label: 'Waterbury'),
      // New Jersey group
      ItemDropperItem(value: 'nj_header', label: 'New Jersey', isGroupHeader: true),
      ItemDropperItem(value: 'newark', label: 'Newark'),
      ItemDropperItem(value: 'jersey_city', label: 'Jersey City'),
      ItemDropperItem(value: 'paterson', label: 'Paterson'),
      ItemDropperItem(value: 'edison', label: 'Edison'),
      ItemDropperItem(value: 'trenton', label: 'Trenton'),
    ];
    
    // Initialize add-enabled dropdown with a few items
    addEnabledItems = const [
      ItemDropperItem(value: 'task1', label: 'Task 1'),
      ItemDropperItem(value: 'task2', label: 'Task 2'),
      ItemDropperItem(value: 'task3', label: 'Task 3'),
    ];
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
            constraints: const BoxConstraints(maxWidth: 1400),
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

                // Two-column layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Dropdowns 1-5
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                    enabled: false, // Disabled for debugging
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
                    enabled: false, // Disabled for debugging
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
                    enabled: false, // Disabled for debugging
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
                    enabled: false, // Disabled for debugging
                  ),
                ),

                const SizedBox(height: 32),

                          // Dropdown 5: Multi-Select Fruits
                          _buildMultiDropdownSection(
                            title: '5. Multi-Select Fruits (8 items)',
                            description: 'Select multiple fruits with chip-based display',
                            selectedValues: selectedFruits.map((e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: fruits,
                              initiallySelected: selectedFruits,
                              onChanged: (items) {
                                setState(() {
                                  selectedFruits = items;
                                });
                              },
                              hintText: 'Select fruits...',
                              maxDropdownHeight: 250,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Right column: Dropdowns 6-7
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown 6: Multi-Select with maxSelected of 4
                          _buildMultiDropdownSection(
                            title: '6. Multi-Select with Max (10 items, max 4)',
                            description: 'Test maxSelected functionality - can only select up to 4 items',
                            selectedValues: selectedMaxItems.map((e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: maxTestItems,
                              initiallySelected: selectedMaxItems,
                              onChanged: (items) {
                                setState(() {
                                  selectedMaxItems = items;
                                });
                              },
                              hintText: 'Select up to 4 items...',
                              maxDropdownHeight: 250,
                              maxSelected: 4,
                              enabled: false, // Disabled for debugging
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Dropdown 7: Cities with State Group Headers
                          _buildDropdownSection(
                            title: '7. Cities by State (with Group Headers)',
                            description: 'Test group headers - states are non-selectable labels',
                            selectedValue: selectedCity?.label,
                            dropdown: dropDown<String>(
                              width: 400,
                              listItems: citiesWithStates,
                              initiallySelected: selectedCity,
                              onChanged: (item) {
                                setState(() {
                                  selectedCity = item;
                                });
                              },
                              hintText: 'Select a city...',
                              showKeyboard: true,
                              maxDropdownHeight: 300,
                              enabled: false, // Disabled for debugging
                            ),
                          ),
                          
                          const SizedBox(height: 32),

                          // Dropdown 8: Add-Enabled Dropdown (Single Select)
                          _buildDropdownSection(
                            title: '8. Add-Enabled Dropdown (Single Select)',
                            description: 'Type a new item name to add it to the list and auto-select it',
                            selectedValue: selectedAddItem?.label,
                            dropdown: dropDown<String>(
                              width: 400,
                              listItems: addEnabledItems,
                              initiallySelected: selectedAddItem,
                              onChanged: (item) {
                                setState(() {
                                  selectedAddItem = item;
                                });
                              },
                              hintText: 'Select or type to add...',
                              showKeyboard: true,
                              maxDropdownHeight: 300,
                              enabled: false, // Disabled for debugging
                              onAddItem: (String searchText) {
                                // Create a new item and add it to the list
                                final newItem = ItemDropperItem<String>(
                                  value: searchText.toLowerCase().replaceAll(' ', '_'),
                                  label: searchText,
                                );
                                setState(() {
                                  addEnabledItems = [...addEnabledItems, newItem];
                                  selectedAddItem = newItem;
                                });
                                return newItem;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 32),

                          // Dropdown 9: Add-Enabled Multi-Select
                          _buildMultiDropdownSection(
                            title: '9. Add-Enabled Multi-Select',
                            description: 'Type a new item name to add it to the list and auto-select it',
                            selectedValues: selectedFruitsWithAdd.map((e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: fruitsWithAdd,
                              initiallySelected: selectedFruitsWithAdd,
                              onChanged: (items) {
                                setState(() {
                                  selectedFruitsWithAdd = items;
                                });
                              },
                              hintText: 'Select fruits or type to add...',
                              maxDropdownHeight: 250,
                              enabled: false, // Disabled for debugging
                              onAddItem: (String searchText) {
                                // Create a new item and add it to the fruitsWithAdd list
                                final newItem = ItemDropperItem<String>(
                                  value: searchText.toLowerCase().replaceAll(' ', '_'),
                                  label: searchText,
                                );
                                setState(() {
                                  fruitsWithAdd = [...fruitsWithAdd, newItem];
                                  selectedFruitsWithAdd = [...selectedFruitsWithAdd, newItem];
                                });
                                return newItem;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          'Single Fruit:', selectedFruit?.label ?? 'None'),
                      _buildSelectionRow(
                          'Number:', selectedNumber?.label ?? 'None'),
                      _buildSelectionRow(
                          'Country:', selectedCountry?.label ?? 'None'),
                      _buildSelectionRow(
                          'Large Item:', selectedLargeItem?.label ?? 'None'),
                      _buildSelectionRow(
                          'Multi Fruits:', selectedFruits.isEmpty
                          ? 'None'
                          : selectedFruits.map((e) => e.label).join(', ')),
                      _buildSelectionRow(
                          'Max Items (4 max):', selectedMaxItems.isEmpty
                          ? 'None'
                          : selectedMaxItems.map((e) => e.label).join(', ')),
                      _buildSelectionRow(
                          'City:', selectedCity?.label ?? 'None'),
                      _buildSelectionRow(
                          'Add-Enabled Item:', selectedAddItem?.label ?? 'None'),
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

  Widget _buildMultiDropdownSection({
    required String title,
    required String description,
    required String selectedValues,
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
          if (selectedValues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Selected: $selectedValues',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
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

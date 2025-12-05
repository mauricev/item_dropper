import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:item_dropper/item_dropper.dart';
import 'dropdown/item_dropper_caller.dart';
import 'dropdown/item_dropper_multi_caller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure window size for desktop platforms
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(1800, 1263),
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
      title: 'ItemDropper Tester',
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
  List<ItemDropperItem<String>> selectedStates = [];
  List<ItemDropperItem<String>> selectedMaxItems = [];
  ItemDropperItem<String>? selectedCity;
  
  // Add-enabled dropdown (example)
  List<ItemDropperItem<String>> addEnabledItems = [];
  ItemDropperItem<String>? selectedAddItem;
  
  // Separate state for dropdown 9 (add-enabled multi-select fruits)
  late List<ItemDropperItem<String>> fruitsWithAdd;
  List<ItemDropperItem<String>> selectedFruitsWithAdd = [];
  
  // Dropdown 10 state
  ItemDropperItem<String>? selectedDropdown10;
  bool dropdown10Enabled = true;

  // Dropdown 11 (deletable multi-select) state
  late final List<ItemDropperItem<String>> deletableDemoBaseItems;
  List<ItemDropperItem<String>> deletableDemoItems = [];
  List<ItemDropperItem<String>> selectedDeletableDemoItems = [];

  // Dropdown 12 (per-item enabled/disabled) state
  late final List<ItemDropperItem<String>> disabledDemoBaseItems;
  List<ItemDropperItem<String>> disabledDemoItems = [];
  ItemDropperItem<String>? selectedDisabledDemoItem;

  // Dropdown 13 (font size testing) state
  late final List<ItemDropperItem<String>> fontSizeTestItems;
  List<ItemDropperItem<String>> selectedFontSizeTestItems = [];
  double chipFieldFontSize = 10.0; // Font size for chips and text field
  double itemFontSize = 10.0; // Font size for dropdown items

  // Dropdown 14 (decoration customization) state
  late final List<ItemDropperItem<String>> decorationTestItems;
  List<ItemDropperItem<String>> selectedDecorationTestItems = [];

  // Field decoration properties
  Color fieldBorderColor = Colors.grey;
  double fieldBorderWidth = 1.0;
  double fieldBorderRadius = 8.0;
  Color fieldBackgroundColor = Colors.white;

  // Chip decoration properties
  Color chipBackgroundColor = Colors.blue;
  Color chipTextColor = Colors.white;
  double chipBorderRadius = 4.0;

  // Font family properties
  String fieldFontFamily = 'Default';
  String itemFontFamily = 'Default';

  // Generate dummy data
  late List<ItemDropperItem<String>> fruits;
  late final List<ItemDropperItem<String>> states;
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

    // Dropdown 5: 50 US States
    states = const [
      ItemDropperItem(value: 'al', label: 'Alabama'),
      ItemDropperItem(value: 'ak', label: 'Alaska'),
      ItemDropperItem(value: 'az', label: 'Arizona'),
      ItemDropperItem(value: 'ar', label: 'Arkansas'),
      ItemDropperItem(value: 'ca', label: 'California'),
      ItemDropperItem(value: 'co', label: 'Colorado'),
      ItemDropperItem(value: 'ct', label: 'Connecticut'),
      ItemDropperItem(value: 'de', label: 'Delaware'),
      ItemDropperItem(value: 'fl', label: 'Florida'),
      ItemDropperItem(value: 'ga', label: 'Georgia'),
      ItemDropperItem(value: 'hi', label: 'Hawaii'),
      ItemDropperItem(value: 'id', label: 'Idaho'),
      ItemDropperItem(value: 'il', label: 'Illinois'),
      ItemDropperItem(value: 'in', label: 'Indiana'),
      ItemDropperItem(value: 'ia', label: 'Iowa'),
      ItemDropperItem(value: 'ks', label: 'Kansas'),
      ItemDropperItem(value: 'ky', label: 'Kentucky'),
      ItemDropperItem(value: 'la', label: 'Louisiana'),
      ItemDropperItem(value: 'me', label: 'Maine'),
      ItemDropperItem(value: 'md', label: 'Maryland'),
      ItemDropperItem(value: 'ma', label: 'Massachusetts'),
      ItemDropperItem(value: 'mi', label: 'Michigan'),
      ItemDropperItem(value: 'mn', label: 'Minnesota'),
      ItemDropperItem(value: 'ms', label: 'Mississippi'),
      ItemDropperItem(value: 'mo', label: 'Missouri'),
      ItemDropperItem(value: 'mt', label: 'Montana'),
      ItemDropperItem(value: 'ne', label: 'Nebraska'),
      ItemDropperItem(value: 'nv', label: 'Nevada'),
      ItemDropperItem(value: 'nh', label: 'New Hampshire'),
      ItemDropperItem(value: 'nj', label: 'New Jersey'),
      ItemDropperItem(value: 'nm', label: 'New Mexico'),
      ItemDropperItem(value: 'ny', label: 'New York'),
      ItemDropperItem(value: 'nc', label: 'North Carolina'),
      ItemDropperItem(value: 'nd', label: 'North Dakota'),
      ItemDropperItem(value: 'oh', label: 'Ohio'),
      ItemDropperItem(value: 'ok', label: 'Oklahoma'),
      ItemDropperItem(value: 'or', label: 'Oregon'),
      ItemDropperItem(value: 'pa', label: 'Pennsylvania'),
      ItemDropperItem(value: 'ri', label: 'Rhode Island'),
      ItemDropperItem(value: 'sc', label: 'South Carolina'),
      ItemDropperItem(value: 'sd', label: 'South Dakota'),
      ItemDropperItem(value: 'tn', label: 'Tennessee'),
      ItemDropperItem(value: 'tx', label: 'Texas'),
      ItemDropperItem(value: 'ut', label: 'Utah'),
      ItemDropperItem(value: 'vt', label: 'Vermont'),
      ItemDropperItem(value: 'va', label: 'Virginia'),
      ItemDropperItem(value: 'wa', label: 'Washington'),
      ItemDropperItem(value: 'wv', label: 'West Virginia'),
      ItemDropperItem(value: 'wi', label: 'Wisconsin'),
      ItemDropperItem(value: 'wy', label: 'Wyoming'),
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
    
    // Dropdown 11: Deletable multi-select items (10 items, 5 deletable)
    deletableDemoBaseItems = const [
      ItemDropperItem(value: 'd1', label: 'Deletable 1', isDeletable: true),
      ItemDropperItem(value: 'd2', label: 'Deletable 2', isDeletable: true),
      ItemDropperItem(value: 'd3', label: 'Deletable 3', isDeletable: true),
      ItemDropperItem(value: 'd4', label: 'Deletable 4', isDeletable: true),
      ItemDropperItem(value: 'd5', label: 'Deletable 5', isDeletable: true),
      ItemDropperItem(value: 'k6', label: 'Keep 6'),
      ItemDropperItem(value: 'k7', label: 'Keep 7'),
      ItemDropperItem(value: 'k8', label: 'Keep 8'),
      ItemDropperItem(value: 'k9', label: 'Keep 9'),
      ItemDropperItem(value: 'k10', label: 'Keep 10'),
    ];
    deletableDemoItems = List.from(deletableDemoBaseItems);
    selectedDeletableDemoItems = [];
    
    // Dropdown 12: Per-item enabled/disabled demo (10 items, 5 initially disabled)
    disabledDemoBaseItems = const [
      ItemDropperItem(value: 'e1', label: 'Item 1', isEnabled: true),
      ItemDropperItem(value: 'e2', label: 'Item 2', isEnabled: false),
      ItemDropperItem(value: 'e3', label: 'Item 3', isEnabled: true),
      ItemDropperItem(value: 'e4', label: 'Item 4', isEnabled: false),
      ItemDropperItem(value: 'e5', label: 'Item 5', isEnabled: true),
      ItemDropperItem(value: 'e6', label: 'Item 6', isEnabled: false),
      ItemDropperItem(value: 'e7', label: 'Item 7', isEnabled: true),
      ItemDropperItem(value: 'e8', label: 'Item 8', isEnabled: false),
      ItemDropperItem(value: 'e9', label: 'Item 9', isEnabled: true),
      ItemDropperItem(value: 'e10', label: 'Item 10', isEnabled: false),
    ];
    disabledDemoItems = List.from(disabledDemoBaseItems);
    selectedDisabledDemoItem = null;

    // Dropdown 13: Font size testing
    fontSizeTestItems = [
      ItemDropperItem(value: 'y', label: 'y'),
      ItemDropperItem(value: 'j', label: 'j'),
      ItemDropperItem(value: 'g', label: 'g'),
      ItemDropperItem(value: '14', label: '14'),
      ItemDropperItem(value: '16', label: '16'),
      ItemDropperItem(value: '18', label: '18'),
      ItemDropperItem(value: '20', label: '20'),
    ];

    // Dropdown 14: Decoration customization testing
    decorationTestItems = const [
      ItemDropperItem(value: 'alpha', label: 'Alpha'),
      ItemDropperItem(value: 'beta', label: 'Beta'),
      ItemDropperItem(value: 'gamma', label: 'Gamma'),
      ItemDropperItem(value: 'delta', label: 'Delta'),
      ItemDropperItem(value: 'epsilon', label: 'Epsilon'),
      ItemDropperItem(value: 'zeta', label: 'Zeta'),
      ItemDropperItem(value: 'eta', label: 'Eta'),
      ItemDropperItem(value: 'theta', label: 'Theta'),
      ItemDropperItem(value: 'iota', label: 'Iota'),
      ItemDropperItem(value: 'kappa', label: 'Kappa'),
    ];

    // Initialize add-enabled dropdown with a few items
    addEnabledItems = const [
      ItemDropperItem(value: 'task1', label: 'Task 1'),
      ItemDropperItem(value: 'task2', label: 'Task 2'),
      ItemDropperItem(value: 'task3', label: 'Task 3'),
    ];
  }

  void _randomizeDisabledDemoItems() {
    final rand = math.Random();

    setState(() {
      disabledDemoItems = disabledDemoBaseItems
          .map(
            (item) => ItemDropperItem<String>(
              value: item.value,
              label: item.label,
              isGroupHeader: item.isGroupHeader,
              isDeletable: item.isDeletable,
              isEnabled: rand.nextBool(),
            ),
          )
          .toList();

      // Clear selection if the previously selected item is now disabled
      if (selectedDisabledDemoItem != null) {
        final match = disabledDemoItems.firstWhere(
          (i) => i.value == selectedDisabledDemoItem!.value,
          orElse: () => ItemDropperItem<String>(
              value: '', label: '', isEnabled: false),
        );
        if (match.value.isEmpty || !match.isEnabled) {
          selectedDisabledDemoItem = null;
        }
      }
    });
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
            constraints: const BoxConstraints(maxWidth: 2000),
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

                // Four-column layout
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

                          const SizedBox(height: 32),

                          // Dropdown 5: Multi-Select States
                          _buildMultiDropdownSection(
                            title: '5. Multi-Select States (50 items)',
                            description: 'Select multiple US states with chip-based display',
                            selectedValues: selectedStates.map((e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: states,
                              initiallySelected: selectedStates,
                              onChanged: (items) {
                                setState(() {
                                  selectedStates = items;
                                });
                              },
                              hintText: 'Select states...',
                              maxDropdownHeight: 250,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Second column: Dropdowns 6-9
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

                          const SizedBox(height: 32),

                          // Font size controls
                          Container(
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
                                const Text(
                                  'Font Size Controls',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Adjust font sizes for chips/fields and dropdown items',
                                  style: TextStyle(fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 16),

                                // Chip/Field Font Size Control
                                Row(
                                  children: [
                                    const Text('Chip/Field Font:'),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        setState(() {
                                          chipFieldFontSize =
                                              (chipFieldFontSize - 1).clamp(
                                                  8.0, 20.0);
                                        });
                                      },
                                    ),
                                    Text('${chipFieldFontSize.toInt()}'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        setState(() {
                                          chipFieldFontSize =
                                              (chipFieldFontSize + 1).clamp(
                                                  8.0, 20.0);
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Item Font Size Control
                                Row(
                                  children: [
                                    const Text('Item Font:'),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        setState(() {
                                          itemFontSize =
                                              (itemFontSize - 1).clamp(
                                                  8.0, 20.0);
                                        });
                                      },
                                    ),
                                    Text('${itemFontSize.toInt()}'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        setState(() {
                                          itemFontSize =
                                              (itemFontSize + 1).clamp(
                                                  8.0, 20.0);
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  'Current: Chip/Field = ${chipFieldFontSize
                                      .toInt()}pt, Items = ${itemFontSize
                                      .toInt()}pt',
                                  style: TextStyle(fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Dropdown 13: Font size testing
                          _buildMultiDropdownSection(
                            title: '13. Font Size Testing (10 items)',
                            description:
                            'Multi-select with 10 test items. Use controls above to adjust font sizes.',
                            selectedValues: selectedFontSizeTestItems.map((
                                e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: fontSizeTestItems,
                              initiallySelected: selectedFontSizeTestItems,
                              onChanged: (items) {
                                setState(() {
                                  selectedFontSizeTestItems = items;
                                });
                              },
                              hintText: 'Select font sizes...',
                              maxDropdownHeight: 250,
                              // Apply the dynamic font sizes
                              fieldTextStyle: TextStyle(
                                  fontSize: chipFieldFontSize),
                              popupTextStyle: TextStyle(fontSize: itemFontSize),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Third column: Dropdown 10-12
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox for enabling/disabling dropdown 10
                          Container(
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
                            child: Row(
                              children: [
                                Checkbox(
                                  value: dropdown10Enabled,
                                  onChanged: (value) {
                                    setState(() {
                                      dropdown10Enabled = value ?? true;
                                    });
                                  },
                                ),
                                const Text(
                                  'Enable Dropdown 10',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Dropdown 10
                          _buildDropdownSection(
                            title: '10. Test Dropdown',
                            description: 'Dropdown with enable/disable checkbox',
                            selectedValue: selectedDropdown10?.label,
                            dropdown: dropDown<String>(
                              width: 300,
                              listItems: fruits,
                              initiallySelected: selectedDropdown10,
                              onChanged: (item) {
                                setState(() {
                                  selectedDropdown10 = item;
                                });
                              },
                              hintText: 'Select a fruit...',
                              showKeyboard: true,
                              enabled: dropdown10Enabled,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Dropdown 11: Deletable items (multi-select)
                          _buildMultiDropdownSection(
                            title: '11. Deletable Items (Multi-Select)',
                            description:
                                'Right-click (desktop/web) or long-press (mobile) items with a trash icon to delete them.',
                            selectedValues: selectedDeletableDemoItems
                                .map((e) => e.label)
                                .join(', '),
                            dropdown: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                multiDropDown<String>(
                                  width: 500,
                                  listItems: deletableDemoItems,
                                  initiallySelected: selectedDeletableDemoItems,
                                  onChanged: (items) {
                                    setState(() {
                                      selectedDeletableDemoItems = items;
                                    });
                                  },
                                  hintText:
                                      'Select items (right-click/long-press to delete)...',
                                  maxDropdownHeight: 250,
                                  onDeleteItem: (item) {
                                    setState(() {
                                      deletableDemoItems = deletableDemoItems
                                          .where((i) => i.value != item.value)
                                          .toList();
                                      selectedDeletableDemoItems =
                                          selectedDeletableDemoItems
                                              .where((i) =>
                                                  i.value != item.value)
                                              .toList();
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        deletableDemoItems =
                                            List.from(deletableDemoBaseItems);
                                        selectedDeletableDemoItems = [];
                                      });
                                    },
                                    child: const Text('Refill items'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Dropdown 12: Per-item enabled/disabled demo (single select)
                          _buildDropdownSection(
                            title: '12. Disabled Items (Single Select)',
                            description:
                                'Some items are disabled (greyed out) and cannot be selected. Use the button to randomize which items are enabled.',
                            selectedValue: selectedDisabledDemoItem?.label,
                            dropdown: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                dropDown<String>(
                                  width: 400,
                                  listItems: disabledDemoItems,
                                  initiallySelected: selectedDisabledDemoItem,
                                  onChanged: (item) {
                                    setState(() {
                                      selectedDisabledDemoItem = item;
                                    });
                                  },
                                  hintText: 'Select an enabled item...',
                                  showKeyboard: true,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _randomizeDisabledDemoItems,
                                    child: const Text('Randomize enable/disable'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Fourth column: Decoration customization
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Decoration controls
                          Container(
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
                                const Text(
                                  'Decoration Controls',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),

                                // Field Border Color
                                const Text('Field Border Color:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildColorButton(
                                        Colors.grey, fieldBorderColor, (color) {
                                      setState(() => fieldBorderColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.blue, fieldBorderColor, (color) {
                                      setState(() => fieldBorderColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.green, fieldBorderColor, (
                                        color) {
                                      setState(() => fieldBorderColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.red, fieldBorderColor, (color) {
                                      setState(() => fieldBorderColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.orange, fieldBorderColor, (
                                        color) {
                                      setState(() => fieldBorderColor = color);
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Field Border Width
                                const Text('Field Border Width:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: fieldBorderWidth,
                                        min: 0,
                                        max: 5,
                                        divisions: 10,
                                        label: fieldBorderWidth.toStringAsFixed(
                                            1),
                                        onChanged: (value) {
                                          setState(() =>
                                          fieldBorderWidth = value);
                                        },
                                      ),
                                    ),
                                    Text('${fieldBorderWidth.toStringAsFixed(
                                        1)}px'),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Field Border Radius
                                const Text('Field Border Radius:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: fieldBorderRadius,
                                        min: 0,
                                        max: 20,
                                        divisions: 20,
                                        label: fieldBorderRadius
                                            .toStringAsFixed(0),
                                        onChanged: (value) {
                                          setState(() =>
                                          fieldBorderRadius = value);
                                        },
                                      ),
                                    ),
                                    Text('${fieldBorderRadius.toStringAsFixed(
                                        0)}px'),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Field Background Color
                                const Text('Field Background:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildColorButton(
                                        Colors.white, fieldBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      fieldBackgroundColor = color);
                                    }),
                                    _buildColorButton(Colors.grey.shade100,
                                        fieldBackgroundColor, (color) {
                                          setState(() =>
                                          fieldBackgroundColor = color);
                                        }),
                                    _buildColorButton(Colors.blue.shade50,
                                        fieldBackgroundColor, (color) {
                                          setState(() =>
                                          fieldBackgroundColor = color);
                                        }),
                                    _buildColorButton(Colors.green.shade50,
                                        fieldBackgroundColor, (color) {
                                          setState(() =>
                                          fieldBackgroundColor = color);
                                        }),
                                    _buildColorButton(Colors.amber.shade50,
                                        fieldBackgroundColor, (color) {
                                          setState(() =>
                                          fieldBackgroundColor = color);
                                        }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Divider(),
                                const SizedBox(height: 16),

                                // Chip Background Color
                                const Text('Chip Background:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildColorButton(
                                        Colors.blue, chipBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      chipBackgroundColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.green, chipBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      chipBackgroundColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.purple, chipBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      chipBackgroundColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.orange, chipBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      chipBackgroundColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.teal, chipBackgroundColor, (
                                        color) {
                                      setState(() =>
                                      chipBackgroundColor = color);
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Chip Text Color
                                const Text('Chip Text Color:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildColorButton(
                                        Colors.white, chipTextColor, (color) {
                                      setState(() => chipTextColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.black, chipTextColor, (color) {
                                      setState(() => chipTextColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.blue.shade900, chipTextColor, (
                                        color) {
                                      setState(() => chipTextColor = color);
                                    }),
                                    _buildColorButton(
                                        Colors.green.shade900, chipTextColor, (
                                        color) {
                                      setState(() => chipTextColor = color);
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Chip Border Radius
                                const Text('Chip Border Radius:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: chipBorderRadius,
                                        min: 0,
                                        max: 20,
                                        divisions: 20,
                                        label: chipBorderRadius.toStringAsFixed(
                                            0),
                                        onChanged: (value) {
                                          setState(() =>
                                          chipBorderRadius = value);
                                        },
                                      ),
                                    ),
                                    Text('${chipBorderRadius.toStringAsFixed(
                                        0)}px'),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Divider(),
                                const SizedBox(height: 16),

                                // Field/Chip Font Family
                                const Text('Field/Chip Font:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildFontButton(
                                        'Default', fieldFontFamily, (font) {
                                      setState(() => fieldFontFamily = font);
                                    }),
                                    _buildFontButton(
                                        'Courier', fieldFontFamily, (font) {
                                      setState(() => fieldFontFamily = font);
                                    }),
                                    _buildFontButton(
                                        'Times', fieldFontFamily, (font) {
                                      setState(() => fieldFontFamily = font);
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Item Font Family
                                const Text('Item Font:',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildFontButton(
                                        'Default', itemFontFamily, (font) {
                                      setState(() => itemFontFamily = font);
                                    }),
                                    _buildFontButton(
                                        'Courier', itemFontFamily, (font) {
                                      setState(() => itemFontFamily = font);
                                    }),
                                    _buildFontButton(
                                        'Times', itemFontFamily, (font) {
                                      setState(() => itemFontFamily = font);
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Dropdown 14: Decoration testing
                          _buildMultiDropdownSection(
                            title: '14. Decoration Testing (10 items)',
                            description:
                            'Multi-select with customizable field and chip decorations. Use controls above.',
                            selectedValues: selectedDecorationTestItems.map((
                                e) => e.label).join(', '),
                            dropdown: multiDropDown<String>(
                              width: 500,
                              listItems: decorationTestItems,
                              initiallySelected: selectedDecorationTestItems,
                              onChanged: (items) {
                                setState(() {
                                  selectedDecorationTestItems = items;
                                });
                              },
                              hintText: 'Select items...',
                              maxDropdownHeight: 250,
                              fieldDecoration: BoxDecoration(
                                color: fieldBackgroundColor,
                                border: Border.all(
                                  color: fieldBorderColor,
                                  width: fieldBorderWidth,
                                ),
                                borderRadius: BorderRadius.circular(
                                    fieldBorderRadius),
                              ),
                              selectedChipDecoration: BoxDecoration(
                                color: chipBackgroundColor,
                                borderRadius: BorderRadius.circular(
                                    chipBorderRadius),
                              ),
                              fieldTextStyle: TextStyle(
                                fontSize: 10,
                                // Use internal default for consistent sizing
                                color: chipTextColor,
                                fontFamily: fieldFontFamily == 'Default'
                                    ? null
                                    : fieldFontFamily,
                              ),
                              popupTextStyle: TextStyle(
                                // fontSize NOT specified - let default (10.0) apply
                                fontFamily: itemFontFamily == 'Default'
                                    ? null
                                    : itemFontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildColorButton(Color color, Color currentColor,
      Function(Color) onTap) {
    final bool isSelected = color == currentColor;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade400,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildFontButton(String fontName, String currentFont,
      Function(String) onTap) {
    final bool isSelected = fontName == currentFont;
    return GestureDetector(
      onTap: () => onTap(fontName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          fontName,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: fontName == 'Default' ? null : fontName,
          ),
        ),
      ),
    );
  }
}

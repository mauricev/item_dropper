import 'package:flutter/material.dart';
import 'package:item_dropper/item_dropper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Item Dropper Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  // Single-select state
  ItemDropperItem<String>? selectedFruit;

  // Multi-select state with pre-selected items
  List<ItemDropperItem<String>> selectedColors = [];

  // Fruit items for single-select
  final List<ItemDropperItem<String>> fruits = [
    ItemDropperItem(value: 'apple', label: 'Apple'),
    ItemDropperItem(value: 'banana', label: 'Banana'),
    ItemDropperItem(value: 'orange', label: 'Orange'),
    ItemDropperItem(value: 'grape', label: 'Grape'),
    ItemDropperItem(value: 'mango', label: 'Mango'),
    ItemDropperItem(value: 'strawberry', label: 'Strawberry'),
  ];

  // Color items for multi-select
  final List<ItemDropperItem<String>> colors = [
    ItemDropperItem(value: 'red', label: 'Red'),
    ItemDropperItem(value: 'blue', label: 'Blue'),
    ItemDropperItem(value: 'green', label: 'Green'),
    ItemDropperItem(value: 'yellow', label: 'Yellow'),
    ItemDropperItem(value: 'purple', label: 'Purple'),
    ItemDropperItem(value: 'orange', label: 'Orange'),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select some colors for the multi-select example
    selectedColors = [
      colors[0], // Red
      colors[2], // Green
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Dropper Example'),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Single-Select Example
              const Text(
                'Single-Select Dropdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your favorite fruit:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SingleItemDropper<String>(
                items: fruits,
                selectedItem: selectedFruit,
                width: 300,
                onChanged: (item) {
                  setState(() {
                    selectedFruit = item;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (selectedFruit != null)
                Text(
                  'You selected: ${selectedFruit!.label}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                  ),
                ),

              const SizedBox(height: 48),

              // Multi-Select Example
              const Text(
                'Multi-Select Dropdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your favorite colors (some pre-selected):',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              MultiItemDropper<String>(
                items: colors,
                selectedItems: selectedColors,
                width: 400,
                maxSelected: 4,
                // Limit to 4 selections
                onChanged: (items) {
                  setState(() {
                    selectedColors = items;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (selectedColors.isNotEmpty)
                Text(
                  'Selected: ${selectedColors.map((c) => c.label).join(", ")}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';

// Define the structure for dropdown items
class DropdownOption {
  final String value;
  final String display;

  DropdownOption({required this.value, required this.display});

  // Override equals and hashCode for proper comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropdownOption &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          display == other.display;

  @override
  int get hashCode => value.hashCode ^ display.hashCode;
}

// --- Main Dropdown Widget ---
class CustomSearchableDropdown extends StatefulWidget {
  final List<DropdownOption> items;
  final DropdownOption? selectedItem;
  final ValueChanged<DropdownOption?> onChanged;
  final String hintText;
  final String searchHintText;
  final InputDecoration? decoration;
  final double? dialogMaxHeight;
  final Widget? noResultsFoundWidget;
  final String? priorSearchContent; // Optional: Pre-fill search bar
  final VoidCallback?
  onClear; // Optional: Callback when clear button is pressed

  const CustomSearchableDropdown({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.hintText = 'Select Item',
    this.searchHintText = 'Search...',
    this.decoration,
    this.dialogMaxHeight = 300.0,
    this.noResultsFoundWidget,
    this.priorSearchContent,
    this.onClear, // Add onClear to constructor
  });

  @override
  State<CustomSearchableDropdown> createState() =>
      _CustomSearchableDropdownState();
}

class _CustomSearchableDropdownState extends State<CustomSearchableDropdown> {
  // Method to show the searchable list in a dialog
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _SearchableDialogContent(
          items: widget.items,
          selectedItem: widget.selectedItem,
          onChanged: widget.onChanged,
          hintText: widget.hintText,
          searchHintText: widget.searchHintText,
          dialogMaxHeight: widget.dialogMaxHeight,
          noResultsFoundWidget: widget.noResultsFoundWidget,
          priorSearchContent: widget.priorSearchContent, // Pass prior content
        );
      },
    );
  }

  // Method to handle clearing the selection
  void _clearSelection() {
    widget.onClear?.call(); // Call the external callback if provided
    widget.onChanged(null); // Clear the internal selection
  }

  @override
  Widget build(BuildContext context) {
    // Define default decoration if not provided
    final effectiveDecoration = (widget.decoration ??
            const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ))
        .applyDefaults(Theme.of(context).inputDecorationTheme);

    final bool hasSelection = widget.selectedItem != null;

    return InkWell(
      onTap: _showSearchDialog,
      child: InputDecorator(
        decoration: effectiveDecoration.copyWith(
          hintText: !hasSelection ? widget.hintText : null,
        ),
        isEmpty: !hasSelection,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Display selected item's text
            Expanded(
              child: Text(
                widget.selectedItem?.display ?? '',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            // Row for Clear and Dropdown icons
            Row(
              mainAxisSize: MainAxisSize.min, // Take only needed space
              children: [
                // Clear Button (Conditionally Visible)
                if (hasSelection)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    iconSize: 20, // Adjust size as needed
                    padding: EdgeInsets.zero, // Remove default padding
                    constraints:
                        const BoxConstraints(), // Remove default constraints
                    tooltip:
                        MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip, // Accessibility
                    onPressed: _clearSelection, // Call clear method
                  ),
                // Add spacing if clear button is visible
                if (hasSelection) const SizedBox(width: 4),
                // Dropdown Arrow Icon
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- StatefulWidget for Dialog Content ---
class _SearchableDialogContent extends StatefulWidget {
  final List<DropdownOption> items;
  final DropdownOption? selectedItem;
  final ValueChanged<DropdownOption?> onChanged;
  final String hintText; // Used for Dialog Title
  final String searchHintText;
  final double? dialogMaxHeight;
  final Widget? noResultsFoundWidget;
  final String? priorSearchContent; // Receive prior content

  const _SearchableDialogContent({
    required this.items,
    this.selectedItem,
    required this.onChanged,
    required this.hintText,
    required this.searchHintText,
    this.dialogMaxHeight,
    this.noResultsFoundWidget,
    this.priorSearchContent,
  });

  @override
  State<_SearchableDialogContent> createState() =>
      _SearchableDialogContentState();
}

class _SearchableDialogContentState extends State<_SearchableDialogContent> {
  late final TextEditingController _searchController;
  late List<DropdownOption> _filteredItems;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Initialize controller with prior content if available
    _searchController = TextEditingController(text: widget.priorSearchContent);
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
    // Initial filter if prior content exists
    if (widget.priorSearchContent != null &&
        widget.priorSearchContent!.isNotEmpty) {
      _filterItems();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _filterItems();
    });
  }

  void _filterItems() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems =
          query.isEmpty
              ? widget.items
              : widget.items
                  .where((item) => item.display.toLowerCase().contains(query))
                  .toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hintText),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 0.0,
        horizontal: 0.0,
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search TextField
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: TextField(
                  controller: _searchController, // Uses initialized controller
                  autofocus: true, // Still autofocus
                  decoration: InputDecoration(
                    hintText: widget.searchHintText,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixIconConstraints: const BoxConstraints(maxHeight: 30),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                  ),
                ),
              ),
              // List of items
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.dialogMaxHeight ?? 300.0,
                ),
                child:
                    _filteredItems.isEmpty
                        ? (widget.noResultsFoundWidget ??
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No results found'),
                              ),
                            ))
                        : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          shrinkWrap: true,
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final bool isSelected = widget.selectedItem == item;
                            return ListTile(
                              dense: true,
                              title: Text(item.display),
                              selected: isSelected,
                              selectedTileColor:
                                  Theme.of(context).primaryColorLight,
                              onTap: () {
                                widget.onChanged(item);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

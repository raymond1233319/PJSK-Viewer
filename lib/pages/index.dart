import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/lazy_load.dart';
import 'package:pjsk_viewer/utils/searchable_dropdown.dart';

/// A single dropdown filter's data/configuration
class FilterConfig<T> {
  final String header;
  final List<Map<String, String>> options;
  List<String> selectedValues = [];
  final bool Function(T item, List<String> selectedValues) filterFunc;
  bool isDropdown;
  bool isFullPath;
  bool blueMode;

  FilterConfig({
    required this.header,
    required this.options,
    required this.filterFunc,
    this.isDropdown = false,
    this.isFullPath = false,
    this.blueMode = false,
  });
}

/// A single sort option with title and function
class SortOption<T> {
  final String title;
  final String value;
  final int Function(T a, T b) sortFunction;

  SortOption({
    required this.title,
    required this.value,
    required this.sortFunction,
  });
}

class SortOptions {
  late final SortOption<Map<String, dynamic>> idAsc;
  late final SortOption<Map<String, dynamic>> releaseAtAsc;
  late final SortOption<Map<String, dynamic>> startAtAsc;
  late final SortOption<Map<String, dynamic>> publishedAtAsc;

  SortOptions(BuildContext context) {
    final localizations = ContentLocalizations.of(context)!;
    idAsc = SortOption(
      title: localizations.translate('common', 'id').translated,
      value: "id",
      sortFunction: createGenericSortFunction("id"),
    );
    releaseAtAsc = SortOption(
      title: localizations.translate('common', 'startAt').translated,
      value: "releaseAt",
      sortFunction: createGenericSortFunction("releaseAt"),
    );
    startAtAsc = SortOption(
      title: localizations.translate('common', 'startAt').translated,
      value: "startAt",
      sortFunction: createGenericSortFunction("startAt"),
    );
    publishedAtAsc = SortOption(
      title: localizations.translate('common', 'startAt').translated,
      value: "startAt",
      sortFunction: createGenericSortFunction("publishedAt"),
    );
  }
}

/// A single sort option configuration with multiple sort functions
class SortConfig<T> {
  final List<SortOption<T>> sortOptions;
  String selectedValue; // currently selected sort option value
  String selectedOrder; // currently selected order (asc/desc)

  SortConfig({
    required this.sortOptions,
    this.selectedValue = "id",
    this.selectedOrder = "desc",
  });

  /// Get current sort function based on selected value and order
  int Function(T a, T b)? get currentSortFunction {
    final sortOption = sortOptions.firstWhere(
      (option) => option.value == selectedValue,
      orElse:
          () =>
              sortOptions.isNotEmpty
                  ? sortOptions.first
                  : SortOption(title: '', value: '', sortFunction: (a, b) => 0),
    );

    final baseFunction = sortOption.sortFunction;

    // Apply order
    final isDesc = selectedOrder == 'desc';
    return isDesc ? (a, b) => baseFunction(b, a) : baseFunction;
  }
}

/// Generic sort function for Map<String, dynamic> entries
/// Takes the field name as parameter and returns a sort function
int Function(Map<String, dynamic>, Map<String, dynamic>)
createGenericSortFunction(String fieldName) {
  return (Map<String, dynamic> a, Map<String, dynamic> b) {
    final aValue = a[fieldName];
    final bValue = b[fieldName];

    // Handle null values
    if (aValue == null && bValue == null) return 0;
    if (aValue == null) return -1;
    if (bValue == null) return 1;

    // Handle different data types
    if (aValue is int && bValue is int) {
      return aValue.compareTo(bValue);
    } else if (aValue is String && bValue is String) {
      return aValue.compareTo(bValue);
    } else if (aValue is double && bValue is double) {
      return aValue.compareTo(bValue);
    } else {
      // Fallback to string comparison
      return aValue.toString().compareTo(bValue.toString());
    }
  };
}

class FilterOptions {
  late final List<Map<String, String>> unitOptions;
  late final List<Map<String, String>> unitOptionsWithoutOther;
  late final List<Map<String, String>> characterOptions;
  late final List<Map<String, String>> attributeOptions;
  late final List<Map<String, String>> rarityOptions;
  late final List<Map<String, String>> cardTypeOptions;
  late final List<Map<String, String>> eventTypeOptions;
  late final List<Map<String, String>> songTags;
  late final List<Map<String, String>> mvTypeOptions;
  late final List<Map<String, String>> gachatypeOptions;
  late final List<Map<String, String>> cardSkillTypeOptions;

  FilterOptions(BuildContext context) {
    final localizations = ContentLocalizations.of(context)!;
    final appLocalizations = AppLocalizations.of(context);
    final unitIconAssetPath = 'assets/common/logo_mini/unit_ts_';
    unitOptions = [
      {'value': 'light_sound', 'assetPath': unitIconAssetPath},
      {'value': 'idol', 'assetPath': unitIconAssetPath},
      {'value': 'street', 'assetPath': unitIconAssetPath},
      {'value': 'theme_park', 'assetPath': unitIconAssetPath},
      {'value': 'school_refusal', 'assetPath': unitIconAssetPath},
      {'value': 'piapro', 'assetPath': unitIconAssetPath},
      {'display': appLocalizations.translate('mixed'), 'value': 'none'},
    ];
    unitOptionsWithoutOther =
        unitOptions.where((opt) => opt['value'] != 'none').toList();
    characterOptions = List.generate(
      26,
      (index) => {
        'display': '${index + 1}',
        'value': '${index + 1}',
        'assetPath': 'assets/chara_icons/chr_ts_',
      },
    );
    attributeOptions = [
      {'value': 'pure', 'assetPath': 'assets/icon_attribute_'},
      {'value': 'cool', 'assetPath': 'assets/icon_attribute_'},
      {'value': 'happy', 'assetPath': 'assets/icon_attribute_'},
      {'value': 'mysterious', 'assetPath': 'assets/icon_attribute_'},
      {'value': 'cute', 'assetPath': 'assets/icon_attribute_'},
    ];
    rarityOptions = [
      {'display': '1', 'value': 'rarity_1', 'assetPath': 'assets/'},
      {'display': '2', 'value': 'rarity_2', 'assetPath': 'assets/'},
      {'display': '3', 'value': 'rarity_3', 'assetPath': 'assets/'},
      {'display': '4', 'value': 'rarity_4', 'assetPath': 'assets/'},
      {'display': 'bd', 'value': 'rarity_birthday', 'assetPath': 'assets/'},
    ];

    cardTypeOptions = [
      {'display': appLocalizations.translate('normal'), 'value': 'normal'},
      {
        'display': appLocalizations.translate('term_limited'),
        'value': 'term_limited',
      },
      {'display': appLocalizations.translate('birthday'), 'value': 'birthday'},
      {
        'display': appLocalizations.translate('colorful_festival_limited'),
        'value': 'colorful_festival_limited',
      },
      {
        'display': appLocalizations.translate('bloom_festival_limited'),
        'value': 'bloom_festival_limited',
      },
      {
        'display': appLocalizations.translate('unit_event_limited'),
        'value': 'unit_event_limited',
      },
      {
        'display': appLocalizations.translate('collaboration_limited'),
        'value': 'collaboration_limited',
      },
    ];
    eventTypeOptions = [
      {
        'display':
            localizations
                .translate('event', 'type', innerKey: 'marathon')
                .translated,
        'value': 'marathon',
      },
      {
        'display':
            localizations
                .translate('event', 'type', innerKey: 'cheerful_carnival')
                .translated,
        'value': 'cheerful_carnival',
      },
      {
        'display':
            localizations
                .translate('event', 'type', innerKey: 'world_bloom')
                .translated,
        'value': 'world_bloom',
      },
    ];

    songTags = [
      {
        'value': 'light_music_club',
        'assetPath': 'assets/common/logo_mini/unit_ts_',
      },
      {'value': 'idol', 'assetPath': unitIconAssetPath},
      {'value': 'street', 'assetPath': unitIconAssetPath},
      {'value': 'theme_park', 'assetPath': unitIconAssetPath},
      {'value': 'school_refusal', 'assetPath': unitIconAssetPath},
      {'value': 'vocaloid', 'assetPath': unitIconAssetPath},
      {'display': appLocalizations.translate('other'), 'value': 'other'},
    ];

    mvTypeOptions = [
      {
        'display':
            localizations
                .translate('music', 'categoryType', innerKey: 'mv')
                .translated,
        'value': 'mv',
      },
      {
        'display':
            localizations
                .translate('music', 'categoryType', innerKey: 'mv_2d')
                .translated,
        'value': 'mv_2d',
      },
      {
        'display':
            localizations
                .translate('music', 'categoryType', innerKey: 'original')
                .translated,
        'value': 'original',
      },
      {
        'display':
            localizations
                .translate('music', 'categoryType', innerKey: 'image')
                .translated,
        'value': 'image',
      },
    ];

    gachatypeOptions = [
      {
        'display': appLocalizations.translate('gacha_ordinary'),
        'value': 'ordinary',
      },
      {
        'display': appLocalizations.translate('gacha_limited'),
        'value': 'limited',
      },
      {
        'display': appLocalizations.translate('gacha_festival'),
        'value': 'festival',
      },
      {
        'display': appLocalizations.translate('gacha_normal'),
        'value': 'normal',
      },
      {
        'display': appLocalizations.translate('gacha_beginner'),
        'value': 'beginner',
      },
      {'display': appLocalizations.translate('gacha_gift'), 'value': 'gift'},
    ];

    cardSkillTypeOptions = [
      {
        'display':
            localizations
                .translate('filter', 'skill', innerKey: 'score_up')
                .translated,
        'value': 'score_up',
      },
      {
        'display':
            localizations
                .translate('filter', 'skill', innerKey: 'judgment_up')
                .translated,
        'value': 'judgment_up',
      },
      {
        'display':
            localizations
                .translate('filter', 'skill', innerKey: 'life_recovery')
                .translated,
        'value': 'life_recovery',
      },
      {
        'display':
            localizations
                .translate('filter', 'skill', innerKey: 'perfect_score_up')
                .translated,
        'value': 'perfect_score_up',
      },
      {
        'display':
            localizations
                .translate('filter', 'skill', innerKey: 'life_score_up')
                .translated,
        'value': 'life_score_up',
      },
      {
        'display': appLocalizations.translate('score_up_keep'),
        'value': 'score_up_keep',
      },
      {
        'display': appLocalizations.translate('sub_unit_score_up'),
        'value': 'sub_unit_score_up',
      },
      {
        'display': appLocalizations.translate('score_up_character_rank'),
        'value': 'score_up_character_rank',
      },
      {
        'display': appLocalizations.translate(
          'other_member_score_up_reference_rate',
        ),
        'value': 'other_member_score_up_reference_rate',
      },
      {
        'display': appLocalizations.translate('score_up_unit_count'),
        'value': 'score_up_unit_count',
      },
    ];
  }
}

class FilterBottomSheet<T> extends StatelessWidget {
  final List<FilterConfig<T>> filters;
  final SortConfig<T>? sortConfig;
  final VoidCallback onApply;

  const FilterBottomSheet({
    super.key,
    required this.filters,
    this.sortConfig,
    required this.onApply,
  });

  /// Build a single filter option widget
  Widget _buildOption<U>(
    context,
    Map<String, String> option,
    FilterConfig<U> filter,
  ) {
    final val = option['value']!;
    final path = option['assetPath'] ?? '';
    final isSelected = filter.selectedValues.contains(val);

    // if assetPath is not empty, use it to display the image
    Widget displayWidget;

    if (path.isNotEmpty) {
      displayWidget =
          filter.isFullPath
              ? Image.asset(path, height: 24)
              : Image.asset('$path$val.png', height: 24);
    } else {
      displayWidget = Text(option['display'] ?? '');
    }
    Color isSelectedColour;
    Color isNotSelectedColour;
    if (filter.blueMode) {
      isSelectedColour = Colors.blue;
      isNotSelectedColour = Colors.blueGrey.shade300;
    } else {
      isSelectedColour = Colors.grey;
      isNotSelectedColour = Colors.transparent;
    }

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          filter.selectedValues.remove(val);
        } else {
          filter.selectedValues.add(val);
        }
        (context as Element).markNeedsBuild();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? isSelectedColour : isNotSelectedColour,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: displayWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        // Main column for the bottom sheet layout
        mainAxisSize: MainAxisSize.min, // Take minimum vertical space
        children: [
          // --- Scrollable Filter Options ---
          Expanded(
            // Make the filter options section expand and scroll
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align headers to the left
                children: [
                  // --- Sort Options ---
                  if (sortConfig != null) ...[
                    Text(
                      localizations
                              ?.translate('filter', 'sort', innerKey: 'caption')
                              .translated ??
                          'Sort',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          // Direction dropdown (Asc/Desc)
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: sortConfig!.selectedOrder,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'asc',
                                  child: Text(
                                    localizations
                                            ?.translate(
                                              'filter',
                                              'sort',
                                              innerKey: 'ascending',
                                            )
                                            .translated ??
                                        'Asc',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'desc',
                                  child: Text(
                                    localizations
                                            ?.translate(
                                              'filter',
                                              'sort',
                                              innerKey: 'descending',
                                            )
                                            .translated ??
                                        'Desc',
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  sortConfig!.selectedOrder = value;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sort field dropdown
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: sortConfig!.selectedValue,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items:
                                  sortConfig!.sortOptions.map((sortOption) {
                                    return DropdownMenuItem(
                                      value: sortOption.value,
                                      child: Text(sortOption.title),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                sortConfig!.selectedValue = value;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                  ],

                  // --- Filter Options ---
                  for (var filter in filters) ...[
                    Text(filter.header),
                    const SizedBox(height: 8),
                    // if dropdown mode, render a Dropdown Menu
                    if (filter.isDropdown)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: CustomSearchableDropdown(
                          // Convert filter options from List<Map<String, String>> to List<DropdownOption>
                          items:
                              filter.options.map((option) {
                                return DropdownOption(
                                  value: option['value']!,
                                  // Use display text, fall back to value if display is missing
                                  display:
                                      option['display'] ?? option['value']!,
                                );
                              }).toList(),

                          // Determine the currently selected DropdownOption based on filter.selectedValues
                          selectedItem:
                              filter.selectedValues.isNotEmpty
                                  ? DropdownOption(
                                    value: filter.selectedValues.first,
                                    // Find the display text matching the selected value
                                    display:
                                        filter.options.firstWhere(
                                          (opt) =>
                                              opt['value'] ==
                                              filter.selectedValues.first,
                                          // Provide a fallback if the selected value isn't in options (shouldn't happen ideally)
                                          orElse:
                                              () => {
                                                'display':
                                                    filter.selectedValues.first,
                                              },
                                        )['display'] ??
                                        filter
                                            .selectedValues
                                            .first, // Fallback display
                                  )
                                  : null,

                          // Update filter.selectedValues when a new option is chosen
                          onChanged: (DropdownOption? selectedOption) {
                            if (selectedOption != null) {
                              filter.selectedValues
                                ..clear()
                                ..add(selectedOption.value);
                            }
                            (context as Element).markNeedsBuild();
                          },

                          // Set hints using the filter header
                          hintText: filter.header,
                          searchHintText: "",
                          priorSearchContent:
                              filter.selectedValues.firstOrNull
                                  ?.split(':')
                                  .last,
                          onClear: () => filter.selectedValues.clear(),
                        ),
                      )
                    // if not dropdown mode, render a grid
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children:
                              filter.options
                                  .map(
                                    (option) =>
                                        _buildOption(context, option, filter),
                                  )
                                  .toList(),
                        ),
                      ),
                    const Divider(),
                  ],
                ],
              ),
            ),
          ),

          // --- Action Buttons ---
          Padding(
            // Add padding around the buttons
            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // reset button
                TextButton(
                  onPressed: () {
                    // clear all selections including sort
                    for (var f in filters) {
                      f.selectedValues.clear();
                    }
                    // Reset sort to default (ID descending)
                    if (sortConfig != null &&
                        sortConfig!.sortOptions.isNotEmpty) {
                      sortConfig!.selectedValue =
                          sortConfig!.sortOptions.first.value;
                      sortConfig!.selectedOrder = 'desc';
                    }
                    // rebuild the sheet
                    (context as Element).markNeedsBuild();
                  },
                  child: Text(
                    localizations?.translate('common', 'reset').translated ??
                        "Reset",
                  ),
                ),
                const SizedBox(width: 8),

                // apply button
                ElevatedButton(
                  onPressed: onApply,
                  child: Text(
                    localizations?.translate('common', 'apply').translated ??
                        "Apply",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic index page:
///  • optional search (via searchPredicate)
///  • any number of dropdown filters (via FilterConfig.filterFunc)
///  • multiple optional sort options (via sortOptions)
///  • paginated list via LazyLoadUtility
class IndexPage<T> extends StatefulWidget {
  final String title;

  // full un‐filtered list of items
  final List<T> allItems;

  // search bar
  final bool showSearch;
  final bool Function(T item, String query) searchPredicate;

  // zero or more dropdown filters
  final List<FilterConfig<T>> filters;

  // sort configuration
  final SortConfig<T>? sortConfig;

  // pagination
  final int pageSize;
  final int itemsPerRow;
  final ScrollController scrollController;
  final Widget Function(BuildContext, T) itemBuilder;

  final List<Widget>? appBarActions;
  final String? appBarSwitchText;
  final FocusNode searchFocusNode;

  const IndexPage({
    super.key,
    required this.title,
    required this.allItems,
    this.showSearch = false,
    required this.searchPredicate,
    this.filters = const [],
    this.sortConfig,
    this.pageSize = 10,
    required this.scrollController,
    required this.itemBuilder,
    this.appBarActions,
    this.appBarSwitchText,
    this.itemsPerRow = 1,
    required this.searchFocusNode,
  });

  @override
  State<IndexPage<T>> createState() => _IndexPageState<T>();
}

class _IndexPageState<T> extends State<IndexPage<T>> {
  late LazyLoadUtility<T> _lazyLoad;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sortedItems = List<T>.from(widget.allItems);

    _lazyLoad = LazyLoadUtility<T>(
      pageSize: widget.pageSize,
      scrollController: widget.scrollController,
      allItems: sortedItems,
      filteredItems: [],
      onLoadMoreStarted: () => setState(() {}),
      onLoadMoreFinished: () => setState(() {}),
    );
    applyFilters();
  }

  void applyFilters() {
    // start from full list and apply filters
    var filtered =
        widget.allItems.where((item) {
          // search
          if (widget.showSearch &&
              _searchQuery.isNotEmpty &&
              !widget.searchPredicate(item, _searchQuery)) {
            return false;
          }
          // each dropdown filter
          for (var filter in widget.filters) {
            if (filter.selectedValues.isNotEmpty &&
                !filter.filterFunc(item, filter.selectedValues)) {
              return false;
            }
          }
          return true;
        }).toList();

    // Apply sorting
    if (widget.sortConfig != null) {
      final sortConfig = widget.sortConfig!;
      // Use currentSortFunction
      final currentFunction = sortConfig.currentSortFunction;
      if (currentFunction != null) {
        filtered.sort(currentFunction);
      }
    } else {
      // Default sort by descending ID
      filtered.sort((a, b) {
        final ai = (a as Map<String, dynamic>)['id'] as int;
        final bi = (b as Map<String, dynamic>)['id'] as int;
        return bi.compareTo(ai); // Descending order
      });
    }

    setState(() {
      _lazyLoad.updateFilteredItems(filtered);
      // scroll back to top
      if (widget.scrollController.hasClients) {
        widget.scrollController.jumpTo(0);
      }
    });
  }

  Widget builder(context, idx) {
    if (_lazyLoad.isLoadingIndicator(idx)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.itemBuilder(context, _lazyLoad.filteredItems[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        // Title
        title: Text(widget.title),

        // Actions
        actions: [
          if (widget.appBarSwitchText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Builder(
                builder: (context) {
                  final width = MediaQuery.of(context).size.width * 0.2;
                  return SizedBox(
                    width: width,
                    child: Text(
                      widget.appBarSwitchText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        // if text is long, reduce font size
                        fontSize:
                            widget.appBarSwitchText!.length > 10 ? 11 : 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (widget.appBarActions != null) ...widget.appBarActions!,
        ],

        bottom:
            (widget.showSearch ||
                    widget.filters.isNotEmpty ||
                    widget.sortConfig != null)
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // Search bar
                        if (widget.showSearch) ...[
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: widget.searchFocusNode,
                              onChanged: (q) {
                                _searchQuery = q;
                                applyFilters();
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText:
                                    localizations
                                        ?.translate('common', 'title')
                                        .translated ??
                                    'Title',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // filters and sort
                        if (widget.filters.isNotEmpty ||
                            widget.sortConfig != null)
                          IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder:
                                    (modalContext) => SizedBox(
                                      height:
                                          MediaQuery.of(
                                            modalContext,
                                          ).size.height *
                                          0.7,
                                      child: FilterBottomSheet<T>(
                                        filters: widget.filters,
                                        sortConfig: widget.sortConfig,
                                        onApply: () {
                                          applyFilters();
                                          Navigator.pop(modalContext);
                                        },
                                      ),
                                    ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                )
                : null,
      ),

      // Items list
      body:
          _lazyLoad.filteredItems.isEmpty
              ? Center(
                child: Text(
                  AppLocalizations.of(context).translate('no_items_found'),
                ),
              )
              : widget.itemsPerRow > 1
              ? GridView.builder(
                controller: widget.scrollController,
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.itemsPerRow,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 0.7,
                ),
                itemCount: _lazyLoad.itemCount,
                itemBuilder: builder,
              )
              : ListView.builder(
                controller: widget.scrollController,
                itemCount: _lazyLoad.itemCount,
                itemBuilder: builder,
              ),
    );
  }

  @override
  void dispose() {
    _lazyLoad.dispose();
    super.dispose();
  }
}

/// A generic index‐item builder:
/// • `top` widget (e.g. image) displayed at top
/// • `title` / `subtitle` below
/// • taps navigate via `pageBuilder`
Widget buildIndexItem<T>({
  required BuildContext context,
  required T id,
  required Widget top,
  required String title,
  String subtitle = '',
  required Widget Function(T id) pageBuilder,
  double? aspectRatio,
  required FocusNode searchFocusNode,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              searchFocusNode.unfocus();
              navigateToDetailPage<T>(
                context: context,
                id: id,
                pageBuilder: pageBuilder,
              );
            },
            child:
                aspectRatio != null
                    ? AspectRatio(aspectRatio: aspectRatio, child: top)
                    : top,
          ),
          ListTile(
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              searchFocusNode.unfocus();
              navigateToDetailPage<T>(
                context: context,
                id: id,
                pageBuilder: pageBuilder,
              );
            },
          ),
        ],
      ),
    ),
  );
}

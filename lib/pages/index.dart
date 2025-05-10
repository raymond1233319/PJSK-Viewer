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
        'display':
            appLocalizations.translate('score_up_keep'),
        'value': 'score_up_keep',
      },
      {
        'display':
            appLocalizations.translate('sub_unit_score_up'),
        'value': 'sub_unit_score_up',
      },
      {
        'display':
            appLocalizations.translate('score_up_character_rank'),
        'value': 'score_up_character_rank',
      },
      {
        'display':
            appLocalizations.translate('other_member_score_up_reference_rate'),
        'value': 'other_member_score_up_reference_rate',
      },
      {
        'display':
            appLocalizations.translate('score_up_unit_count'),
        'value': 'score_up_unit_count',
      },
    ];
  }
}

class FilterBottomSheet<T> extends StatelessWidget {
  final List<FilterConfig<T>> filters;
  final VoidCallback onApply;

  const FilterBottomSheet({
    super.key,
    required this.filters,
    required this.onApply,
  });

  /// Build a single filter option widget
  Widget _buildOption<T>(
    context,
    Map<String, String> option,
    FilterConfig<T> filter,
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
          developer.log('Removing $val from ${filter.header}');
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

  /// Build the filter options
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
                    // clear all selections
                    for (var f in filters) {
                      f.selectedValues.clear();
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
  // pagination
  final int pageSize;
  final int itemsPerRow;
  final ScrollController scrollController;
  final Widget Function(BuildContext, T) itemBuilder;

  final List<Widget>? appBarActions;
  final String? appBarSwitchText;

  const IndexPage({
    super.key,
    required this.title,
    required this.allItems,
    this.showSearch = false,
    required this.searchPredicate,
    this.filters = const [],
    this.pageSize = 10,
    required this.scrollController,
    required this.itemBuilder,
    this.appBarActions,
    this.appBarSwitchText,
    this.itemsPerRow = 1,
  });

  @override
  State<IndexPage<T>> createState() => _IndexPageState<T>();
}

class _IndexPageState<T> extends State<IndexPage<T>> {
  late LazyLoadUtility<T> _lazyLoad;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final sortedItems = List<T>.from(widget.allItems)..sort((a, b) {
      final ai = (a as Map<String, dynamic>)['id'] as int;
      final bi = (b as Map<String, dynamic>)['id'] as int;
      return ai.compareTo(bi);
    });
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
    // start from full list
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
            (widget.showSearch || widget.filters.isNotEmpty)
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
                              onChanged: (q) {
                                _searchQuery = q;
                                applyFilters();
                              },
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

                        // filters
                        if (widget.filters.isNotEmpty)
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
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap:
                () => navigateToDetailPage<T>(
                  context: context,
                  id: id,
                  pageBuilder: pageBuilder,
                ),
            child:
                aspectRatio != null
                    ? AspectRatio(aspectRatio: aspectRatio, child: top)
                    : top,
          ),
          ListTile(
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap:
                () => navigateToDetailPage<T>(
                  context: context,
                  id: id,
                  pageBuilder: pageBuilder,
                ),
          ),
        ],
      ),
    ),
  );
}

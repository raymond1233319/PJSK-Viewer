import 'package:flutter/material.dart';
import 'package:pjsk_viewer/pages/image_view.dart';

class MultiImageOption {
  final String label;
  final String? imageUrl;
  final Widget? icon;

  MultiImageOption({required this.label, this.imageUrl, this.icon});
}

/// A generic selector that can display any number of tabs (labels/icons)
/// and show the corresponding content (e.g. network image) below.
/// 
class MultiImageSelector extends StatefulWidget {
  final List<MultiImageOption> options;
  final EdgeInsetsGeometry padding;
  final BoxConstraints buttonConstraints;
  final BorderRadius borderRadius;
  final int startPosition;

  const MultiImageSelector({
    super.key,
    required this.options,
    this.startPosition = 0,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.buttonConstraints = const BoxConstraints(minWidth: 100, minHeight: 40),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<MultiImageSelector> createState() => _MultiImageSelectorState();
}



class _MultiImageSelectorState extends State<MultiImageSelector> {
  late int _selectedIndex;
  late List<bool> _isSelected;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.startPosition.clamp(0, widget.options.length - 1);
    _isSelected = List.generate(
      widget.options.length,
      (i) => i == _selectedIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.options[_selectedIndex];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: widget.padding,
              child: Center(
                child: ToggleButtons(
                  isSelected: _isSelected,
                  borderRadius: widget.borderRadius,
                  constraints: BoxConstraints(
                    minHeight: widget.buttonConstraints.minHeight,
                  ),
                  onPressed: (int index) {
                    setState(() {
                      _selectedIndex = index;
                      for (int i = 0; i < _isSelected.length; i++) {
                        _isSelected[i] = i == index;
                      }
                    });
                  },
                  children:
                      widget.options.map((opt) {
                        if (opt.icon != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: opt.icon!,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(opt.label),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            buildHeroImageViewer(context, option.imageUrl),
          ],
        ),
      ),
    );
  }
}

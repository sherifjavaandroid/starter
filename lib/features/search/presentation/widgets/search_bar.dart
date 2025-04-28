import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../bloc/search_bloc.dart';

class SearchBarWidget extends StatefulWidget {
  final Function(String) onSearch;
  final Function(String)? onQueryChanged;
  final String? initialQuery;

  const SearchBarWidget({
    Key? key,
    required this.onSearch,
    this.onQueryChanged,
    this.initialQuery,
  }) : super(key: key);

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _showClearButton = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _showClearButton = _controller.text.isNotEmpty;
    });

    if (widget.onQueryChanged != null) {
      widget.onQueryChanged!(_controller.text);
    }
  }

  void _onSubmitted(String value) {
    final sanitizedValue = InputSanitizer.sanitizeText(value);
    if (sanitizedValue.isNotEmpty) {
      widget.onSearch(sanitizedValue);
      _focusNode.unfocus();
    }
  }

  void _onClearPressed() {
    _controller.clear();
    setState(() {
      _showClearButton = false;
    });

    if (widget.onQueryChanged != null) {
      widget.onQueryChanged!('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search photos...',
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: _onSubmitted,
            ),
          ),
          if (_showClearButton)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: _onClearPressed,
              color: Colors.grey,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// Search Suggestions Widget
class SearchSuggestionsWidget extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;

  const SearchSuggestionsWidget({
    Key? key,
    required this.suggestions,
    required this.onSuggestionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            leading: const Icon(Icons.history, size: 20),
            title: Text(suggestion),
            onTap: () => onSuggestionSelected(suggestion),
          );
        },
      ),
    );
  }
}

// Advanced Search Bar with Suggestions
class AdvancedSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final String? initialQuery;

  const AdvancedSearchBar({
    Key? key,
    required this.onSearch,
    this.initialQuery,
  }) : super(key: key);

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (prev, curr) => curr is SearchSuggestionsLoaded,
            builder: (context, state) {
              if (state is SearchSuggestionsLoaded) {
                return SearchSuggestionsWidget(
                  suggestions: state.suggestions,
                  onSuggestionSelected: (suggestion) {
                    _controller.text = suggestion;
                    widget.onSearch(suggestion);
                    _focusNode.unfocus();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SearchBarWidget(
        onSearch: widget.onSearch,
        onQueryChanged: (query) {
          if (query.isNotEmpty) {
            context.read<SearchBloc>().add(GetSearchSuggestionsEvent(query: query));
          }
        },
        initialQuery: widget.initialQuery,
      ),
    );
  }
}
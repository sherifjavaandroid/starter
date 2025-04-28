import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search_bloc.dart';

class FilterWidget extends StatelessWidget {
  const FilterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (prev, curr) => curr is SearchSuccess || curr is SearchInitial,
      builder: (context, state) {
        final currentFilters = state is SearchSuccess ? state.filters : <String, dynamic>{};

        return Container(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _FilterChip(
                label: 'Sort By',
                value: currentFilters['orderBy'] as String?,
                icon: Icons.sort,
                onTap: () => _showSortOptions(context, currentFilters),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Color',
                value: currentFilters['color'] as String?,
                icon: Icons.color_lens,
                onTap: () => _showColorOptions(context, currentFilters),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Orientation',
                value: currentFilters['orientation'] as String?,
                icon: Icons.crop_rotate,
                onTap: () => _showOrientationOptions(context, currentFilters),
              ),
              if (currentFilters.isNotEmpty) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('Clear All'),
                  onPressed: () {
                    context.read<SearchBloc>().add(ApplyFiltersEvent(filters: {}));
                  },
                  backgroundColor: Colors.red[50],
                  labelStyle: TextStyle(color: Colors.red[700]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context, Map<String, dynamic> currentFilters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ColorOptionsSheet(
        currentValue: currentFilters['color'] as String?,
        onSelected: (value) {
          final newFilters = {...currentFilters, 'color': value};
          context.read<SearchBloc>().add(ApplyFiltersEvent(filters: newFilters));
        },
      ),
    );
  }

  void _showOrientationOptions(BuildContext context, Map<String, dynamic> currentFilters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _OrientationOptionsSheet(
        currentValue: currentFilters['orientation'] as String?,
        onSelected: (value) {
          final newFilters = {...currentFilters, 'orientation': value};
          context.read<SearchBloc>().add(ApplyFiltersEvent(filters: newFilters));
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterChip({
    Key? key,
    required this.label,
    this.value,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return ActionChip(
      backgroundColor: hasValue ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: hasValue ? Theme.of(context).primaryColor : null,
          ),
          const SizedBox(width: 4),
          Text(
            value ?? label,
            style: TextStyle(
              color: hasValue ? Theme.of(context).primaryColor : null,
              fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      onPressed: onTap,
    );
  }
}

class _SortOptionsSheet extends StatelessWidget {
  final String? currentValue;
  final Function(String?) onSelected;

  const _SortOptionsSheet({
    Key? key,
    this.currentValue,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          _OptionTile(
            title: 'Relevant',
            value: 'relevant',
            groupValue: currentValue,
            onTap: () {
              onSelected('relevant');
              Navigator.pop(context);
            },
          ),
          _OptionTile(
            title: 'Latest',
            value: 'latest',
            groupValue: currentValue,
            onTap: () {
              onSelected('latest');
              Navigator.pop(context);
            },
          ),
          _OptionTile(
            title: 'Popular',
            value: 'popular',
            groupValue: currentValue,
            onTap: () {
              onSelected('popular');
              Navigator.pop(context);
            },
          ),
          if (currentValue != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text('Clear'),
              textColor: Colors.red,
              onTap: () {
                onSelected(null);
                Navigator.pop(context);
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ColorOptionsSheet extends StatelessWidget {
  final String? currentValue;
  final Function(String?) onSelected;

  const _ColorOptionsSheet({
    Key? key,
    this.currentValue,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Color',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _ColorOption(
                color: Colors.black,
                label: 'Black',
                value: 'black',
                isSelected: currentValue == 'black',
                onTap: () {
                  onSelected('black');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.white,
                label: 'White',
                value: 'white',
                isSelected: currentValue == 'white',
                onTap: () {
                  onSelected('white');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.yellow,
                label: 'Yellow',
                value: 'yellow',
                isSelected: currentValue == 'yellow',
                onTap: () {
                  onSelected('yellow');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.orange,
                label: 'Orange',
                value: 'orange',
                isSelected: currentValue == 'orange',
                onTap: () {
                  onSelected('orange');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.red,
                label: 'Red',
                value: 'red',
                isSelected: currentValue == 'red',
                onTap: () {
                  onSelected('red');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.purple,
                label: 'Purple',
                value: 'purple',
                isSelected: currentValue == 'purple',
                onTap: () {
                  onSelected('purple');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.blue,
                label: 'Blue',
                value: 'blue',
                isSelected: currentValue == 'blue',
                onTap: () {
                  onSelected('blue');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.green,
                label: 'Green',
                value: 'green',
                isSelected: currentValue == 'green',
                onTap: () {
                  onSelected('green');
                  Navigator.pop(context);
                },
              ),
              _ColorOption(
                color: Colors.teal,
                label: 'Teal',
                value: 'teal',
                isSelected: currentValue == 'teal',
                onTap: () {
                  onSelected('teal');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          if (currentValue != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text('Clear'),
              textColor: Colors.red,
              onTap: () {
                onSelected(null);
                Navigator.pop(context);
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OrientationOptionsSheet extends StatelessWidget {
  final String? currentValue;
  final Function(String?) onSelected;

  const _OrientationOptionsSheet({
    Key? key,
    this.currentValue,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Orientation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          _OptionTile(
            title: 'Landscape',
            value: 'landscape',
            groupValue: currentValue,
            icon: Icons.crop_landscape,
            onTap: () {
              onSelected('landscape');
              Navigator.pop(context);
            },
          ),
          _OptionTile(
            title: 'Portrait',
            value: 'portrait',
            groupValue: currentValue,
            icon: Icons.crop_portrait,
            onTap: () {
              onSelected('portrait');
              Navigator.pop(context);
            },
          ),
          _OptionTile(
            title: 'Square',
            value: 'squarish',
            groupValue: currentValue,
            icon: Icons.crop_square,
            onTap: () {
              onSelected('squarish');
              Navigator.pop(context);
            },
          ),
          if (currentValue != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text('Clear'),
              textColor: Colors.red,
              onTap: () {
                onSelected(null);
                Navigator.pop(context);
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String value;
  final String? groupValue;
  final VoidCallback onTap;
  final IconData? icon;

  const _OptionTile({
    Key? key,
    required this.title,
    required this.value,
    this.groupValue,
    required this.onTap,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    Key? key,
    required this.color,
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
} const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
),
builder: (context) => _SortOptionsSheet(
currentValue: currentFilters['orderBy'] as String?,
onSelected: (value) {
final newFilters = {...currentFilters, 'orderBy': value};
context.read<SearchBloc>().add(ApplyFiltersEvent(filters: newFilters));
},
),
);
}

void _showColorOptions(BuildContext context, Map<String, dynamic> currentFilters) {
showModalBottomSheet(
context: context,
shape:
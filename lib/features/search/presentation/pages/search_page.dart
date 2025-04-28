import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/security/screenshot_prevention_service.dart';
import '../../../home/presentation/widgets/photo_card.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_bar.dart';
import '../widgets/filter_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ScrollController _scrollController = ScrollController();
  late ScreenshotPreventionService _screenshotPrevention;
  late SearchBloc _searchBloc;

  @override
  void initState() {
    super.initState();
    _searchBloc = context.read<SearchBloc>();
    _screenshotPrevention = context.read<ScreenshotPreventionService>();
    _screenshotPrevention.enableProtection();

    _scrollController.addListener(_onScroll);
    _searchBloc.add(LoadSearchHistoryEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      _searchBloc.add(LoadMoreSearchResultsEvent());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 60),
        child: AppBar(
          title: const Text('Search Photos'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SearchBarWidget(
                onSearch: (query) {
                  _searchBloc.add(SearchPhotosEvent(query: query));
                },
                onQueryChanged: (query) {
                  _searchBloc.add(GetSearchSuggestionsEvent(query: query));
                },
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (state is SearchInitial) {
            return _buildInitialView(context);
          } else if (state is SearchLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SearchSuccess) {
            return _buildSearchResults(context, state);
          } else if (state is SearchError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.message}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _searchBloc.add(LoadSearchHistoryEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return Column(
      children: [
        const FilterWidget(),
        Expanded(
          child: BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (prev, curr) =>
            curr is SearchInitial || curr is SearchHistoryLoaded,
            builder: (context, state) {
              if (state is SearchHistoryLoaded && state.history.isNotEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            _searchBloc.add(ClearSearchHistoryEvent());
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.history.map((query) {
                        return ActionChip(
                          label: Text(query),
                          onPressed: () {
                            _searchBloc.add(SearchPhotosEvent(query: query));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              }
              return const Center(
                child: Text('Start searching for photos'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchSuccess state) {
    if (state.photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${state.query}"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FilterWidget(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${state.photos.length} results for "${state.query}"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index >= state.photos.length) {
                  if (state.hasReachedMax) return null;
                  return const Center(child: CircularProgressIndicator());
                }

                final photo = state.photos[index];
                return PhotoGridCard(
                  photo: photo,
                  onTap: () {
                    // Navigate to photo detail page
                    Navigator.pushNamed(
                      context,
                      '/photo-detail',
                      arguments: photo,
                    );
                  },
                );
              },
              childCount: state.hasReachedMax
                  ? state.photos.length
                  : state.photos.length + 1,
            ),
          ),
        ),
      ],
    );
  }
}
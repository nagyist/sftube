import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libadwaita/libadwaita.dart';
import 'package:libadwaita_bitsdojo/libadwaita_bitsdojo.dart';
import 'package:libadwaita_searchbar_ac/libadwaita_searchbar_ac.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:piped_api/piped_api.dart';
import 'package:pstube/data/extensions/extensions.dart';
import 'package:pstube/data/services/services.dart';
import 'package:pstube/ui/screens/home_page/tabs.dart';
import 'package:pstube/ui/states/states.dart';
import 'package:pstube/ui/widgets/widgets.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yexp;

class MyHomePage extends HookConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _currentIndex = useState<int>(0);
    final _addDownloadController = TextEditingController();
    final _searchController = TextEditingController();
    final toggleSearch = useState<bool>(false);
    final searchedTerm = useState<String>('');
    final _controller = PageController(initialPage: _currentIndex.value);
    final videos = useMemoized(
      () => PipedApi().getUnauthenticatedApi().trending(
            region: ref.watch(regionProvider),
          ),
    );

    void toggleSearchBar({bool? value}) {
      searchedTerm.value = '';
      toggleSearch.value = value ?? !toggleSearch.value;
    }

    final navItems = <String, IconData>{
      context.locals.home: LucideIcons.home,
      context.locals.playlist: LucideIcons.list,
      context.locals.downloads: LucideIcons.download,
      context.locals.settings: LucideIcons.settings,
    };

    Future<dynamic> addDownload() async {
      if (_addDownloadController.text.isEmpty) {
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        final youtubeRegEx = RegExp(
          r'^((?:https?:)?\/\/)?((?:www|m)\.)?((?:youtube\.com|youtu.be))(\/(?:[\w\-]+\?v=|embed\/|v\/)?)([\w\-]+)(\S+)?$',
        );
        if (clipboard != null &&
            clipboard.text != null &&
            youtubeRegEx.hasMatch(clipboard.text!)) {
          _addDownloadController.text = clipboard.text!;
        }
      }
      return showPopoverForm(
        context: context,
        onConfirm: () {
          context.back();
          if (_addDownloadController.value.text.isNotEmpty) {
            showDownloadPopup(
              context,
              videoUrl: _addDownloadController.text
                  .split('/')
                  .last
                  .split('watch?v=')
                  .last,
            );
          }
        },
        hint: 'https://youtube.com/watch?v=***********',
        title: context.locals.downloadFromVideoUrl,
        controller: _addDownloadController,
      );
    }

    void clearAll() {
      final deleteFromStorage = ValueNotifier<bool>(false);
      showPopoverForm(
        context: context,
        builder: (ctx) => ValueListenableBuilder<bool>(
          valueListenable: deleteFromStorage,
          builder: (_, value, ___) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.locals.clearAll,
                  style: context.textTheme.bodyText1,
                ),
                CheckboxListTile(
                  value: value,
                  onChanged: (val) => deleteFromStorage.value = val!,
                  title: Text(context.locals.alsoDeleteThemFromStorage),
                ),
              ],
            );
          },
        ),
        onConfirm: () {
          final downloadListUtils = ref.read(downloadListProvider);
          for (final item in downloadListUtils.downloadList) {
            if (File(item.queryVideo.path + item.queryVideo.name)
                    .existsSync() &&
                deleteFromStorage.value) {
              File(item.queryVideo.path + item.queryVideo.name).deleteSync();
            }
          }
          downloadListUtils.clearAll();
          context.back();
        },
        confirmText: context.locals.yes,
        title: context.locals.confirm,
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex.value != 0) {
          _controller.jumpToPage(0);
          return false;
        } else if (toggleSearch.value) {
          toggleSearchBar();
          return false;
        }

        return true;
      },
      child: AdwScaffold(
        actions: AdwActions().bitsdojo,
        start: [
          AdwHeaderButton(
            isActive: toggleSearch.value,
            onPressed: toggleSearchBar,
            icon: const Icon(Icons.search, size: 20),
          ),
        ],
        title: toggleSearch.value
            ? AdwSearchBarAc(
                constraints: BoxConstraints.loose(const Size(500, 40)),
                toggleSearchBar: toggleSearchBar,
                hintText: '',
                search: null,
                asyncSuggestions: (str) => str.isNotEmpty
                    ? yexp.YoutubeExplode().search.getQuerySuggestions(str)
                    : Future.value([]),
                onSubmitted: (str) => searchedTerm.value = str,
                controller: _searchController,
              )
            : null,
        end: [
          if (!toggleSearch.value)
            AdwHeaderButton(
              onPressed: addDownload,
              icon: const Icon(
                Icons.add,
                size: 17,
              ),
            ),
          if (!toggleSearch.value && _currentIndex.value == 2)
            AdwHeaderButton(
              icon: const Icon(LucideIcons.trash),
              onPressed: clearAll,
            ),
        ],
        body: FutureBuilder<Response<BuiltList<StreamItem>>>(
          future: videos,
          builder: (context, snapshot) {
            final mainScreens = [
              HomeTab(snapshot: snapshot),
              const PlaylistTab(),
              const DownloadsTab(),
              const SettingsTab(),
            ];

            return Column(
              children: [
                if (!toggleSearch.value)
                  Flexible(
                    child: SFBody(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: mainScreens.length,
                        itemBuilder: (context, index) => mainScreens[index],
                        onPageChanged: (index) => _currentIndex.value = index,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: searchedTerm.value.isNotEmpty
                        ? SearchScreen(
                            searchedTerm: searchedTerm,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Center(
                                child: Text(context.locals.typeToSearch),
                              ),
                            ],
                          ),
                  ),
              ],
            );
          },
        ),
        viewSwitcher: !toggleSearch.value
            ? AdwViewSwitcher(
                tabs: List.generate(
                  navItems.entries.length,
                  (index) {
                    final item = navItems.entries.elementAt(index);
                    return ViewSwitcherData(
                      title: item.key,
                      badge: index == 2
                          ? ref.watch(downloadListProvider).downloading
                          : null,
                      icon: item.value,
                    );
                  },
                ),
                currentIndex: _currentIndex.value,
                onViewChanged: _controller.jumpToPage,
              )
            : null,
      ),
    );
  }
}

class SearchScreen extends HookWidget {
  const SearchScreen({
    super.key,
    required this.searchedTerm,
  });

  final ValueNotifier<String> searchedTerm;

  @override
  Widget build(BuildContext context) {
    final isMounted = useIsMounted();
    final api = PipedApi().getUnauthenticatedApi();
    final _currentPage = useState<BuiltList<SearchItem>?>(null);
    final nextPageToken = useState<String?>(null);
    final isLoading = useState<bool>(false);
    final filter = useState<SearchFilter>(SearchFilter.all);

    Future<void> loadVideos() async {
      if (!isMounted()) return;
      final page = (await api.search(
        q: searchedTerm.value,
        filter: SearchFilter.all,
      ))
          .data;

      if (page?.items == null) return;

      _currentPage.value = page!.items;
    }

    final controller = useScrollController();

    Future<void> _getMoreData() async {
      if (isLoading.value ||
          !isMounted() ||
          nextPageToken.value == null ||
          controller.position.pixels != controller.position.maxScrollExtent) {
        return;
      }

      isLoading.value = true;

      final nextPage = await api.searchNextPage(
        nextpage: nextPageToken.value!,
        q: searchedTerm.value,
        filter: filter.value,
      );

      if (nextPage.data == null && nextPage.data?.items != null) {
        return;
      }

      nextPageToken.value = nextPage.data!.nextpage;

      _currentPage.value = _currentPage.value!.rebuild(
        (b) => b.addAll(
          nextPage.data!.items!.toList(),
        ),
      );
      isLoading.value = false;
    }

    useEffect(
      () {
        loadVideos();
        controller.addListener(_getMoreData);
        searchedTerm.addListener(loadVideos);
        return () {
          searchedTerm.removeListener(loadVideos);
          controller.removeListener(_getMoreData);
        };
      },
      [controller],
    );

    return _currentPage.value != null && !isLoading.value
        ? ListView.separated(
            separatorBuilder: (context, index) => Divider(
              color: context.getBackgroundColor.withOpacity(0.6),
            ),
            shrinkWrap: true,
            controller: controller,
            itemCount: _currentPage.value!.length + 1,
            itemBuilder: (ctx, idx) => idx == _currentPage.value!.length
                ? getCircularProgressIndicator()
                : _currentPage.value![idx].showContent(context),
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }
}
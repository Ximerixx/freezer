import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/typicons_icons.dart';
import 'package:freezer/api/cache.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/details_screens.dart';
import 'package:freezer/ui/elements.dart';
import 'package:freezer/ui/home_screen.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/translations.i18n.dart';

import 'tiles.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import 'error.dart';


openScreenByURL(BuildContext context, String url) async {
  DeezerLinkResponse res = await deezerAPI.parseLink(url);
  if (res == null) return;

  switch (res.type) {
    case DeezerLinkType.TRACK:
      Track t = await deezerAPI.track(res.id);
      MenuSheet(context).defaultTrackMenu(t);
      break;
    case DeezerLinkType.ALBUM:
      Album a = await deezerAPI.album(res.id);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));
      break;
    case DeezerLinkType.ARTIST:
      Artist a = await deezerAPI.artist(res.id);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => ArtistDetails(a)));
      break;
    case DeezerLinkType.PLAYLIST:
      Playlist p = await deezerAPI.playlist(res.id);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlaylistDetails(p)));
      break;
  }

}

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  String _query;
  bool _offline = false;
  bool _loading = false;
  TextEditingController _controller = new TextEditingController();
  List _suggestions = [];
  bool _cancel = false;
  bool _showCards = true;
  FocusNode _focus = FocusNode();

  void _submit(BuildContext context, {String query}) async {
    if (query != null) _query = query;

    //URL
    if (_query.startsWith('http')) {
      setState(() => _loading = true);
      try {
        await openScreenByURL(context, _query);
      } catch (e) {}
      setState(() => _loading = false);
      return;
    }

    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => SearchResultsScreen(_query, offline: _offline,))
    );
  }

  @override
  void initState() {
    _cancel = false;
    //Check for connectivity and enable offline mode
    Connectivity().checkConnectivity().then((res) {
      if (res == ConnectivityResult.none) setState(() {
        _offline = true;
      });
    });


    super.initState();
  }

  //Load search suggestions
  Future<List<String>> _loadSuggestions() async {
    if (_query == null || _query.length < 2 || _query.startsWith('http')) return null;
    String q = _query;
    await Future.delayed(Duration(milliseconds: 300));
    if (q != _query) return null;
    //Load
    List sugg;
    try {
      sugg = await deezerAPI.searchSuggestions(_query);
    } catch (e) {print(e);}

    if (sugg != null && !_cancel)
      setState(() => _suggestions = sugg);
  }

  Widget _removeHistoryItemWidget(int index) {
    return IconButton(
      icon: Icon(Icons.close),
      onPressed: () async {
        if (cache.searchHistory != null)
          cache.searchHistory.removeAt(index);
        setState((){});
        await cache.save();
      }
    );
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Search'.i18n),
      body: ListView(
        children: <Widget>[
          Container(height: 4.0),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    alignment: Alignment(1.0, 0.0),
                    children: [
                      TextField(
                        onChanged: (String s) {
                          setState(() => _query = s);
                          _loadSuggestions();
                        },
                        onTap: () {
                          setState(() => _showCards = false);
                        },
                        focusNode: _focus,
                        decoration: InputDecoration(
                          labelText: 'Search or paste URL'.i18n,
                          fillColor: Theme.of(context).bottomAppBarColor,
                          filled: true,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey)
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey)
                          ),
                        ),
                        controller: _controller,
                        onSubmitted: (String s) => _submit(context, query: s),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40.0,
                            child: IconButton(
                              splashRadius: 20.0,
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _suggestions = [];
                                  _query = '';
                                });
                                _controller.clear();
                              },
                            ),
                          ),
                        ],
                      )

                    ],
                  )
                ),

              ],
            ),
          ),
          Container(height: 8.0),
          ListTile(
            title: Text('Offline search'.i18n),
            leading: Icon(Icons.offline_pin),
            trailing: Switch(
              value: _offline,
              onChanged: (v) {
                setState(() => _offline = !_offline);
              },
            ),
          ),
          if (_loading)
            LinearProgressIndicator(),
          FreezerDivider(),

          //"Browse" Cards
          if (_showCards)
            ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  'Quick access',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SearchBrowseCard(
                    color: Color(0xff11b192),
                    text: 'Flow'.i18n,
                    icon: Icon(Typicons.waves),
                    onTap: () async {
                      await playerHelper.playFromSmartTrackList(SmartTrackList(id: 'flow'));
                    },
                  ),
                  SearchBrowseCard(
                    color: Color(0xff7c42bb),
                    text: 'Shows'.i18n,
                    icon: Icon(FontAwesome5.podcast),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Shows'.i18n),
                        body: SingleChildScrollView(
                          child: HomePageScreen(
                            channel: DeezerChannel(target: 'shows')
                          )
                        ),
                      ),
                    )),
                  )
                ],
              ),
              Container(height: 4.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SearchBrowseCard(
                    color: Color(0xffff555d),
                    icon: Icon(FontAwesome5.chart_line),
                    text: 'Charts'.i18n,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Charts'.i18n),
                        body: SingleChildScrollView(
                          child: HomePageScreen(
                            channel: DeezerChannel(target: 'channels/charts')
                          )
                        ),
                      ),
                    )),
                  ),
                  SearchBrowseCard(
                    color: Color(0xff2c4ea7),
                    text: 'Browse'.i18n,
                    icon: Image.asset('assets/browse_icon.png', width: 26.0),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Browse'.i18n),
                        body: SingleChildScrollView(
                          child: HomePageScreen(
                            channel: DeezerChannel(target: 'channels/explore')
                          )
                        ),
                      ),
                    )),
                  )
                ],
              )
            ],

          //History
          if (!_showCards && cache.searchHistory != null && cache.searchHistory.length > 0 && (_query??'').length < 2)
            ...List.generate(cache.searchHistory.length > 10 ? 10 : cache.searchHistory.length, (int i) {
              dynamic data = cache.searchHistory[i].data;
              switch (cache.searchHistory[i].type) {
                case SearchHistoryItemType.TRACK:
                  return TrackTile(
                    data,
                    onTap: () {
                      List<Track> queue = cache.searchHistory.where((h) => h.type == SearchHistoryItemType.TRACK).map<Track>((t) => t.data).toList();
                      playerHelper.playFromTrackList(queue, queue.first.id, QueueSource(
                        text: 'Search history'.i18n,
                        source: 'searchhistory',
                        id: 'searchhistory'
                      ));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet(context);
                      m.defaultTrackMenu(data);
                    },
                    trailing: _removeHistoryItemWidget(i),
                  );
                case SearchHistoryItemType.ALBUM:
                  return AlbumTile(
                    data,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => AlbumDetails(data))
                      );
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet(context);
                      m.defaultAlbumMenu(data);
                    },
                    trailing: _removeHistoryItemWidget(i),
                  );
                case SearchHistoryItemType.ARTIST:
                  return ArtistHorizontalTile(
                    data,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ArtistDetails(data))
                      );
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet(context);
                      m.defaultArtistMenu(data);
                    },
                    trailing: _removeHistoryItemWidget(i),
                  );
                case SearchHistoryItemType.PLAYLIST:
                  return PlaylistTile(
                    data,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => PlaylistDetails(data))
                      );
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet(context);
                      m.defaultPlaylistMenu(data);
                    },
                    trailing: _removeHistoryItemWidget(i),
                  );
              }
              return Container();
          }),

          //Clear history
          if (cache.searchHistory != null && cache.searchHistory.length > 2)
            ListTile(
              title: Text('Clear search history'.i18n),
              leading: Icon(Icons.clear_all),
              onTap: () {
                cache.searchHistory = [];
                cache.save();
                setState((){});
              },
            ),

          //Suggestions
          ...List.generate((_suggestions??[]).length, (i) => ListTile(
            title: Text(_suggestions[i]),
            leading: Icon(Icons.search),
            onTap: () {
              setState(() => _query = _suggestions[i]);
              _submit(context);
            },
          ))
        ],
      ),
    );
  }
}

class SearchBrowseCard extends StatelessWidget {

  final Color color;
  final Widget icon;
  final Function onTap;
  final String text;
  SearchBrowseCard({@required this.color, @required this.onTap, @required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: this.onTap,
        child: Container(
          width: MediaQuery.of(context).size.width / 2 - 32,
          height: 75,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  icon,
                if (icon != null)
                  Container(width: 8.0),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: (color.computeLuminance() > 0.5) ? Colors.black:Colors.white
                  ),
                ),
              ],
            )
          ),
        ),
      )
    );
  }
}


class SearchResultsScreen extends StatelessWidget {

  final String query;
  final bool offline;

  SearchResultsScreen(this.query, {this.offline});

  Future _search() async {
    if (offline??false) {
      return await downloadManager.search(query);
    }
    return await deezerAPI.search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Search Results'.i18n),
      body: FutureBuilder(
        future: _search(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {

          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(),);
          if (snapshot.hasError) return ErrorScreen();

          SearchResults results = snapshot.data;

          if (results.empty)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.warning,
                    size: 64,
                  ),
                  Text('No results!'.i18n)
                ],
              ),
            );

          //Tracks
          List<Widget> tracks = [];
          if (results.tracks != null && results.tracks.length != 0) {
            tracks = [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text(
                  'Tracks'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              ...List.generate(3, (i) {
                if (results.tracks.length <= i) return Container(width: 0, height: 0,);
                Track t = results.tracks[i];
                return TrackTile(
                  t,
                  onTap: () {
                    cache.addToSearchHistory(t);
                    playerHelper.playFromTrackList(results.tracks, t.id, QueueSource(
                      text: 'Search'.i18n,
                      id: query,
                      source: 'search'
                    ));
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultTrackMenu(t);
                  },
                );
              }),
              ListTile(
                title: Text('Show all tracks'.i18n),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => TrackListScreen(results.tracks, QueueSource(
                      id: query,
                      source: 'search',
                      text: 'Search'.i18n
                    )))
                  );
                },
              ),
              FreezerDivider()
            ];
          }

          //Albums
          List<Widget> albums = [];
          if (results.albums != null && results.albums.length != 0) {
            albums = [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text(
                  'Albums'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              ...List.generate(3, (i) {
                if (results.albums.length <= i) return Container(height: 0, width: 0,);
                Album a = results.albums[i];
                return AlbumTile(
                  a,
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultAlbumMenu(a);
                  },
                  onTap: () {
                    cache.addToSearchHistory(a);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AlbumDetails(a))
                    );
                  },
                );
              }),
              ListTile(
                title: Text('Show all albums'.i18n),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AlbumListScreen(results.albums))
                  );
                },
              ),
              FreezerDivider()
            ];
          }

          //Artists
          List<Widget> artists = [];
          if (results.artists != null && results.artists.length != 0) {
            artists = [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Text(
                  'Artists'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Container(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(results.artists.length, (int i) {
                    Artist a = results.artists[i];
                    return ArtistTile(
                      a,
                      onTap: () {
                        cache.addToSearchHistory(a);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => ArtistDetails(a))
                        );
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet(context);
                        m.defaultArtistMenu(a);
                      },
                    );
                  }),
                )
              ),
              FreezerDivider()
            ];
          }

          //Playlists
          List<Widget> playlists = [];
          if (results.playlists != null && results.playlists.length != 0) {
            playlists = [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Text(
                  'Playlists'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              ...List.generate(3, (i) {
                if (results.playlists.length <= i) return Container(height: 0, width: 0,);
                Playlist p = results.playlists[i];
                return PlaylistTile(
                  p,
                  onTap: () {
                    cache.addToSearchHistory(p);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => PlaylistDetails(p))
                    );
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultPlaylistMenu(p);
                  },
                );
              }),
              ListTile(
                title: Text('Show all playlists'.i18n),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SearchResultPlaylists(results.playlists))
                  );
                },
              )
            ];
          }

          return ListView(
            children: <Widget>[
              Container(height: 8.0,),
              ...tracks,
              Container(height: 8.0,),
              ...albums,
              Container(height: 8.0,),
              ...artists,
              Container(height: 8.0,),
              ...playlists
            ],
          );
        },
      )
    );
  }
}

//List all tracks
class TrackListScreen extends StatelessWidget {

  final QueueSource queueSource;
  final List<Track> tracks;

  TrackListScreen(this.tracks, this.queueSource);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Tracks'.i18n),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (BuildContext context, int i) {
          Track t = tracks[i];
          return TrackTile(
            t,
            onTap: () {
              playerHelper.playFromTrackList(tracks, t.id, queueSource);
            },
            onHold: () {
              MenuSheet m = MenuSheet(context);
              m.defaultTrackMenu(t);
            },
          );
        },
      ),
    );
  }
}

//List all albums
class AlbumListScreen extends StatelessWidget {

  final List<Album> albums;
  AlbumListScreen(this.albums);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Albums'.i18n),
      body: ListView.builder(
        itemCount: albums.length,
        itemBuilder: (context, i) {
          Album a = albums[i];
          return AlbumTile(
            a,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AlbumDetails(a))
              );
            },
            onHold: () {
              MenuSheet m = MenuSheet(context);
              m.defaultAlbumMenu(a);
            },
          );
        },
      ),
    );
  }
}

class SearchResultPlaylists extends StatelessWidget {

  final List<Playlist> playlists;
  SearchResultPlaylists(this.playlists);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Playlists'.i18n),
      body: ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          Playlist p = playlists[i];
          return PlaylistTile(
            p,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => PlaylistDetails(p))
              );
            },
            onHold: () {
              MenuSheet m = MenuSheet(context);
              m.defaultPlaylistMenu(p);
            },
          );
        },
      ),
    );
  }
}

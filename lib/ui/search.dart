import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/details_screens.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/translations.i18n.dart';

import 'tiles.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import 'error.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  String _query;
  bool _offline = false;
  TextEditingController _controller = new TextEditingController();
  List _suggestions = [];

  void _submit(BuildContext context, {String query}) {
    if (query != null) _query = query;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => SearchResultsScreen(_query, offline: _offline,))
    );
  }

  @override
  void initState() {
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
    if (_query == null || _query.length < 2) return null;
    String q = _query;
    await Future.delayed(Duration(milliseconds: 300));
    if (q != _query) return null;
    //Load
    List sugg = await deezerAPI.searchSuggestions(_query);
    setState(() => _suggestions = sugg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search'.i18n),),
      body: ListView(
        children: <Widget>[
          Container(height: 16.0),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    alignment: Alignment(1.0, 1.0),
                    children: [
                      TextField(
                        onChanged: (String s) {
                          setState(() => _query = s);
                          _loadSuggestions();
                        },
                        decoration: InputDecoration(
                          labelText: 'Search'.i18n
                        ),
                        controller: _controller,
                        onSubmitted: (String s) => _submit(context, query: s),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _suggestions = [];
                            _query = '';
                          });
                          _controller.clear();
                        },
                      ),
                    ],
                  )
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () => _submit(context),
                  ),
                )
              ],
            ),
          ),
          ListTile(
            title: Text('Offline search'.i18n),
            leading: Switch(
              value: _offline,
              onChanged: (v) {
                setState(() => _offline = !_offline);
              },
            ),
          ),
          Divider(),
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
      appBar: AppBar(
        title: Text('Search Results'.i18n),
      ),
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
              Text(
                'Tracks'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold
                ),
              ),
              ...List.generate(3, (i) {
                if (results.tracks.length <= i) return Container(width: 0, height: 0,);
                Track t = results.tracks[i];
                return TrackTile(
                  t,
                  onTap: () {
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
              )
            ];
          }

          //Albums
          List<Widget> albums = [];
          if (results.albums != null && results.albums.length != 0) {
            albums = [
              Text(
                'Albums'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold
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
              )
            ];
          }

          //Artists
          List<Widget> artists = [];
          if (results.artists != null && results.artists.length != 0) {
            artists = [
              Text(
                'Artists'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold
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
              )
            ];
          }

          //Playlists
          List<Widget> playlists = [];
          if (results.playlists != null && results.playlists.length != 0) {
            playlists = [
              Text(
                'Playlists'.i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold
                ),
              ),
              ...List.generate(3, (i) {
                if (results.playlists.length <= i) return Container(height: 0, width: 0,);
                Playlist p = results.playlists[i];
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
      appBar: AppBar(title: Text('Tracks'.i18n),),
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
      appBar: AppBar(title: Text('Albums'.i18n),),
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
      appBar: AppBar(title: Text('Playlists'.i18n),),
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

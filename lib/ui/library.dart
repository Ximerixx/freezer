import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/cache.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/settings.dart';
import 'package:freezer/ui/details_screens.dart';
import 'package:freezer/ui/downloads_screen.dart';
import 'package:freezer/ui/error.dart';
import 'package:freezer/ui/importer_screen.dart';
import 'package:freezer/ui/tiles.dart';
import 'package:freezer/translations.i18n.dart';

import 'menu.dart';
import 'settings_screen.dart';
import '../api/spotify.dart';
import '../api/download.dart';

class LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('Library'.i18n),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.file_download),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DownloadsScreen())
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => SettingsScreen())
            );
          },
        ),
      ],
    );
  }

}

class LibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LibraryAppBar(),
      body: ListView(
        children: <Widget>[
          Container(height: 4.0,),
          if (!downloadManager.running && downloadManager.queueSize > 0)
            ListTile(
              title: Text('Downloads'.i18n),
              leading: Icon(Icons.file_download),
              subtitle: Text('Downloading is currently stopped, click here to resume.'.i18n),
              onTap: () {
                downloadManager.start();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DownloadsScreen()
                ));
              },
            ),
          //Dirty if to not use columns
          if (!downloadManager.running && downloadManager.queueSize > 0)
            Divider(),

          ListTile(
            title: Text('Tracks'.i18n),
            leading: Icon(Icons.audiotrack),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryTracks())
              );
            },
          ),
          ListTile(
            title: Text('Albums'.i18n),
            leading: Icon(Icons.album),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryAlbums())
              );
            },
          ),
          ListTile(
            title: Text('Artists'.i18n),
            leading: Icon(Icons.recent_actors),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryArtists())
              );
            },
          ),
          ListTile(
            title: Text('Playlists'.i18n),
            leading: Icon(Icons.playlist_play),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryPlaylists())
              );
            },
          ),
          ListTile(
            title: Text('History'.i18n),
            leading: Icon(Icons.history),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => HistoryScreen())
              );
            },
          ),
          Divider(),
          ListTile(
            title: Text('Import'.i18n),
            leading: Icon(Icons.import_export),
            subtitle: Text('Import playlists from Spotify'.i18n),
            onTap: () {
              if (spotify.doneImporting != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => CurrentlyImportingScreen())
                );
                if (spotify.doneImporting) spotify.doneImporting = null;
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ImporterScreen())
              );
            },
          ),
          ExpansionTile(
            title: Text('Statistics'.i18n),
            leading: Icon(Icons.insert_chart),
            children: <Widget>[
              FutureBuilder(
                future: downloadManager.getStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorScreen();
                  if (!snapshot.hasData) return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CircularProgressIndicator()
                      ],
                    ),
                  );
                  List<String> data = snapshot.data;
                  return Column(
                    children: <Widget>[
                      ListTile(
                        title: Text('Offline tracks'.i18n),
                        leading: Icon(Icons.audiotrack),
                        trailing: Text(data[0]),
                      ),
                      ListTile(
                        title: Text('Offline albums'.i18n),
                        leading: Icon(Icons.album),
                        trailing: Text(data[1]),
                      ),
                      ListTile(
                        title: Text('Offline playlists'.i18n),
                        leading: Icon(Icons.playlist_add),
                        trailing: Text(data[2]),
                      ),
                      ListTile(
                        title: Text('Offline size'.i18n),
                        leading: Icon(Icons.sd_card),
                        trailing: Text(data[3]),
                      ),
                      ListTile(
                        title: Text('Free space'.i18n),
                        leading: Icon(Icons.disc_full),
                        trailing: Text(data[4]),
                      ),
                    ],
                  );
                },
              )
            ],
          )
        ],
      ),
    );
  }
}

class LibraryTracks extends StatefulWidget {
  @override
  _LibraryTracksState createState() => _LibraryTracksState();
}

class _LibraryTracksState extends State<LibraryTracks> {

  bool _loading = false;
  bool _loadingTracks = false;
  ScrollController _scrollController = ScrollController();
  List<Track> tracks = [];
  List<Track> allTracks = [];
  int trackCount;

  Playlist get _playlist => Playlist(id: deezerAPI.favoritesPlaylistId);

  Future _load() async {
    //Already loaded
    if (trackCount != null && tracks.length >= trackCount) {
      //Update tracks cache if fully loaded
      if (cache.libraryTracks == null || cache.libraryTracks.length != trackCount) {
        setState(() {
          cache.libraryTracks = tracks.map((t) => t.id).toList();
        });
        await cache.save();
      }
      return;
    }

    ConnectivityResult connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      setState(() => _loading = true);
      int pos = tracks.length;

      if (trackCount == null || tracks.length == 0) {
        //Load tracks as a playlist
        Playlist favPlaylist;
        try {
          favPlaylist = await deezerAPI.playlist(deezerAPI.favoritesPlaylistId);
        } catch (e) {}
        //Error loading
        if (favPlaylist == null) {
          setState(() => _loading = false);
          return;
        }
        //Update
        setState(() {
          trackCount = favPlaylist.trackCount;
          tracks = favPlaylist.tracks;
          _makeFavorite();
          _loading = false;
        });
        return;
      }

      //Load another page of tracks from deezer
      if (_loadingTracks) return;
      _loadingTracks = true;

      List<Track> _t;
      try {
        _t = await deezerAPI.playlistTracksPage(deezerAPI.favoritesPlaylistId, pos);
      } catch (e) {}
      //On error load offline
      if (_t == null) {
        await _loadOffline();
        return;
      }
      setState(() {
        tracks.addAll(_t);
        _makeFavorite();
        _loading = false;
        _loadingTracks = false;
      });

    }
  }

  Future _loadOffline() async {
    Playlist p = await downloadManager.getPlaylist(deezerAPI.favoritesPlaylistId);
    if (p != null) setState(() {
      tracks = p.tracks;
    });
  }

  Future _loadAll() async {
    List tracks = await downloadManager.allOfflineTracks();
    setState(() {
      allTracks = tracks;
    });
  }

  //Update tracks with favorite true
  void _makeFavorite() {
    for (int i=0; i<tracks.length; i++)
      tracks[i].favorite = true;
  }

  @override
  void initState() {
    _scrollController.addListener(() {
      //Load more tracks on scroll
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) _load();
    });

    _load();

    //Load all tracks
    _loadAll();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tracks'.i18n),),
      body: ListView(
        controller: _scrollController,
        children: <Widget>[
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(height: 8.0,),
                Text(
                  'Loved tracks'.i18n,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    MakePlaylistOffline(_playlist),
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.file_download, size: 32.0,),
                          Container(width: 4,),
                          Text('Download'.i18n)
                        ],
                      ),
                      onPressed: () {
                        downloadManager.addOfflinePlaylist(_playlist, private: false);
                      },
                    )
                  ],
                )
              ],
            ),
          ),
          //Loved tracks
          ...List.generate(tracks.length, (i) {
            Track t = tracks[i];
            return TrackTile(
              t,
              onTap: () {
                playerHelper.playFromTrackList(tracks, t.id, QueueSource(
                  id: deezerAPI.favoritesPlaylistId,
                  text: 'Favorites'.i18n,
                  source: 'playlist'
                ));
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                m.defaultTrackMenu(
                  t,
                  onRemove: () {
                    setState(() {
                      tracks.removeWhere((track) => t.id == track.id);
                    });
                  }
                );
              },
            );
          }),
          if (_loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                )
              ],
            ),
          Divider(),
          Text(
            'All offline tracks'.i18n,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold
            ), 
          ),
          Container(height: 8,),
          ...List.generate(allTracks.length, (i) {
            Track t = allTracks[i];
            return TrackTile(
              t,
              onTap: () {
                playerHelper.playFromTrackList(allTracks, t.id, QueueSource(
                  id: 'allTracks',
                  text: 'All offline tracks'.i18n,
                  source: 'offline'
                ));
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                m.defaultTrackMenu(t);
              },
            );
          })
        ],
      )
    );
  }
}


class LibraryAlbums extends StatefulWidget {
  @override
  _LibraryAlbumsState createState() => _LibraryAlbumsState();
}

class _LibraryAlbumsState extends State<LibraryAlbums> {

  List<Album> _albums;

  Future _load() async {
    if (settings.offlineMode) return;
    try {
      List<Album> albums = await deezerAPI.getAlbums();
      setState(() => _albums = albums);
    } catch (e) {}
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Albums'.i18n),),
      body: ListView(
        children: <Widget>[
          Container(height: 8.0,),
          if (!settings.offlineMode && _albums == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator()
              ],
            ),

          if (_albums != null)
            ...List.generate(_albums.length, (int i) {
              Album a = _albums[i];
              return AlbumTile(
                a,
                onTap: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AlbumDetails(a))
                  );
                },
                onHold: () async {
                  MenuSheet m = MenuSheet(context);
                  m.defaultAlbumMenu(a, onRemove: () {
                    setState(() => _albums.remove(a));
                  });
                },
              );
            }),

          FutureBuilder(
            future: downloadManager.getOfflineAlbums(),
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData || snapshot.data.length == 0) return Container(height: 0, width: 0,);

              List<Album> albums = snapshot.data;
              return Column(
                children: <Widget>[
                  Divider(),
                  Text(
                    'Offline albums'.i18n,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0
                    ),
                  ),
                  ...List.generate(albums.length, (i) {
                    Album a = albums[i];
                    return AlbumTile(
                      a,
                      onTap: () {
                        Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => AlbumDetails(a))
                        );
                      },
                      onHold: () async {
                        MenuSheet m = MenuSheet(context);
                        m.defaultAlbumMenu(a, onRemove: () {
                          setState(() {
                            albums.remove(a);
                            _albums.remove(a);
                          });
                        });
                      },
                    );
                  })
                ],
              );
            },
          )
        ],
      ),
    );
  }
}

class LibraryArtists extends StatefulWidget {
  @override
  _LibraryArtistsState createState() => _LibraryArtistsState();
}

class _LibraryArtistsState extends State<LibraryArtists> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Artists'.i18n),),
      body: FutureBuilder(
        future: deezerAPI.getArtists(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {

          if (snapshot.hasError) return ErrorScreen();
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(),);

          return ListView(
            children: <Widget>[
              ...List.generate(snapshot.data.length, (i) {
                Artist a = snapshot.data[i];
                return ArtistHorizontalTile(
                  a,
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ArtistDetails(a))
                    );
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultArtistMenu(a, onRemove: () {
                      setState(() => {});
                    });
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}


class LibraryPlaylists extends StatefulWidget {
  @override
  _LibraryPlaylistsState createState() => _LibraryPlaylistsState();
}

class _LibraryPlaylistsState extends State<LibraryPlaylists> {

  List<Playlist> _playlists;

  Future _load() async {
    if (!settings.offlineMode) {
      try {
        List<Playlist> playlists = await deezerAPI.getPlaylists();
        setState(() => _playlists = playlists);
      } catch (e) {}
    }
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  Playlist get favoritesPlaylist => Playlist(
    id: deezerAPI.favoritesPlaylistId,
    title: 'Favorites'.i18n,
    user: User(name: deezerAPI.userName),
    image: ImageDetails(thumbUrl: 'assets/favorites_thumb.jpg'),
    tracks: [],
    trackCount: 1,
    duration: Duration(seconds: 0)
  );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Playlists'.i18n),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Create new playlist'.i18n),
            leading: Icon(Icons.playlist_add),
            onTap: () async {
              if (settings.offlineMode) {
                Fluttertoast.showToast(
                  msg: 'Cannot create playlists in offline mode'.i18n,
                  gravity: ToastGravity.BOTTOM
                );
                return;
              }
              MenuSheet m = MenuSheet(context);
              await m.createPlaylist();
              await _load();
            },
          ),
          Divider(),

          if (!settings.offlineMode && _playlists == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
              ],
            ),

          //Favorites playlist
          PlaylistTile(
            favoritesPlaylist,
            onTap: () async {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => PlaylistDetails(favoritesPlaylist)
              ));
            },
            onHold: () {
              MenuSheet m = MenuSheet(context);
              favoritesPlaylist.library = true;
              m.defaultPlaylistMenu(favoritesPlaylist);
            },
          ),

          if (_playlists != null)
            ...List.generate(_playlists.length, (int i) {
              Playlist p = _playlists[i];
              return PlaylistTile(
                p,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => PlaylistDetails(p)
                )),
                onHold: () {
                  MenuSheet m = MenuSheet(context);
                  m.defaultPlaylistMenu(
                    p,
                    onRemove: () {setState(() => _playlists.remove(p));},
                    onUpdate: () {_load();});
                },
              );
            }),

          FutureBuilder(
            future: downloadManager.getOfflinePlaylists(),
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData) return Container(height: 0, width: 0,);
              if (snapshot.data.length == 0) return Container(height: 0, width: 0,);

              List<Playlist> playlists = snapshot.data;
              return Column(
                children: <Widget>[
                  Divider(),
                  Text(
                    'Offline playlists'.i18n,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  ...List.generate(playlists.length, (i) {
                    Playlist p = playlists[i];
                    return PlaylistTile(
                      p,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => PlaylistDetails(p)
                      )),
                      onHold: () {
                        MenuSheet m = MenuSheet(context);
                        m.defaultPlaylistMenu(p, onRemove: () {
                          setState(() {
                            playlists.remove(p);
                            _playlists.remove(p);
                          });
                        });
                      },
                    );
                  })
                ],
              );
            },
          )

        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'.i18n),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: () {
              setState(() => cache.history = []);
              cache.save();
            },
          )
        ],
      ),
      body: ListView.builder(
        itemCount: (cache.history??[]).length,
        itemBuilder: (BuildContext context, int i) {
          Track t = cache.history[i];
          return TrackTile(
            t,
            onTap: () {
              playerHelper.playFromTrackList(cache.history, t.id, QueueSource(
                id: null,
                text: 'History'.i18n,
                source: 'history'
              ));
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


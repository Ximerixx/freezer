import 'package:flutter/material.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/error.dart';
import 'package:freezer/ui/menu.dart';
import 'tiles.dart';
import 'details_screens.dart';
import '../settings.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Container(height: 16.0,),
        FreezerTitle(),
        Container(height: 16.0,),
        HomePageScreen()
      ],
    );
  }
}

class FreezerTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'freezer',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Jost',
        fontSize: 75,
        fontStyle: FontStyle.italic,
        letterSpacing: 7
      ),
    );
  }
}



class HomePageScreen extends StatefulWidget {

  final HomePage homePage;
  final DeezerChannel channel;
  HomePageScreen({this.homePage, this.channel, Key key}): super(key: key);

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {

  HomePage _homePage;
  bool _cancel = false;
  bool _error = false;

  void _loadChannel() async {
    HomePage _hp;
    //Fetch channel from api
    try {
      _hp = await deezerAPI.getChannel(widget.channel.target);
    } catch (e) {}
    if (_hp == null) {
      //On error
      setState(() => _error = true);
      return;
    }
    setState(() => _homePage = _hp);
  }
  void _loadHomePage() async {
    //Load local
    try {
      HomePage _hp = await HomePage().load();
      setState(() => _homePage = _hp);
    } catch (e) {}
    //On background load from API
    try {
      if (settings.offlineMode) return;
      HomePage _hp = await deezerAPI.homePage();
      if (_hp != null) {
        if (_cancel) return;
        if (_hp.sections.length == 0) return;
        setState(() => _homePage = _hp);
        //Save to cache
        await _homePage.save();
      }
    } catch (e) {}
  }

  void _load() {
    if (widget.channel != null) {
      _loadChannel();
      return;
    }
    if (widget.channel == null && widget.homePage == null) {
      _loadHomePage();
      return;
    }
    if (widget.homePage.sections == null || widget.homePage.sections.length == 0) {
      _loadHomePage();
      return;
    }
    //Already have data
    setState(() => _homePage = widget.homePage);
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_homePage == null)
      return Center(child: CircularProgressIndicator(),);
    if (_error)
      return ErrorScreen();
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          ...List.generate(_homePage.sections.length, (i) {
            HomePageSection section = _homePage.sections[i];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                    child: Text(
                      section.title,
                      textAlign: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 24.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0)
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List<Widget>.generate(section.items.length, (i) {
                      HomePageItem item = section.items[i];

                      switch (item.type) {
                        case HomePageItemType.SMARTTRACKLIST:
                          return SmartTrackListTile(
                            item.value,
                            onTap: () {
                              playerHelper.playFromSmartTrackList(item.value);
                            },
                          );
                        case HomePageItemType.ALBUM:
                          return AlbumCard(
                            item.value,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => AlbumDetails(item.value)
                              ));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet(context);
                              m.defaultAlbumMenu(item.value);
                            },
                          );
                        case HomePageItemType.ARTIST:
                          return ArtistTile(
                            item.value,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ArtistDetails(item.value)
                              ));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet(context);
                              m.defaultArtistMenu(item.value);
                            },
                          );
                        case HomePageItemType.PLAYLIST:
                          return PlaylistCardTile(
                            item.value,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => PlaylistDetails(item.value)
                              ));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet(context);
                              m.defaultPlaylistMenu(item.value);
                            },
                          );
                        case HomePageItemType.CHANNEL:
                          return ChannelTile(
                            item.value,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(title: Text(item.value.title.toString()),),
                                  body: HomePageScreen(channel: item.value,),
                                )
                              ));
                            },
                          );
                      }
                      return Container(height: 0, width: 0);
                    }),
                  ),
                ),
                Container(height: 16.0,)
              ],
            );
          })
        ],
      ),
    );
  }
}

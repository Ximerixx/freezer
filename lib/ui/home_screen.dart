import 'package:flutter/material.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/main.dart';
import 'package:freezer/ui/elements.dart';
import 'package:freezer/ui/error.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/translations.i18n.dart';
import 'tiles.dart';
import 'details_screens.dart';
import '../settings.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SafeArea(child: Container()),
          Flexible(child: HomePageScreen(),)
        ],
      ),
    );
  }
}

class FreezerTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset('assets/icon.png', width: 64, height: 64),
              Text(
                'freezer',
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900
                ),
              )
            ],
          )
        ],
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
      if (settings.offlineMode) await deezerAPI.authorize();
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
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_homePage == null)
      return Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ));
    if (_error)
      return ErrorScreen();
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _homePage.sections.length,
      itemBuilder: (context, i) {
        return HomepageSectionWidget(_homePage.sections[i]);
      },
    );
  }
}

class HomepageSectionWidget extends StatelessWidget {

  final HomePageSection section;
  HomepageSectionWidget(this.section);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            child: Text(
              section.title,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.w900
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(section.items.length + 1, (i) {
              //Has more items
              if (i == section.items.length) {
                if (section.hasMore??false) {
                  return FlatButton(
                    child: Text(
                      'Show more'.i18n,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20.0
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar(section.title),
                        body: SingleChildScrollView(
                          child: HomePageScreen(
                            channel: DeezerChannel(target: section.pagePath)
                          )
                        ),
                      ),
                    )),
                  );
                }
                return Container(height: 0, width: 0);
              }
              //Show item
              HomePageItem item = section.items[i];
              return HomePageItemWidget(item);
            }),
          ),
        ),
        Container(height: 8.0),
      ],
    );
  }
}



class HomePageItemWidget extends StatelessWidget {

  HomePageItem item;
  HomePageItemWidget(this.item);

  @override
  Widget build(BuildContext context) {

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
                  appBar: FreezerAppBar(item.value.title.toString()),
                  body: SingleChildScrollView(
                    child: HomePageScreen(channel: item.value,)
                  ),
                )
            ));
          },
        );
      case HomePageItemType.SHOW:
        return ShowCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ShowScreen(item.value)
            ));
          },
        );
    }
    return Container(height: 0, width: 0);
  }
}

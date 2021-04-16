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
    return Column(
        children: List.generate(_homePage.sections.length, (i) {
          switch (_homePage.sections[i].layout) {
            case HomePageSectionLayout.ROW:
              return HomepageRowSection(_homePage.sections[i]);
            case HomePageSectionLayout.GRID:
              return HomePageGridSection(_homePage.sections[i]);
            default:
              return HomepageRowSection(_homePage.sections[i]);
          }
        },
    ));
  }
}

class HomepageRowSection extends StatelessWidget {

  final HomePageSection section;
  HomepageRowSection(this.section);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          section.title??'',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w900
          ),
        ),
      ),
      subtitle: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(section.items.length + 1, (j) {
            //Has more items
            if (j == section.items.length) {
              if (section.hasMore ?? false) {
                return TextButton(
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
            HomePageItem item = section.items[j];
            return HomePageItemWidget(item);
          }),
        ),
      )
    );
  }
}

class HomePageGridSection extends StatelessWidget {

  final HomePageSection section;
  HomePageGridSection(this.section);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          section.title??'',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.w900
          ),
        ),
      ),
      subtitle: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: List.generate(section.items.length, (i) {

          //Item
          return HomePageItemWidget(section.items[i]);
        }),
      ),
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

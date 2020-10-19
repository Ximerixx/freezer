import 'package:flutter/material.dart';
import 'package:freezer/settings.dart';

class LeadingIcon extends StatelessWidget {

  final IconData icon;
  final Color color;
  LeadingIcon(this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.0,
      height: 42.0,
      decoration: BoxDecoration(
        color: (color??Theme.of(context).primaryColor).withOpacity(1.0),
        shape: BoxShape.circle
      ),
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }
}

//Container with set size to match LeadingIcon
class EmptyLeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 42.0, height: 42.0);
  }
}


class FreezerAppBar extends StatelessWidget implements PreferredSizeWidget {

  final String title;
  final List<Widget> actions;
  final Widget bottom;
  //Should be specified if bottom is specified
  final double height;

  FreezerAppBar(this.title, {this.actions = const [], this.bottom, this.height = 56.0});
  
  Size get preferredSize => Size.fromHeight(this.height);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(primaryColor: (Theme.of(context).brightness == Brightness.light)?Colors.white:Colors.black),
      child: AppBar(
        elevation: 0.0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: actions,
        bottom: bottom,
      ),
    );
  }
}

class FreezerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: 1.5,
      indent: 16.0,
      endIndent: 16.0,
    );
  }
}

TextStyle popupMenuTextStyle() {
  return TextStyle(
    color: (settings.theme == Themes.Light)?Colors.black:Colors.white
  );
}
import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {

  final String message;

  ErrorScreen({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error,
            color: Colors.red,
            size: 64.0,
          ),
          Container(height: 4.0,),
          Text(message ?? 'Please check your connection and try again later...')
        ],
      ),
    );
  }
}

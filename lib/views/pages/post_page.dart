import 'package:flutter/material.dart';

class PostPage extends StatelessWidget {
  const PostPage({super.key});

  final title = 'Post Page';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Container(
        color: Colors.purple,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('First Name'),
            SizedBox(height: 8,),
            TextField(decoration: InputDecoration(border: OutlineInputBorder())),
            SizedBox(height: 8,),
            Text('Last Name'),
            SizedBox(height: 8,),
            TextField(decoration: InputDecoration(border: OutlineInputBorder())),
          ],
        ),
      ),
    );
  }
}

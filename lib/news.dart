import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customdropdown.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';

bool loaded = false;
var loadedJson;

class News extends StatefulWidget {
  @override
  NewsState createState() => NewsState();
}

class NewsState extends State<News> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Offstage(
              offstage: index != 0,
              child: TickerMode(
                enabled: index == 0,
                child: MaterialApp(home: MyHome()),
              ),
            ),
            Offstage(
              offstage: index != 1,
              child: TickerMode(
                enabled: index == 1,
                child: MaterialApp(home: BookMarks()),
              ),
            ),
          ],
        ),
        bottomNavigationBar: new BottomNavigationBar(
          currentIndex: index,
          onTap: (int index) {
            setState(() {
              this.index = index;
            });
          },
          items: <BottomNavigationBarItem>[
            new BottomNavigationBarItem(
              icon: new Icon(Icons.home),
              title: new Text("Home"),
            ),
            new BottomNavigationBarItem(
              icon: new Icon(Icons.collections_bookmark),
              title: new Text("Bookmarks"),
            ),
          ],
        ),
      ),
    );
  }
}

class BookMarkItem {
  String key;
  String title;
  String description;
  String imageURL;
  String source;
  String articleURL;

  BookMarkItem(this.title, this.description, this.imageURL, this.source,
      this.articleURL);
  BookMarkItem.fromSnapshot(DataSnapshot snapshot)
      : key = snapshot.key,
        title = snapshot.value['title'],
        description = snapshot.value['description'],
        imageURL = snapshot.value['imageURL'],
        source = snapshot.value['source'],
        articleURL = snapshot.value['articleURL'];

  toJson() {
    return {
      'title': title,
      'description': description,
      'imageURL': imageURL,
      'source': source,
      'articleURL': articleURL,
    };
  }
}

class MyHomeState extends State<MyHome> {
  bool notNull(Object o) => o != null;
  final currentTime = new DateTime.now();

  List<BookMarkItem> items = List();
  BookMarkItem bookMarkItem;
  DatabaseReference reference;

  @override
  void initState() {
    super.initState();
    bookMarkItem = BookMarkItem("", "", "", "", "");
    final FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
    _getUser().then((user) {
      reference = firebaseDatabase.reference().child('users/' + user.uid);
      reference.onChildAdded.listen(_onEntryAdded);
      reference.onChildChanged.listen(_onEntryChanged);
    });
  }

  _onEntryAdded(Event event) {
    setState(() {
      items.add(BookMarkItem.fromSnapshot(event.snapshot));
    });
  }

  _onEntryChanged(Event event) {
    var old = items.singleWhere((entry) {
      return entry.key == event.snapshot.key;
    });
    setState(() {
      items[items.indexOf(old)] = BookMarkItem.fromSnapshot(event.snapshot);
    });
  }

  void bookMark() async {
    reference.push().set(bookMarkItem.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        centerTitle: true,
        title: new Text('News'),
        actions: <Widget>[
          StreamBuilder(
            stream: FirebaseAuth.instance.currentUser().asStream(),
            builder:
                (BuildContext context, AsyncSnapshot<FirebaseUser> snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(96.0),
                      boxShadow: [
                        new BoxShadow(
                            color: Colors.black45,
                            blurRadius: 1.5,
                            offset: Offset(0.0, 1.0))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(96.0),
                      child: Image.network(snapshot.data.photoUrl),
                    ),
                  ),
                );
              } else {
                return Container(
                  height: 0.0,
                  width: 0.0,
                );
              }
            },
          )
        ],
      ),
      body: FutureBuilder(
        future: fetchFutureLaunches(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final jsonResponse = json.decode(snapshot.data.toString());
            return ListView.builder(
              itemCount: jsonResponse['totalResults'],
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(
                      left: 8.0, right: 8.0, top: 12.0, bottom: 0.0),
                  child: GestureDetector(
                    onTap: () {
                      _launchURL(jsonResponse['articles'][index]['url']);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.all(const Radius.circular(7.5)),
                        boxShadow: [
                          new BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2.5,
                              offset: Offset(0.0, 2.5))
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(children: <Widget>[
                          Flexible(
                            child: Column(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        (currentTime.difference(DateTime.parse(
                                                    jsonResponse['articles']
                                                            [index]
                                                        ['publishedAt'])))
                                                .inHours
                                                .toString() +
                                            " hr ago · " +
                                            jsonResponse['articles'][index]
                                                ['source']['name'],
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13.0),
                                      ),
                                      new CustomDropdownButton<List<Object>>(
                                        isDense: true,
                                        iconSize: 20.0,
                                        items: <List<Object>>[
                                          [
                                            '  Save',
                                            Icons.bookmark_border,
                                          ],
                                          [
                                            '  Customize',
                                            Icons.settings,
                                          ],
                                        ].map((var value) {
                                          return new CustomDropdownMenuItem<
                                              List<Object>>(
                                            value: value,
                                            child: new Row(
                                              children: <Widget>[
                                                Icon(
                                                  value[1],
                                                  color: Colors.grey[700],
                                                ),
                                                Text(
                                                  value[0],
                                                  style:
                                                      TextStyle(fontSize: 12.0),
                                                )
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          switch (value[0]) {
                                            case '  Save':
                                              bookMarkItem.title =
                                                  jsonResponse['articles']
                                                      [index]['title'];
                                              bookMarkItem.description =
                                                  jsonResponse['articles']
                                                          [index]
                                                      ['description'] ??= "";
                                              bookMarkItem.imageURL =
                                                  jsonResponse['articles']
                                                      [index]['urlToImage'];
                                              bookMarkItem.source =
                                                  jsonResponse['articles']
                                                      [index]['source']['name'];
                                              bookMarkItem.articleURL =
                                                  jsonResponse['articles']
                                                      [index]['url'];
                                              bookMark();
                                              break;
                                            case '  Customize':
                                              print("Customize");
                                              break;
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Column(
                                        children: <Widget>[
                                          Text(
                                            jsonResponse['articles'][index]
                                                ['title'],
                                            style: TextStyle(fontSize: 15.0),
                                          ),
                                          Text(
                                            jsonResponse['articles'][index]
                                                ['description'] ??= "",
                                            maxLines: 3,
                                            style: TextStyle(
                                                fontSize: 13.0,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    jsonResponse['articles'][index]
                                                ['urlToImage'] !=
                                            null
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                left: 2.0),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(7.5),
                                              child: CachedNetworkImage(
                                                height: 75.0,
                                                width: 75.0,
                                                imageUrl:
                                                    jsonResponse['articles']
                                                        [index]['urlToImage'],
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ].where(notNull).toList(),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            );
          }
          return new Center(
              child: CircularProgressIndicator(
                  valueColor: new AlwaysStoppedAnimation<Color>(Colors.blue)));
        },
      ),
    );
  }

  Future<String> fetchFutureLaunches() async {
    if (!loaded) {
      print("Got from URL.");
      final json = await http.get(
          "https://newsapi.org/v2/top-headlines?country=us&apiKey=792059e30e20494e94fd5a2e56fb4da4");
      loaded = true;
      loadedJson = json.body;
      return json.body;
    }
    print("Loaded from storage");
    return loadedJson;
  }
}

class MyHome extends StatefulWidget {
  @override
  MyHomeState createState() => MyHomeState();
}

class BookMarks extends StatefulWidget {
  @override
  BookMarkState createState() => BookMarkState();
}

class BookMarkState extends State<BookMarks> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bookmarks"),
      ),
      body: Center(
        child: FutureBuilder(
          future: _getUser(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              FirebaseUser user = snapshot.data;
              return FirebaseAnimatedList(
                  query: FirebaseDatabase.instance
                      .reference()
                      .child('users/' + user.uid),
                  itemBuilder: (context, snapshot, animation, index) {
                    return Padding(
                      padding: const EdgeInsets.only(
                          left: 8.0, right: 8.0, top: 12.0, bottom: 0.0),
                      child: GestureDetector(
                        onTap: () {
                          _launchURL(snapshot.value['articleURL']);
                        },
                        child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.all(const Radius.circular(7.5)),
                              boxShadow: [
                                new BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2.5,
                                    offset: Offset(0.0, 2.5))
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(children: <Widget>[
                                Flexible(
                                  child: Column(
                                    children: <Widget>[
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 5.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            Text(
                                              snapshot.value['source'],
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13.0),
                                            ),
                                            new CustomDropdownButton<
                                                List<Object>>(
                                              isDense: true,
                                              iconSize: 20.0,
                                              items: <List<Object>>[
                                                [
                                                  '  Remove bookmark',
                                                  Icons.bookmark,
                                                ],
                                                [
                                                  '  Customize',
                                                  Icons.settings,
                                                ],
                                              ].map((var value) {
                                                return new CustomDropdownMenuItem<
                                                    List<Object>>(
                                                  value: value,
                                                  child: new Row(
                                                    children: <Widget>[
                                                      Icon(
                                                        value[1],
                                                        color: Colors.grey[700],
                                                      ),
                                                      Text(
                                                        value[0],
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                switch (value[0]) {
                                                  case '  Remove bookmark':
                                                    removeBookMark(
                                                        FirebaseDatabase
                                                            .instance
                                                            .reference()
                                                            .child('users/' +
                                                                user.uid).child('/' + snapshot.key));
                                                    break;
                                                  case '  Customize':
                                                    print("Customize");
                                                    break;
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Column(
                                              children: <Widget>[
                                                Text(
                                                  snapshot.value['title'],
                                                  style:
                                                      TextStyle(fontSize: 15.0),
                                                ),
                                                Text(
                                                  snapshot.value[
                                                      'description'] ??= "",
                                                  maxLines: 3,
                                                  style: TextStyle(
                                                      fontSize: 13.0,
                                                      color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          snapshot.value['imageURL'] != null
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 2.0),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius
                                                        .circular(7.5),
                                                    child: CachedNetworkImage(
                                                      height: 75.0,
                                                      width: 75.0,
                                                      imageUrl: snapshot
                                                          .value['imageURL'],
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 0.0,
                                                  height: 0.0,
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            )),
                      ),
                    );
                  });
            }
            return Text("Loading");
          },
        ),
      ),
    );
  }

  void removeBookMark(DatabaseReference ref) async {
    ref.remove();
  }
}

Future<FirebaseUser> _getUser() async {
  return await FirebaseAuth.instance.currentUser();
}

_launchURL(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

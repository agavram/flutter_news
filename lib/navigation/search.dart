import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_news/navigation/widgets.dart';
import 'package:flutter_news/utilities/api.dart';
import 'package:flutter_news/utilities/bookMarkItem.dart';
import 'package:flutter_news/utilities/fetch.dart';
import 'package:flutter_news/utilities/firebase.dart';
import 'package:flutter_news/utilities/url_launch.dart';

class Search extends StatefulWidget {
  SearchState createState() => SearchState();
}

enum FetchStatus { idle, fetching, fetched }

class SearchState extends State<Search> with SingleTickerProviderStateMixin {
  FetchStatus fetchStatus = FetchStatus.idle;
  TextEditingController textController;
  double borderWidth = 1.0;
  List<String> popularSearches = [];
  GetFromUrl fetchUrl = GetFromUrl();
  FirebaseUser user;
  var data = Map();
  DatabaseReference reference;

  @override
  void initState() {
    final FirebaseDatabase firebaseDatabase = Auth.getDatabase();
    Auth.getUser().then((user) {
      this.user = user;
      reference = firebaseDatabase.reference().child('users/' + user.uid);
      reference.onChildAdded.listen(_onEntryAdded);
      reference.onChildRemoved.listen(_onEntryRemoved);
    });
    popularSearches = [
      'Business',
      'Entertainment',
      'General',
      'Health',
      'Science',
      'Sports',
      'Technology'
    ];
    textController = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MediaQuery.of(context).size.width,
            child: TextField(
              onSubmitted: (value) {
                setState(() {
                  fetchStatus = FetchStatus.fetching;
                  handleSearch(value, false);
                });
              },
              onChanged: (value) {
                if (value == "") {
                  setState(() {
                    borderWidth = 1.0;
                  });
                } else {
                  setState(() {
                    borderWidth = 0.5;
                  });
                }
              },
              controller: textController,
              enabled: true,
              style: TextStyle(color: Colors.white, fontSize: 16.0),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(bottom: 2.0),
                border: InputBorder.none,
                hintText: 'Search for an article',
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        width: borderWidth,
                        color: Colors.white,
                        style: BorderStyle.solid))),
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              FocusScope.of(context).requestFocus(new FocusNode());
              setState(() {
                fetchStatus = FetchStatus.fetching;
                handleSearch(textController.text, false);
              });
            },
            icon: Icon(Icons.search),
          )
        ],
      ),
      body: searchScreen(),
    );
  }

  Future<dynamic> handleSearch(final search, final category) async {
    var query;
    if (search == TextEditingValue) {
      query = search.text;
    } else {
      query = search;
    }

    dynamic fetch;
    if (!category) {
      fetch = await fetchUrl.fetch('https://newsapi.org/v2/everything?q=' +
          query +
          '&sortBy=popularity&apiKey=' +
          apiKey);
          print('https://newsapi.org/v2/everything?q=' +
          query +
          '&sortBy=popularity&apiKey=' +
          apiKey);
    } else {
      fetch = await fetchUrl.fetch(
          'https://newsapi.org/v2/top-headlines?country=us' +
              query +
              '&apiKey=' +
              apiKey);
    }
    setState(() {
      fetchStatus = FetchStatus.fetched;
    });
    return fetch;
  }

  Widget searchScreen() {
    switch (fetchStatus) {
      case FetchStatus.idle:
        return Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: ListView.builder(
            // padding: EdgeInsets.only(top: 4.0, bottom: 0.0),
            itemCount: popularSearches.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  textController.text = popularSearches[index];
                  setState(() {
                    fetchStatus = FetchStatus.fetching;
                  });
                  handleSearch('&category=' + popularSearches[index], true);
                },
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      popularSearches[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.0, color: Colors.grey[700]),
                    )),
              );
            },
          ),
        );
        break;
      case FetchStatus.fetching:
        return ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return LoadingCard();
            });
        break;
      case FetchStatus.fetched:
        List<BookMarkItem> bookMarkItem = [];
        int itemCount = fetchUrl.fetchSaved()['totalResults'];
        var pageNum = 2;
        itemCount = itemCount.clamp(0, 20);
        return NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            if (!notification.leading) {
              if (fetchUrl.fetchSaved()['totalResults'] > 20) {
                int addCount = fetchUrl.fetchSaved()['totalResults'];
                addCount = addCount.clamp(0, 20);
                if (addCount != 0) {
                  handleSearch(textController.text + '&page=$pageNum', false)
                      .then((_) {
                    pageNum++;
                    setState(() {
                      itemCount += addCount;
                    });
                  });
                }
              }
            }
          },
          child: ListView.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) {
              bookMarkItem.add(BookMarkItem.fromJson(
                  fetchUrl.fetchSaved()['articles'][index]));
              return Padding(
                padding: const EdgeInsets.only(
                    left: 8.0, right: 8.0, top: 6.0, bottom: 6.0),
                child: GestureDetector(
                  onTap: () {
                    launchURL(bookMarkItem[index].articleURL);
                  },
                  child: NewsContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(children: <Widget>[
                        NewsCard(
                            showDate: false,
                            bookMarkItem: bookMarkItem[index],
                            customPopUpMenu: PopupMenuButton<int>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 20.0,
                                color: Colors.grey[700],
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (_) {
                                switch (_) {
                                  case 0:
                                    if (!data.containsKey(
                                        bookMarkItem[index].title)) {
                                      bookMark(bookMarkItem[index]);
                                    } else {
                                      BookMarkItem.removeBookMark(
                                          Auth.getDatabase()
                                              .reference()
                                              .child('users/' + user.uid)
                                              .child('/' +
                                                  data[bookMarkItem[index]
                                                      .title]));
                                    }
                                    break;
                                  case 1:
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                bool bookmarked =
                                    data.containsKey(bookMarkItem[index].title);
                                return <PopupMenuEntry<int>>[
                                  PopupMenuItem<int>(
                                    value: 0,
                                    child: Row(
                                      children: <Widget>[
                                        Icon(bookmarked
                                            ? Icons.bookmark
                                            : Icons.bookmark_border),
                                        Text(bookmarked
                                            ? "Remove bookmark"
                                            : "  Bookmark")
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ))
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        break;
    }
  }

  _onEntryAdded(Event event) {
    data[event.snapshot.value['title']] = event.snapshot.key;
  }

  void bookMark(BookMarkItem bMrkItm) async {
    reference.push().set(bMrkItm.toJson());
  }

  _onEntryRemoved(Event event) {
    data.remove(event.snapshot.value['title']);
  }
}

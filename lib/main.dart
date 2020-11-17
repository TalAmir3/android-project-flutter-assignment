import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:hello_me/userRepository.dart';
import 'package:hello_me/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';


//void main() => runApp(MyApp());

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
            body: Center(
                child: Text(snapshot.error.toString(),
                    textDirection: TextDirection.ltr)));
      }
      if (snapshot.connectionState == ConnectionState.done) {
        return MyApp();
      }
      return Center(child: CircularProgressIndicator());
        },
    );
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Welcome to Flutter',
        theme: ThemeData(
          primaryColor: Colors.red,
        ),
        home: RandomWords()
    );
  }
}


class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final List<WordPair> _suggestions = <WordPair>[];
  final _saved = Set<WordPair>();
  final TextStyle _biggerFont = const TextStyle(fontSize: 18);
  GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  double snappingHight = 0.0;
  double blurValue = 0.0;
  SnappingSheetController _snappingSheetController = SnappingSheetController();
  PickedFile _image;
  ImagePicker picker = ImagePicker();
  String profileURL;


  CollectionReference favorites = FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    profileURL = "";
    //loading = false;
  }


    getImage() async {
    PickedFile pickedFile = await picker.getImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = pickedFile;
      } else {
        print('No image selected.');
        _image = null;
      }
    });
  }

  Future<void> uploadImage(String filePath, User user) async {
    File file = File(filePath);

    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('${user.uid}/file-to-upload.png')
          .putFile(file);
    } on FirebaseException catch (e) {
      print("there was an exception uploading the image: $e");
      // e.g, e.code == 'canceled'
    }
  }

  Future<void> downloadImage(User user) async {
    //Directory appDocDir = await getApplicationDocumentsDirectory();
    //File downloadToFile = File('${appDocDir.path}/download-logo.png');

    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('${user.uid}/file-to-upload.png')
          .getDownloadURL()
          .then((value) {
            setState(() {
              profileURL = value;
            });
      });
          //.writeToFile(downloadToFile);
    } on FirebaseException catch (e) {
      print("there was a problen getting the image: $e");
      setState(() {
        profileURL = "";
      });
      // e.g, e.code == 'canceled'
    }
  }

  // Future uploadImageToFirebase(BuildContext context) async {
  //   String ImagePath = _image.path;
  //   firebase_storage.Reference firebaseStorageRef =
  //   firebase_storage.FirebaseStorage.instance.ref().child('uploads/$ImagePath');
  //   firebase_storage.UploadTask uploadTask = firebaseStorageRef.putFile(File(_image.path));
  //   firebase_storage.TaskSnapshot taskSnapshot = await uploadTask
  //       .whenComplete(() => print("done uploading1"));
  //   // taskSnapshot.ref.getDownloadURL().then(
  //   //       (value) => print("Done: $value"),
  //   // );
  // }

  Future<void> addFavorite(CollectionReference user_fav, WordPair pair){
    String p = pair.asPascalCase;
    return user_fav.add({"pair": p})
        .then((value) => print("fav add"))
        .catchError((error) => print("Failed to add pair: $error"));
  }
  
  Future<void> removeFavorite(CollectionReference user_fav, String pair) async {
    //String p = pair.toString();
    String id;
    await user_fav.get()
        .then((QuerySnapshot querySnapshot) => {
          querySnapshot.docs.forEach((doc) {
            if(doc['pair'] == pair) {
              id = doc.id;
              //print("id in if is: $id");
            }
          })
    });
    //print("id is: $id");
    user_fav.doc(id.toString())
        .delete()
        .then((value) => print("Pair Deleted"))
        .catchError((error) => print("Failed to delete user: $error"));
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    return ChangeNotifierProvider<UserRepository>(
        create: (_) => UserRepository.instance(),
      child: Consumer<UserRepository>(
        builder: (context, user, _){
          return ListTile(
            title: Text(
              pair.asPascalCase,
              style: _biggerFont,
            ),
            trailing: Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
            ),
            onTap: () {
              User current_user = user.user;
              CollectionReference user_fav;
              if(user.status == Status.Authenticated) {
                user_fav = favorites.doc(current_user.uid).collection('favorites');
                if (!alreadySaved)
                  addFavorite(user_fav, pair);
                else{
                  String p = pair.asPascalCase;
                  removeFavorite(user_fav, p);
                }
              }
              setState(() {
                if (alreadySaved) {
                  _saved.remove(pair);
                  //print(pair);
                } else {
                  _saved.add(pair);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...

          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }

  Future<void> getFavorites(CollectionReference user_fav, Set<WordPair> s, Set<WordPair> localSaved) async {
    await user_fav.get().then((QuerySnapshot querySnapshot) => {
      querySnapshot.docs.forEach((doc) {
        var d = doc['pair'].toString().split(RegExp(r"(?=[A-Z])"));
        //print("d is: $d");
        WordPair w = WordPair(d[0], d[1]);
        //print("word is: $w");
        w.asPascalCase;
        s.add(w);
      })
    }).catchError((error) => print("Failed error is : $error"));
    //localSaved.forEach((save) {save = save.asPascalCase;});
    s.addAll(localSaved);
    //s.toSet();

    print("set is: $s");

  }

  void _pushSaved() {
    //User current_user = user.user;
    //CollectionReference user_fav = favorites.doc(current_user.uid).collection('favorites');

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
            final tiles = _saved.map(
                (WordPair pair) {
              return ListTile(
                  title: Text(
                    pair.asPascalCase,
                    style: _biggerFont,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _saved.remove(pair);
                        //_saved.forEach((element) {_saved.remove(pair)});
                        (context as Element).reassemble();
                      });
                        // _scaffoldkey.currentState.showSnackBar(SnackBar(
                        //   content: Text('Deletion is not implemented yet'),
                        // ));
                      // String p = pair.toString();

                    }
                  ),
              );
            },
          );


          final divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            //key:_scaffoldkey,
            appBar: AppBar(
              //automaticallyImplyLeading: true,
              title: Text('Saved Suggestions'),
             // leading: IconButton(icon: Icon(Icons.arrow_back),
              //    onPressed: () {Navigator.pop(context);},),

            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void addPairToUI(CollectionReference user_fav) async {
    await user_fav.get()
        .then((QuerySnapshot querySnapshot) => {
      querySnapshot.docs.forEach((doc) {
        //var v = doc['pair'];
        //print("pair in doc: $v");
        //print("pair got: $p");
        var d = doc['pair'].toString().split(RegExp(r"(?=[A-Z])"));
        //print("d is: $d");
        WordPair w = WordPair(d[0], d[1]);
        print("w is: $w");
        //var a = _saved[0];
        //print("_saved[0]: $a");
        if(!_saved.contains(w)) {
          print("$w is not in set");
          //print("true");
          setState(() {
            _saved.add(w.toLowerCase());
          });
          //print(_saved);
          //print("id in if is: $id");
        }
      })
    });
  }

  void addPairInDB(CollectionReference user_fav, WordPair pair) async {
    String p = pair.asPascalCase;
    bool found = false;
    await user_fav.get()
        .then((QuerySnapshot querySnapshot) => {
      querySnapshot.docs.forEach((doc) {
        if(doc['pair'] == p) {
          found = true;
        }
      })
    });
    if(!found)
      addFavorite(user_fav, pair);
  }

  void _pushSavedAuth(UserRepository user){
    CollectionReference user_saved = favorites.doc(user.user.uid).collection('favorites');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (BuildContext context){
            return StreamBuilder(
              stream: user_saved.snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot){
                  if(!snapshot.hasData){
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  return Scaffold(
                    appBar: AppBar(title: Text("Saved Suggestion")),
                    body: ListView(
                      children: snapshot.data.docs.map((doc) {
                        return Center(
                          child: ListTile(
                            title: Text(doc['pair'], style: _biggerFont),
                            trailing: IconButton(icon: Icon(Icons.delete),
                            onPressed: () {
                              removeFavorite(user_saved, doc['pair']);
                              var d = doc['pair'].toString().split(RegExp(r"(?=[A-Z])"));
                              WordPair w = WordPair(d[0], d[1]);
                              // if(_saved.contains(w.toLowerCase())){
                              //   print("true");
                              // }
                              setState(() {
                                  _saved.remove(w.toLowerCase());
                              });
                              // print(_saved);
                            },),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
            );
          }
      )
    );
  }
  void _pushLogin(UserRepository user) async {
   await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LogIn(user: user)),
    );
   if(user.status == Status.Authenticated){
     CollectionReference user_fav = favorites.doc(user.user.uid).collection('favorites');
     addPairToUI(user_fav);
     downloadImage(user.user);
   }
  }

  // void signOut() async{
  //   print("sign out");
  //   await Provider.of<UserRepository>(context).signOut();
  // }


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserRepository>(
      create: (_) => UserRepository.instance(),
    child:Consumer<UserRepository>(
      builder: (context, user, _) {
        //String uid = user.user.uid;
        // CollectionReference user_fav = favorites.doc(uid).collection('favorites');
        // Set<WordPair> savedPairs = Set<WordPair>();
        // if (user.status == Status.Authenticated) {
        //   getFavorites(user_fav, savedPairs, _saved);
        //   //print(savedPairs);
        // } else {
        //   savedPairs = _saved;
        // }
        return Scaffold (
          key: _scaffoldkey,
          appBar: AppBar(
            title: Text('Startup Name Generator'),
            actions: [
              IconButton(icon: Icon(Icons.list), onPressed: () {
                if(user.status == Status.Authenticated){
                  CollectionReference user_saved = favorites.doc(user.user.uid).collection('favorites');
                  if(_saved.isNotEmpty){
                    for (var pair in _saved) {
                      addPairInDB(user_saved, pair);
                    }
                  }
                  //addPairToUI(user_saved);
                  _pushSavedAuth(user);
                }
                else{
                  _pushSaved();
                }
              }),
              if(user.status == Status.Authenticated)
                IconButton(icon: Icon(Icons.exit_to_app), onPressed: () {
                  print("sign out");
                  user.signOut();
                  setState(() {
                    _saved.clear();
                  });
                })
              else
                IconButton(icon: Icon(Icons.login), onPressed: () => _pushLogin(user),)
            ],
          ),
          body:  (user.status == Status.Authenticated)
          ? Stack(
            children:[
              Container(child: _buildSuggestions(),),
              BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue,),
              child: SnappingSheet(
                snappingSheetController: _snappingSheetController,
                snapPositions: [
                  SnapPosition(
                      positionPixel: 0,
                      snappingCurve: Curves.ease,
                      snappingDuration: Duration(milliseconds: 750)
                  ),
                  SnapPosition(
                      positionPixel: 100,
                      snappingCurve: Curves.ease,
                      snappingDuration: Duration(milliseconds: 750)
                  ),
                  SnapPosition(
                      positionFactor: 0.5,
                      snappingCurve: Curves.ease,
                      snappingDuration: Duration(milliseconds: 500)
                  ),
                ],
                initSnapPosition: SnapPosition(positionPixel: 0),
                onSnapBegin: () {
                  setState(() {
                    if(_snappingSheetController.currentSnapPosition ==
                        _snappingSheetController.snapPositions[0]){
                      //snappingHight = 200;
                      blurValue = 0;
                    }else{
                      //snappingHight = 0;
                      blurValue = 4;
                    }
                  });
                },
                //sheetAbove: SnappingSheetContent(
                    //child: _buildSuggestions(),
                //),
                sheetBelow: SnappingSheetContent(
                    child: Container(
                      color: Colors.white,
                      child: Row(
                        children: [
                        Material(
                          color: Colors.white,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                              child: profileURL == ""
                                  ? CircleAvatar(
                                backgroundColor: Colors.black12,
                                radius: 50,
                              )
                              : CircleAvatar(
                                backgroundImage: NetworkImage(profileURL.toString()),
                                backgroundColor: Colors.black12,
                                radius: 50,
                              )
                          ),
                        ),
                        Wrap(
                          children: [
                            Container(
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                      child: Text("${user.user.email}", style: TextStyle(fontSize: 20),)
                                  ),
                                  RaisedButton(
                                    child: Text("Change Avatar"),
                                    color: Colors.redAccent,
                                    //padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    onPressed: () async {
                                      await getImage();
                                      if(_image == null){
                                        _scaffoldkey.currentState.showSnackBar(SnackBar(
                                              content: Text('No image selected'),
                                            ));
                                      }else {
                                        await uploadImage(_image.path, user.user);
                                        await downloadImage(user.user);
                                        print(profileURL);
                                      }
                                      },
                                  )
                                ],
                              ),
                            )

                        ],)
                      ],)
                    ),
                    heightBehavior: SnappingSheetHeight.fit(),
              ),
              grabbing: InkWell(
                onTap: () {
                  setState(() {
                    if(_snappingSheetController.currentSnapPosition ==
                        _snappingSheetController.snapPositions[0]){
                      _snappingSheetController.snapToPosition(_snappingSheetController.snapPositions[1]);
                      //snappingHight = 200;
                      blurValue = 4;
                    }else{
                      //snappingHight = 0;
                      _snappingSheetController.snapToPosition(_snappingSheetController.snapPositions[0]);
                      blurValue = 0;
                    }
                  });
                },
                child: Container(
                  color: Colors.grey,
                    child: Stack(
                      children:[
                        Wrap(
                        direction: Axis.vertical,
                        //spacing: 100,
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                              child: Text(" Welcome back, ${user.user.email}",style: _biggerFont, )
                          ),

                        ],
                      ),
                        Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.fromLTRB(0, 0, 20, 0),
                          child: Icon(Icons.keyboard_arrow_up),

                        )
                      ]
                    ),

                ),
              ),
                grabbingHeight: 60,
        ),
            ),]
          )
        : _buildSuggestions(),
        );
      },
    )

      );
  }
}










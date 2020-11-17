import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:hello_me/userRepository.dart';

class LogIn extends StatefulWidget {
  final UserRepository user;
  LogIn({this.user});

  @override
  _LogInState createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  //FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController _email;
  TextEditingController _password;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: "");
    _password = TextEditingController(text: "");
    //loading = false;
  }

  @override
  Widget build(BuildContext context) {
    //final user = Provider.of<UserRepository>(context);
    return Scaffold (
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Builder(
        builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 50),
          child: Column(
            children: <Widget>[
              Text('Welcome to Startup Names Generator, pleaselog in below'),
              TextFormField(
                decoration: InputDecoration(
                    hintText: 'Email'
                ),
                controller: _email,
              ),
              TextFormField(
                decoration: InputDecoration(
                    hintText: 'Password'
                ),
                controller: _password,
                obscureText: true,
              ),
              Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                //width: 350,
                child: loading
                    ? CircularProgressIndicator()
                    : MaterialButton(
                        child: Text('Login'),
                        color: Colors.red,
                        minWidth: 350,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                        ),
                        onPressed: () async {
                          setState(() {
                            loading = true;
                          });
                          if (!await widget.user.signIn(_email.text, _password.text)) {
                            //print(loading);
                            setState(() {
                               loading = false;
                             });
                            // print("weh");
                            Scaffold.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'There was an error logging into the app'),
                              ),
                            );
                          }
                          else {
                            setState(() {
                              loading = false;
                            });
                            Navigator.pop(context);
                            // Navigator.pop(context);
                            //print("hi2");
                          }
                        },
                      ),
                ),
              Container(
                width: 350,
                child: MaterialButton(
                    child: Text('New user? Click to sign up'),
                    color: Colors.blueGrey,
                    minWidth: 350,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                    onPressed: (){
                      _settingModalBottomSheet(context,
                                          _email.text,
                                          _password.text, widget.user);
                    }
                ),
              )


            ],
          ),
        ),
        )),
      );


  }
}

void _settingModalBottomSheet(context, String email, String password, UserRepository user){
  TextEditingController _password_confirm;
  final _formKey = GlobalKey<FormState>();
  showModalBottomSheet(
      context: context,
      builder: (BuildContext bc){
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 50),
          child: Wrap(
            children: [
              Center(
                child: Text("Please confirm your password below:",
                  style: TextStyle(fontSize: 16),),),
              Form(
                key: _formKey,
                child: Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    decoration: InputDecoration(
                        hintText: 'Password'
                    ),
                    controller: _password_confirm,
                    obscureText: true,
                    validator: (val) =>
                        val != password ? 'passwords must match' : null,
                  ),
                ),
              ),
              Center(
                child: RaisedButton(
                  //padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Text('Confirm'),
                    color: Colors.blueGrey,
                    // shape: RoundedRectangleBorder(
                    //   borderRadius: BorderRadius.circular(18.0),
                    // ),
                    onPressed: () async {
                      if(_formKey.currentState.validate()){
                          if(!await user.signUp(email, password)){
                            print("There was a problem signing up");

                          }else{
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }

                      }

                    }
                    ),
              )
            ],
          ),
        );
      }
  );
}

// Container(
// child: new Wrap(
// children: <Widget>[
// new ListTile(
// leading: new Icon(Icons.music_note),
// title: new Text('Music'),
// onTap: () => {}
// ),
// new ListTile(
// leading: new Icon(Icons.videocam),
// title: new Text('Video'),
// onTap: () => {},
// ),
// ],
// ),
// );







import 'package:flutter/material.dart';
import 'package:soft_eng/screens/login.dart';
import 'package:soft_eng/screens/instructorAllFeedback.dart';
import 'package:soft_eng/screens/instructorClassView.dart';
import 'package:soft_eng/screens/instructorPastSessions.dart';

//ACCESSIBILITY TEAM
//Async
import 'dart:async';
//
//STT pub
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
//
import 'dart:io'; //Timer stuff
//TTS pub
import 'package:flutter_tts/flutter_tts.dart';

//

class InstructorIntoAllFeedback extends StatefulWidget {
  final String classTitle;
  InstructorIntoAllFeedback({String classTitle}) : this.classTitle = (classTitle != null) ? classTitle : "Class View"; //IF NULL it reports as Class View
  @override
  _InstructorIntoAllFeedbackState createState() =>
      _InstructorIntoAllFeedbackState();
}

class _InstructorIntoAllFeedbackState extends State<InstructorIntoAllFeedback> {
  //ACCESSIBILITY TEAM
  final FlutterTts flutterTts = FlutterTts(); //Set up STT class
  final SpeechToText _STTRecog = SpeechToText(); //Set up STT Class

  String audioText =
      ": Speech-To-Text Listener: say \"commands\" for more info"; //Local String for spoken results
  String StoredText = ""; //Local String for stored results
  String oldText = ""; //Old copy of Stored Text
  String internalRef = ""; //Debuging and command mode text
  bool _STTisAvailable = false; //checking for availability
  bool _STTChecked = false; //if checked for STT once
  bool commandModeSTT = true; //If in command mode
  bool multListener = false; //If for some reason there's multiple listeners
  double level = 0.0; //sound level i believe unused really.
  String lastError = ""; //Error Holder
  String _currentLocaleId = ""; //used Locale for STT
  List<LocaleName> _localeNames = []; //List of Available STT lang

  void initState() {
    super.initState();
    initSTTState();
  }

  //Fail-STT
  void _showSTTFail() {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("STT not Recongized"),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // END of Fail-STT

  //Display Commands
  void _showSTTCommands() {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("STT/TTS Commands"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Commands.'),
                Text('Logout.'),
                Text('Class View.'),
                Text('All feedback.'),
                Text('Past Session.'),
                Text('Read Screen.'),
                Text('Read Header.'),
                Text('Read Body.'),
                Text('Read Bottom.'),
              ],
            ),
          ),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                multListener = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  //END of Display Commands

  // Start up STT
  Future<void> initSTTState() async {
    if (!_STTChecked && !_STTisAvailable) {
      bool STTisAvailable = await _STTRecog.initialize(
          onError: errorListener,
          onStatus:
              statusListener); //returns if there is STT on the smart phone
      if (STTisAvailable) {
        //if it is available
        _localeNames = await _STTRecog
            .locales(); //retrieve all capable locales (all available lang)

        var systemLocale = await _STTRecog.systemLocale(); //Get current locale
        _currentLocaleId = systemLocale.localeId; //set so.
      }

      if (!mounted) return;

      setState(() {
        //Update app with STT is available
        _STTisAvailable = STTisAvailable;
        _STTChecked = true;
      });
    }
  }
  //End of Startup: STT

  //String to Command function:
  void detectKey(String key) {
    //Phrase Decoding:
    bool detectedKey = false;
    internalRef = "Command: " + key;
    if (key.toLowerCase() == "open class view" ||
        key.toLowerCase() == "class view") {
      _selectedPage = 2;
      detectedKey = true;
    } else if (key.toLowerCase() == "open all feedback" ||
        key.toLowerCase() == "all feedback" ||
        key.toLowerCase() == "open all feedbacks" ||
        key.toLowerCase() == "all feedbacks") {
      _selectedPage = 0;
      detectedKey = true;
    } else if (key.toLowerCase() == "open past sessions" ||
        key.toLowerCase() == "past sessions" ||
        key.toLowerCase() == "open pass sessions" ||
        key.toLowerCase() == "pass sessions" ||
        key.toLowerCase() == "open past session" ||
        key.toLowerCase() == "past session" ||
        key.toLowerCase() == "open pass session" ||
        key.toLowerCase() == "pass session") {
      _selectedPage = 1;
      detectedKey = true;
    } else if (key.toLowerCase() == "switch page") {
      _selectedPage = (_selectedPage + 1) % 3;
      detectedKey = true;
    } else if (key.toLowerCase() == "logout" ||
        key.toLowerCase() == "log out") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => Login()),
        (Route<dynamic> route) => false,
      );
      detectedKey = true;
    } else if (key.toLowerCase() == "help" ||
        key.toLowerCase() == "command" ||
        key.toLowerCase() == "commands") {
      if (!multListener) {
        setState(() {
          multListener = true;
        });
        _showSTTCommands();
      } else
        multListener = false;
      detectedKey = true;
    } else if (key.toLowerCase() == "read screen") {
      detectedKey = true;
      speak(allTTS: true);
    } else if (key.toLowerCase() == "read header") {
      detectedKey = true;
      speak(headerTTS: true);
    } else if (key.toLowerCase() == "read body") {
      detectedKey = true;
      speak(bodyTTS: true);
    } else if (key.toLowerCase() == "read bottom") {
      detectedKey = true;
      speak(bottomTTS: true);
    }
    if (detectedKey)
      internalRef = "Command detected: " + key;
    else
      audioText =
          "Unknown Command: " + key + " Say: \"Commands\" for list of commands";
    if (key == "") {
      audioText = "";
      StoredText = oldText;
    }
    setState(() {});
  }
  //END String to Command

  // STT functions:
  void startListening() {
    //Start STT
    oldText = StoredText; //save storedText
    if (audioText != "")
      StoredText = """$StoredText 
      $audioText."""; //put on new line
    if (StoredText.startsWith(".")) StoredText.substring(2);
    audioText = "";
    _STTRecog.listen(
        //Start listening
        onResult: resultListener, //results pushed onto resultListener function
        listenFor: Duration(seconds: 6), //doesn't really work on android
        localeId: "en-US", //which locale to listen for *English only
        onSoundLevelChange:
            soundLevelListener, //detecting sound levels for analysis
        cancelOnError:
            false, //just cancel when error, false so i can use errorListener for everything
        partialResults: true); //show words as they are found from STT
    setState(() {}); //Refresh
  }

  void stopListening() {
    //To stop STT function call
    _STTRecog.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    //To cancel STT function call
    _STTRecog.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    //Conditional: finalResult if it is correct statement, if not it would be used each time it prints partial results.

    //result Listener
    setState(() {
      if (commandModeSTT) //print STT
        audioText = "Command: ${result.recognizedWords}";
      else
        audioText = "${result.recognizedWords}"; // - ${result.finalResult}";
    });
    if (result.finalResult &&
        !commandModeSTT &&
        (result.recognizedWords.toLowerCase() == "turn on command mode")) {
      commandModeSTT = true;
      internalRef = "Command Mode is Active";
      setState(() {});
    } else if (result.finalResult && commandModeSTT) {
      _STTRecog.cancel(); //to stop old one from timing out
      setState(() {
        multListener = false;
      });
      sleep(Duration(microseconds: 250)); //slight delay to let async cancel
      detectKey(result.recognizedWords); //scan result for command
    } else if (result.finalResult)
      _STTRecog.cancel(); //to stop old one from timing out
  }

  void soundLevelListener(double level) {
    //internally display sound level
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    _STTRecog.cancel();
    //If error
    setState(() {
      lastError = "Error: ${error.errorMsg} - ${error.permanent}";
      StoredText = oldText;
      setState(() {
        level = 0.0;
      });
    });
  }

  void statusListener(String status) {
    //shows status of STT
    setState(() {
      lastError = "Status: $status";
    });
  }

  _switchLang(selectedVal) {
    //to help switch lang
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }
  // END OF STT FUNCTIONS

  //TTS FUNCTIONS
  Future<void> speak({
    String spokenByTTS = '',
    bool allTTS = false,
    bool headerTTS = false,
    bool bodyTTS = false,
    bool bottomTTS = false,
    /*
      bool buttonBodyTTS = false,
      bool buttonBottomTTS = false,
      bool audioTextTTS = false,
      bool lastErrorTTS = false,
      bool internalRefTTS = false,
      bool clearTextTTS = false,
      bool enableTextTTS = false,
      bool cancelTTS = false,
      bool stopTTS = false,
      bool buttonTTS = false,
      bool startTTS = false,
      bool underBoxTTS = false*/
  }) async {
    //WE USE ... to induce a pause between sections
    if (headerTTS || allTTS) {
      if (_selectedPage == 0) {
        //All FeedBack view
        spokenByTTS += "You are on the All FeedBack Page...";
      } else if (_selectedPage == 1) {
        //Past Session
        spokenByTTS += "You are on the Past Session Page...";
      } else if (_selectedPage == 2) {
        //Class View
        (widget.classTitle.toLowerCase() != "class view")
            ? spokenByTTS +=
                "You are on the Class View page of " + widget.classTitle + "..."
            : spokenByTTS += "You are on the Class View page...";
      }
    }
    //Body section
    if (bodyTTS || allTTS) {
      if (_selectedPage == 0) {
        spokenByTTS += "Here is the screen for all feedback...";
        spokenByTTS += "you can Sort feedback via the options shown...";
        spokenByTTS += "There is a word cloud that shows keywords...";
      } else if (_selectedPage == 1) {
        spokenByTTS += "Here is the screen for past sessions...";
        spokenByTTS += "This page shows you list of sessions...";
      } else if (_selectedPage == 2) {
        spokenByTTS += "Body Discription info list, from top to bottom:...";
        spokenByTTS += "Class Info";
        spokenByTTS += "with Class ID: " + widget.classID + "...";
        spokenByTTS += "Add meeting times in the times field:";
        spokenByTTS += "...";
        spokenByTTS += "Add Location in the location field:";
        spokenByTTS += "...";
        spokenByTTS += "Put your name in professor field: ";
        spokenByTTS += "...";
        spokenByTTS += "put Teacher Assistant names in the T A fields:";
        spokenByTTS += "...";
        spokenByTTS += "Update button on the bottom of the screen:";
        spokenByTTS += "...";
      }
    }
    if (bottomTTS || allTTS) {
      spokenByTTS += "At the bottom there are 3 buttons...";
      spokenByTTS += "Left button is All Feedback...";
      spokenByTTS += "Middle button is Past Session...";
      spokenByTTS += "Right button is Class View...";
    }
    await flutterTts.setLanguage("en-US"); //English only
    await flutterTts.speak(spokenByTTS);
  }
  //END OF TTS FUNCTIONS

  //END ACCESSIBILITY TEAM
  int _selectedPage = 0;
  final _pageOptions = [
    InstructorAllFeedback(),
    InstructorPastSessions(),
    InstructorClassView(),
    //Login(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('CLASS NAME'),
      //   centerTitle: true,
      // ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _pageOptions.elementAt(_selectedPage),
          ),
          Row(
            children: <Widget>[
              IconButton(
                // Start STT
                icon: Icon(_STTisAvailable
                    ? (!_STTRecog.isListening ? Icons.mic : Icons.pause)
                    : Icons.mic_off),
                tooltip: audioText,
                onPressed: !_STTRecog.isListening
                    ? (!_STTisAvailable ? _showSTTFail : startListening)
                    : stopListening,
              ),
              Expanded(child: Text(audioText))
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: lightPurple,
        currentIndex: _selectedPage,
        onTap: (int index) {
          setState(() {
            _selectedPage = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.chat,
              color: green,
            ),
            title: Text(
              'All Feedback',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.library_books,
              color: green,
            ),
            title: Text(
              'Past Sessions',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.class_,
              color: green,
            ),
            title: Text(
              'Class View',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

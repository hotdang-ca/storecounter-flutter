import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

Injector injector;

class SocketService {
  static const String TENANT_KEY = 'tenant';
  static const String COUNT_KEY = 'count';

  static const String EMIT_COUNT_EVENT = 'count';
  static const String EMIT_GET_COUNT_EVENT = 'getCount';

  static const String COUNT_EVENT = 'count';
  static const String CONNECT_EVENT = 'connect';
  static const String DISCONNECT_EVENT = 'disconnect';

  static const String PREF_KEY = 'ca.fourandahalfgiraffes.inandout.channel';

  IO.Socket socket;
  int count = 0;
  String channel;
  String socketServer;
  bool isConnected = false;

  subscribe(String server, String channel) {
    this.channel = channel;
    this.socketServer = server;
    this.isConnected = false;
    this.socket.emit(EMIT_GET_COUNT_EVENT, {
      TENANT_KEY: this.channel,
    });
  }

  announceCount() {
    if (this.socketServer == null) {
      print('Socket has no server');
      return;
    }

    this.socket.emit(EMIT_COUNT_EVENT, {
      TENANT_KEY: this.channel,
      COUNT_KEY: this.count,
    });
  }

  setCount(int count) {
    this.count = count;
    this.announceCount();
  }

  increment() {
    this.count = this.count + 1;
    this.announceCount();
  }

  decrement() {
    if (this.count == 0) {
      this.count = 0;
    } else {
      this.count = this.count - 1;
    }

    this.announceCount();
  }

  createSocketConnection(String server, String channel) {
    // TODO: only here because we call createSocketConnection in Widget.build
    if (this.isConnected) {
      return;
    }

    this.socketServer = server;
    this.channel = channel;

    if (this.socket != null) {
      this.socket.clearListeners();
    }

    this.socket = IO.io(this.socketServer, <String, dynamic>{
      'transports': ['websocket'],
    });
    this.isConnected = true;

    this.socket.on(CONNECT_EVENT, (_) {
      this.socket.emit(EMIT_GET_COUNT_EVENT, {
        TENANT_KEY: this.channel,
      });
    });

    this.socket.on(COUNT_EVENT, (data) {
      if (data[TENANT_KEY] == this.channel) {
        this.count = data[COUNT_KEY];
      }
    });

    this.socket.on(DISCONNECT_EVENT, (_) => print('Disconnected'));
  }
}

class DependencyInjection {
  Injector initialise(Injector injector) {
    injector.map<SocketService>((i) => SocketService(), isSingleton: true);
    return injector;
  }
}

class AppInitializer {
  initialise(Injector injector) async {}
}

void main() async {
  DependencyInjection().initialise(Injector.getInjector());
  injector = Injector.getInjector();
  await AppInitializer().initialise(injector);

  runApp(InAndOutAppContainer());
}
// green: 255, 93, 164, 146
// blue: 255, 69, 122, 164
// blue:
class InAndOutAppContainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In and Out',
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 69, 122, 164)
      ),
      home: InAndOut(
        title: 'In and Out', // TODO: base on some configuration
        channel: '', // TODO: base on some configuration
        socketServer: 'https://storecounter.hotdang.ca', // TODO: base on some configuration
      ),
    );
  }
}

class InAndOut extends StatefulWidget {
  InAndOut(
      {
        Key key,
        @required this.title,
        @required this.channel,
        @required this.socketServer
      }) : super(key: key);

  final String title;
  final String channel;
  final String socketServer;

  @override
  _InAndOutAppState createState() => _InAndOutAppState();
}

class _InAndOutAppState extends State<InAndOut> {
  int _counter = 0;
  String _channel = '';
  bool _isListening = false;
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = new TextEditingController(text: widget.channel);
    _loadChannelName();
  }

  void _loadChannelName() async {
    final prefs = await SharedPreferences.getInstance();
    var channel = prefs.getString(SocketService.PREF_KEY) ?? '';

    setState(() {
      _channel = channel;
      this._controller.text = channel;
      socketService.subscribe(socketService.socketServer, channel);
      _isListening = false;
    });
  }

  final SocketService socketService = injector.get<SocketService>();

  void _setChannelName(newChannel) async {
    socketService.subscribe(socketService.socketServer, newChannel);

    // persist
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(SocketService.PREF_KEY, newChannel);

    setState(() {
      _channel = newChannel;
      _isListening = false;
    });
  }

  void _incrementCounter() {
    socketService.increment();

    setState(() {
      _counter++;
    });
  }

  void _decrementCounter() {
    socketService.decrement();

    setState(() {
      if (_counter == 0) {
        _counter = 0;
        return;
      }

      _counter--;
    });
  }
  void _clearChannel() {
    socketService.subscribe(socketService.socketServer, '');
    _controller.text = '';

    setState(() {
      _channel = '';
      _isListening = false;
    });
  }

  void _clearCounter() {
    socketService.setCount(0);

    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    /**
     * TODO: maybe there is a better place to connect?
     * In the meantime, we are at least peventing too many connections.
     */
    final SocketService socketService = injector.get<SocketService>();

    socketService.createSocketConnection(widget.socketServer, _channel);

    // TODO: see above todo. obviously need a better place to set this up, AND have access to lifecycle events
    if (!_isListening) {
      socketService.socket.on(SocketService.COUNT_EVENT, (data) {
        var channel = data[SocketService.TENANT_KEY];
        var count = data[SocketService.COUNT_KEY];

        if (channel == _channel) {
          setState(() {
            _counter = count;
          });
        }
      });

      _isListening = true;
    }

    return Scaffold(
      drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                child: Column(
                  children: <Widget>[
                    Text('In And Out', style: TextStyle(color: Colors.white, fontSize: 32)),
                    Text('A retail store counter app', style: TextStyle(color: Colors.white, fontSize: 22)),
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                ),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 69, 122, 164),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(8),
                        border: InputBorder.none,
                        hintText: 'Specify a Channel Name',
                        labelText: 'Channel Name',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            _clearChannel();
                          }
                        )),
                      style: TextStyle(color: Colors.black, fontSize: 21),
                      onChanged: _setChannelName,
                      controller: _controller,
                    ),
                    RaisedButton(
                      textColor: Colors.white,
                      color: Color.fromARGB(255, 93, 164, 146),
                      onPressed: () => Navigator. pop(context),
                      padding: const EdgeInsets.all(16.0),

                      child: const Text(
                          'SET CHANNEL',
                          style: TextStyle(fontSize: 18)
                      ),
                    ),
                    Text(
                        '\nInstructions\n',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    Text(
                      '1. Set your location name. This can be anything, but we recommend it be unique, eg, com.hotdang.retailstore.\n',
                    ),
                    Text(
                      '2. Start hitting the + or - to increment or decrement the counter. This can be visitors coming to or leaving you store, or anything you want to count.\n'
                    ),
                    Text(
                      '3. Open the app on another device (or visit https://storecounter.hotdang.ca), and put in the same location name.\n'
                    ),
                    Text(
                      '4. Voila! Both instances will share the same counter!\n'
                    ),
                ]
              ),
            )
          ]
        ),
      ),
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(
              height: 8,
            ),
            Center(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    child: Text(
                      'Increment or decrement the population, or anything you want to count!',
                      style: Theme.of(context).textTheme.caption,
                    ),
                    width: 250,
                  ),
                  SizedBox(
                    child: Text(
                      '$_channel',
                      style: Theme.of(context).textTheme.headline4,
                    )
                  ),
                  SizedBox(
                    height: 32,
                  ),
                  Text(
                      'Population',
                        style: Theme.of(context).textTheme.overline,
                  ),
                  Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ],
              )
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Center(
                      child: Ink(
                          decoration: const ShapeDecoration(
                              shape: CircleBorder(),
                              color: Color.fromARGB(255, 93, 164, 146),
                          ),
                          child: IconButton(
                            onPressed: _incrementCounter,
                            icon: Icon(Icons.add),
                            iconSize: 128,
                            tooltip: 'Add One',
                            color: Colors.white,
                          )
                      )
                  ),
                  Center(
                      child: Ink(
                          decoration: const ShapeDecoration(
                              shape: CircleBorder(),
                              color: Color.fromARGB(255, 69, 122, 164),
                          ),
                          child: IconButton(
                            onPressed: _decrementCounter,
                            icon: Icon(Icons.remove),
                            iconSize: 128,
                            color: Colors.white,
                            tooltip: 'Remove One',
                          )
                      )
                  ),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: RaisedButton(
                  onPressed: _clearCounter,
                  textColor: Colors.white,
                  color: Colors.black45,
                  padding: const EdgeInsets.all(16.0),
                  child: const Text(
                      'CLEAR',
                      style: TextStyle(fontSize: 18)
                  ),
                )
              )
            )
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/screens/loading_screen.dart';
import 'package:nove_console_article/screens/scan_screen.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const Root(),
    );
  }
}

class Root extends HookWidget {
  const Root({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var emplacements = useState<List<Emplacement>?>(null);
    var token = useState<String?>(null);
    var showPassword = useState(false);
    var controller = useState(TextEditingController());

    login() async {
      showPassword.value = false;
      final filePath =
          '${(await getApplicationDocumentsDirectory()).path}/password.txt';
      var file = await File(filePath).create(recursive: true);
      var password = await file.readAsString();
      if (password == "") {
        showPassword.value = true;
        return false;
      }
      var response =
          await http.post(Uri.https('api.nove.fr', '/authentication-token'),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: jsonEncode(<String, String>{
                'identifier': 'admin',
                'password': password,
              }));
      if (response.statusCode == 200) {
        dynamic body = jsonDecode(response.body);
        token.value = body['token'];
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
        showPassword.value = true;
      }
      return false;
    }

    loadEmplacements() async {
      var response = await http.get(
          Uri.https('api.nove.fr', '/api/f_depotempls/dp_codes'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer ${token.value}'
          });
      if (response.statusCode == 200) {
        dynamic body = jsonDecode(response.body);
        List<Emplacement> newEmplacements = [];
        for (var emplacement in body['emplacements']) {
          newEmplacements.add(Emplacement.fromJson(emplacement));
        }
        emplacements.value = newEmplacements;
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
      }
      return false;
    }

    init() async {
      bool logged = await login();
      if (logged) {
        await loadEmplacements();
      }
    }

    changePassword() async {
      final filePath =
          '${(await getApplicationDocumentsDirectory()).path}/password.txt';
      var file = File(filePath);
      await file.writeAsString(controller.value.text);
      init();
    }

    useEffect(() {
      init();
      return null;
    }, []);

    return SafeArea(
      child: emplacements.value == null
          ? showPassword.value == true
              ? Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 250,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextField(
                            controller: controller.value,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Password',
                            ),
                            onSubmitted: (String value) {
                              changePassword();
                            },
                          ),
                          ElevatedButton(
                            onPressed: () {
                              changePassword();
                            },
                            child: const Text('Valider'),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : const LoadingScreen()
          : ScanScreen(emplacements: emplacements.value!, token: token.value!),
    );
  }
}

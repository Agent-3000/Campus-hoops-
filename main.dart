import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const CampusHoopsApp());

class CampusHoopsApp extends StatelessWidget {
  const CampusHoopsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Campus Hoops Editor',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    home: const EditorPage(),
  );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});
  @override State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Map<String,dynamic>? data;
  List<Map<String,dynamic>> teams = [];
  Map<String,dynamic>? team;
  File? source;
  String status = 'Open a .campushoops save';
  final Map<String,Uint8List> otherFiles = {};

  List<Map<String,dynamic>> findTeams(dynamic x) {
    final out=<Map<String,dynamic>>[];
    if (x is Map) {
      if (x['name'] is String && x['players'] is List) {
        out.add(Map<String,dynamic>.from(x));
      }
      for (final v in x.values) out.addAll(findTeams(v));
    } else if (x is List) {
      for (final v in x) out.addAll(findTeams(v));
    }
    return out;
  }

  Future<void> openSave() async {
    final result=await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['campushoops'], withData: true);
    if (result==null) return;
    try {
      final bytes=result.files.single.bytes ?? await File(result.files.single.path!).readAsBytes();
      final archive=ZipDecoder().decodeBytes(bytes);
      final session=archive.files.firstWhere((f)=>f.name=='session.json.gz');
      final gz=GZipDecoder().decodeBytes(session.content as List<int>);
      data=jsonDecode(utf8.decode(gz));
      otherFiles.clear();
      for(final f in archive.files) {
        if(f.name!='session.json.gz' && f.isFile) otherFiles[f.name]=Uint8List.fromList(f.content as List<int>);
      }
      teams=findTeams(data);
      setState(() {
        source=File(result.files.single.path ?? '');
        status='Loaded ${result.files.single.name} • ${teams.length} teams';
        team=teams.where((t)=>t['name']=='Jackson State').cast<Map<String,dynamic>?>().firstOrNull
          ?? (teams.isEmpty?null:teams.first);
      });
    } catch(e) {
      _error('Could not open save: $e');
    }
  }

  void _error(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));

  void editPlayer(Map<String,dynamic> p) {
    final h=TextEditingController(text:'${p['height'] ?? ''}');
    final o=TextEditingController(text:'${p['overallRating'] ?? ''}');
    showDialog(context:context,builder:(_)=>AlertDialog(
      title:Text('${p['name'] ?? 'Player'}'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:h,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'Height value (example: 74 = 6\'2")')),
        TextField(controller:o,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'Overall rating')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        FilledButton(onPressed:(){
          final hv=int.tryParse(h.text), ov=int.tryParse(o.text);
          if(hv==null||ov==null){_error('Enter numeric values.');return;}
          p['height']=hv; p['overallRating']=ov;
          Navigator.pop(context); setState((){});
        },child:const Text('Apply'))
      ],
    ));
  }

  void all99() {
    if(team==null)return;
    final ps=team!['players'];
    if(ps is List) for(final raw in ps) {
      if(raw is! Map) continue;
      final p=Map<String,dynamic>.from(raw);
      p.forEach((k,v){
        if(v is num && (k.toLowerCase().contains('rating') ||
          ['insideShooting','outsideShooting','handling','passing','rebounding'].contains(k))) raw[k]=99;
      });
      if(raw.containsKey('overallRating')) raw['overallRating']=99;
    }
    setState((){});
  }

  Future<void> saveAs() async {
    if(data==null) return;
    final dir=await getTemporaryDirectory();
    final gzPath='${dir.path}/session.json.gz';
    final gz=GZipEncoder().encode(utf8.encode(jsonEncode(data!)));
    await File(gzPath).writeAsBytes(gz!);
    final out=await FilePicker.platform.saveFile(
      dialogTitle:'Save Campus Hoops file',
      fileName:'edited_campus_hoops.campushoops');
    if(out==null)return;

    final zip=Archive();
    for(final e in otherFiles.entries) zip.addFile(ArchiveFile(e.key,e.value.length,e.value));
    zip.addFile(ArchiveFile('session.json.gz',gz!.length,gz));
    final encoded=ZipEncoder().encode(zip);
    await File(out).writeAsBytes(encoded!);
    setState(()=>status='Saved: $out');
  }

  @override Widget build(BuildContext context) {
    final players=(team?['players'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Scaffold(
      appBar:AppBar(title:const Text('Campus Hoops Save Editor'),actions:[
        IconButton(onPressed:openSave,icon:const Icon(Icons.folder_open)),
        IconButton(onPressed:saveAs,icon:const Icon(Icons.save))
      ]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          Row(children:[
            Expanded(child:DropdownButton<Map<String,dynamic>>(
              isExpanded:true,value:team, hint:const Text('Select team'),
              items:teams.map((t)=>DropdownMenuItem(value:t,child:Text('${t['name']}'))).toList(),
              onChanged:(v)=>setState(()=>team=v))),
            const SizedBox(width:10),
            FilledButton(onPressed:team==null?null:all99,child:const Text('Set Team to 99'))
          ]),
          Align(alignment:Alignment.centerLeft,child:Text(status))
        ])),
        Expanded(child:players.isEmpty
          ? const Center(child:Text('Open a save and select a team.'))
          : ListView.builder(itemCount:players.length,itemBuilder:(c,i){
              final p=players[i];
              return ListTile(
                title:Text('${p['name'] ?? 'Unknown'}'),
                subtitle:Text('${p['position'] ?? ''} • Height: ${p['height'] ?? '-'}'),
                trailing:Text('OVR ${p['overallRating'] ?? '-'}'),
                onTap:()=>editPlayer(p));
            }))
      ]),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:saveAs,icon:const Icon(Icons.save),label:const Text('Save As'))
    );
  }
}

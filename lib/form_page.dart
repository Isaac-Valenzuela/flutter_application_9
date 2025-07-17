import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  final tituloController = TextEditingController();
  String estado = 'pendiente';
  File? imagen;
  bool loading = false;

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        imagen = File(pickedFile.path);
      });
    }
  }

  Future<String?> subirImagen(File file) async {
  final supabase = Supabase.instance.client;
  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
  final path = await supabase.storage.from('fotos').upload(fileName, file);
  if (path != null && path.isNotEmpty) {
    final url = supabase.storage.from('fotos').getPublicUrl(fileName);
    return url;
  }
  return null;
}

  Future<void> guardarTarea() async {
  setState(() => loading = true);
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  String? fotoUrl;
  if (imagen != null) {
    fotoUrl = await subirImagen(imagen!);
  }

  // Insertar en la tabla tareas y obtener el id generado
  final resp = await supabase.from('tareas').insert({
    'usuario_id': userId,
    'titulo': tituloController.text,
    'estado': estado,
    'hora_publicacion': DateTime.now().toIso8601String(),
    'foto_url': fotoUrl ?? '',
  }).select('id');

  // Obtener el id de la tarea recién creada
  final tareaId = resp != null && resp.isNotEmpty ? resp[0]['id'] : null;

  // Insertar en la tabla tareas_compartidas si se obtuvo el id
  if (tareaId != null) {
    await supabase.from('tareas_compartidas').insert({
      'tarea_id': tareaId,
      'usuario_id': userId,
    });
  }

  setState(() => loading = false);
  if (mounted) Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Tarea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: tituloController,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (value) => value == null || value.isEmpty ? 'Ingresa un título' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: estado,
                  items: const [
                    DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'completada', child: Text('Completada')),
                  ],
                  onChanged: (value) => setState(() => estado = value ?? 'pendiente'),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 16),
                imagen != null
                    ? Image.file(imagen!, width: 120, height: 120, fit: BoxFit.cover)
                    : const Icon(Icons.image, size: 120, color: Colors.grey),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galería'),
                      onPressed: () => pickImage(ImageSource.gallery),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Cámara'),
                      onPressed: () => pickImage(ImageSource.camera),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              guardarTarea();
                            }
                          },
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('Guardar tarea'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
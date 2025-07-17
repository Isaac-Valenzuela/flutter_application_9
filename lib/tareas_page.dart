import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TareasPage extends StatefulWidget {
  const TareasPage({super.key});

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> tareasUsuario = [];
  List<Map<String, dynamic>> tareasCompartidas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarTareas();
  }

  Future<void> cargarTareas() async {
    setState(() => loading = true);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        tareasUsuario = [];
        tareasCompartidas = [];
        loading = false;
      });
      return;
    }

    // Tareas del usuario (de la tabla tareas)
    final respUsuario = await supabase
        .from('tareas')
        .select()
        .eq('usuario_id', userId);

    // Tareas compartidas (de la tabla tareas_compartidas)
    final respCompartidasIds = await supabase
        .from('tareas_compartidas')
        .select('tarea_id')
        .eq('usuario_id', userId);

    List<Map<String, dynamic>> tareasCompartidasTemp = [];
    if (respCompartidasIds != null && respCompartidasIds.isNotEmpty) {
      final ids = respCompartidasIds.map((e) => e['tarea_id']).toList();
      final respTareasCompartidas = await supabase
          .from('tareas')
          .select()
          .inFilter('id', ids); // <-- método correcto
      tareasCompartidasTemp = List<Map<String, dynamic>>.from(
        respTareasCompartidas,
      );
    }

    setState(() {
      tareasUsuario = List<Map<String, dynamic>>.from(respUsuario);
      tareasCompartidas = tareasCompartidasTemp;
      loading = false;
    });
  }

  Widget tareaTile(Map<String, dynamic> tarea) {
    final esCompletada = tarea['estado'] == 'completada';
    final fotoUrl = tarea['foto_url'] ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: fotoUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fotoUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 48),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              )
            : const Icon(Icons.image, size: 48),
        title: Text(tarea['titulo'] ?? 'Sin título'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: ${tarea['estado'] ?? 'Desconocido'}'),
            if (tarea['hora_publicacion'] != null)
              Text(
                'Publicado: ${DateTime.tryParse(tarea['hora_publicacion'].toString())?.toLocal().toString().substring(0, 16) ?? tarea['hora_publicacion'].toString()}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Checkbox(
          value: esCompletada,
          onChanged: (value) async {
            if (value != null) {
              await supabase
                  .from('tareas')
                  .update({'estado': value ? 'completada' : 'pendiente'})
                  .eq('id', tarea['id']);
              cargarTareas();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tus tareas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...tareasUsuario.map(tareaTile),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tareas compartidas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...tareasCompartidas.map(tareaTile),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/form');
        },
        child: const Icon(Icons.add),
        tooltip: 'Agregar nueva tarea',
      ),
    );
  }
}

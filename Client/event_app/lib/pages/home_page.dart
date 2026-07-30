import 'package:flutter/material.dart';
import 'create_event.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
   return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        centerTitle: true
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        
        focusColor: Theme.of(context).colorScheme.primaryContainer,
        onPressed: (){
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEvent() ));
      },
      child: Icon(Icons.add_circle_outline)
      ),
    

      
    );
  }
} 
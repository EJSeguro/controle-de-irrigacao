import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final email = auth.currentEmail ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Irrigação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Center(
        child: Text('Bem-vindo, $email!'),
      ),
    );
  }
}

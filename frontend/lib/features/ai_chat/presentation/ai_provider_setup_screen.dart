import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/features/ai_chat/data/ai_config_repository.dart';
import 'package:formora/features/ai_chat/data/ai_provider_registry.dart';

class AiProviderSetupScreen extends ConsumerStatefulWidget {
  const AiProviderSetupScreen({super.key});

  @override
  ConsumerState<AiProviderSetupScreen> createState() => _AiProviderSetupScreenState();
}

class _AiProviderSetupScreenState extends ConsumerState<AiProviderSetupScreen> {
  final _keyController = TextEditingController();
  String _selectedProvider = 'gemini';
  String _selectedModel = 'gemini-1.5-flash';
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  // No hardcoded keys allowed in production code

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final config = ref.read(aiConfigRepositoryProvider);
    final activeId = config.activeProviderId ?? 'gemini';
    final key = await config.getApiKey(activeId);
    final model = config.getSelectedModel(activeId) ?? 'gemini-1.5-flash';

    setState(() {
      _selectedProvider = activeId;
      _selectedModel = model;
      _keyController.text = key ?? '';
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResult = 'Please enter an API Key';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final registry = ref.read(aiProviderRegistryProvider);
    final error = await registry.testProvider(_selectedProvider, key);

    setState(() {
      _testing = false;
      _testSuccess = error == null;
      _testResult = error ?? 'Connection successful!';
    });
  }

  Future<void> _saveConfig() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    final registry = ref.read(aiProviderRegistryProvider);
    await registry.configureProvider(
      providerId: _selectedProvider,
      apiKey: key,
      model: _selectedModel,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Provider settings saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  List<String> _getModelsForProvider(String providerId) {
    if (providerId == 'gemini') {
      return ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash'];
    } else if (providerId == 'openai') {
      return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'];
    } else if (providerId == 'anthropic') {
      return ['claude-3-5-sonnet', 'claude-3-5-haiku'];
    } else {
      return ['meta-llama/llama-3-70b-instruct', 'mistralai/mixtral-8x7b-instruct'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final registry = ref.read(aiProviderRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Providers Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select AI Engine',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: registry.allProviders.map((prov) {
                return DropdownMenuItem(
                  value: prov.id,
                  child: Row(
                    children: [
                      Text(prov.emoji),
                      const SizedBox(width: 8),
                      Text(prov.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedProvider = val;
                    final models = _getModelsForProvider(val);
                    _selectedModel = models.first;
                    _keyController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'Model Selection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _getModelsForProvider(_selectedProvider).map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedModel = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'API Credentials',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 24),

            // Connection testing result
            if (_testResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error,
                      color: _testSuccess == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess == true ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    child: _testing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 50),
                    ),
                    child: const Text('Save & Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

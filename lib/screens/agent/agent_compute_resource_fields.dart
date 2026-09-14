import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class AgentComputeResourceFields extends StatelessWidget {
  final TextEditingController cpuController;
  final TextEditingController memoryController;
  final TextEditingController timeoutController;
  final TextEditingController gpuCountController;
  final TextEditingController gpuMemoryController;
  final bool enabled;

  const AgentComputeResourceFields({
    super.key,
    required this.cpuController,
    required this.memoryController,
    required this.timeoutController,
    required this.gpuCountController,
    required this.gpuMemoryController,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _fields(context, [
        (cpuController, 'CPU cores'),
        (memoryController, 'Memory (MiB)'),
        (timeoutController, 'Timeout (seconds)'),
      ]),
      const SizedBox(height: 8),
      _fields(context, [
        (gpuCountController, 'GPU count'),
        (gpuMemoryController, 'Minimum GPU memory (MiB/card)'),
      ]),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'NVIDIA CUDA physical GPUs. Memory selects cards with enough free VRAM; it does not set a memory limit.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _fields(
    BuildContext context,
    List<(TextEditingController, String)> fields,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 480;
      final width = narrow
          ? constraints.maxWidth
          : (constraints.maxWidth - 8 * (fields.length - 1)) / fields.length;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (controller, label) in fields)
            SizedBox(
              width: width,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr(label),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ],
      );
    },
  );
}

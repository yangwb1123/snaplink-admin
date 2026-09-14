part of 'agent_operations_screen.dart';

mixin _AgentOperationsComputeState on State<AgentOperationsScreen> {
  final TextEditingController _computeArgvController = TextEditingController();
  final TextEditingController _computeWorkdirController = TextEditingController(
    text: '.',
  );
  final TextEditingController _computeCpuController = TextEditingController(
    text: '1',
  );
  final TextEditingController _computeMemoryController = TextEditingController(
    text: '0',
  );
  final TextEditingController _computeGpuCountController =
      TextEditingController(text: '0');
  final TextEditingController _computeGpuMemoryController =
      TextEditingController(text: '0');
  final TextEditingController _computeTimeoutController = TextEditingController(
    text: '60',
  );
  final TextEditingController _computeOsController = TextEditingController();
  final TextEditingController _computeArchitectureController =
      TextEditingController();
  final TextEditingController _computeRuntimesController =
      TextEditingController();
  AgentWorkspaceSelection _workspaceSelection = const AgentWorkspaceSelection();
  final Map<String, String> _workspaceUploadKeys = {};
  final Map<String, String> _computeIdempotencyKeys = {};
  final Map<String, AgentComputeTask> _taskDetails = {};
  final Set<String> _cancellingTaskIds = {};
  final Set<String> _loadingTaskDetails = {};
  List<AgentDevice> _devices = const [];
  List<AgentComputeTask> _computeTasks = const [];
  Object? _deviceFailure;
  Object? _taskFailure;
  Object? _taskActionFailure;
  String? _computeFormError;
  String _targetDeviceId = '';
  bool _devicesLoading = false;
  bool _devicesBusy = false;
  bool _devicesPending = false;
  bool _devicesHaveMore = false;
  bool _tasksLoading = false;
  bool _tasksBusy = false;
  bool _tasksHaveMore = false;
  bool _submittingTask = false;
  bool _deviceScopeMissing = false;
  bool _taskReadScopeMissing = false;
  bool _taskWriteScopeMissing = false;
  bool _taskCancelScopeMissing = false;
  int _deviceGeneration = 0;
  int _taskGeneration = 0;
  String? _deviceCursor;
  String? _taskCursor;

  void _disposeComputeControllers() {
    _computeArgvController.dispose();
    _computeWorkdirController.dispose();
    _computeCpuController.dispose();
    _computeMemoryController.dispose();
    _computeGpuCountController.dispose();
    _computeGpuMemoryController.dispose();
    _computeTimeoutController.dispose();
    _computeOsController.dispose();
    _computeArchitectureController.dispose();
    _computeRuntimesController.dispose();
  }
}

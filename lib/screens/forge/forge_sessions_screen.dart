import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/forge_change_cursor_store.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_oauth_token_refresh.dart';
import 'package:sso_admin/services/product_api_origin.dart';
import 'package:sso_admin/services/browser_navigation.dart';

part 'forge_sessions_screen_view.dart';
part 'forge_sessions_screen_helpers.dart';
part 'forge_runs_panel.dart';

class ForgeSessionsScreen extends StatefulWidget {
  final String accessToken;
  final String apiOrigin;
  final http.Client? httpClient;
  final http.Client? oauthHttpClient;
  final Duration oauthRevocationTimeout;

  const ForgeSessionsScreen({
    super.key,
    required this.accessToken,
    required this.apiOrigin,
    this.httpClient,
    this.oauthHttpClient,
    this.oauthRevocationTimeout = const Duration(seconds: 5),
  });

  @override
  State<ForgeSessionsScreen> createState() => _ForgeSessionsScreenState();
}

class _ForgeSessionsScreenState extends State<ForgeSessionsScreen>
    with WidgetsBindingObserver {
  late final ForgeConversationsApi _api;
  late final ForgeOAuthTokenRefresh _tokenRefresh;
  late final ForgeChangeCursorStore _changeCursorStore;
  late final Future<void> _cursorReady;
  final _titleController = TextEditingController();
  final _scopeIDController = TextEditingController();
  final _promptController = TextEditingController();
  List<ForgeOwnedConversation> _conversations = const [];
  List<ForgeConversationPrompt> _prompts = const [];
  List<ForgeConversationRun> _runs = const [];
  List<ForgeRunTimelineEvent> _runEvents = const [];
  ForgeOwnedConversation? _selected;
  ForgeConversationRun? _selectedRun;
  ForgePromptCursor? _promptCursor;
  ForgeRunCursor? _runCursor;
  String? _nextAfterID;
  String _scopeKind = 'global';
  String? _conversationError;
  String? _promptError;
  String? _createError;
  String? _appendError;
  String? _changeError;
  String? _runError;
  String? _runTimelineError;
  _PendingCreate? _pendingCreate;
  _PendingPrompt? _pendingPrompt;
  bool _loadingConversations = false;
  bool _loadingPrompts = false;
  bool _creating = false;
  bool _appending = false;
  bool _hasMoreConversations = false;
  bool _hasMorePrompts = false;
  bool _loadingRuns = false;
  bool _loadingRunTimeline = false;
  bool _hasMoreRuns = false;
  bool _hasMoreRunEvents = false;
  int _changeCursor = 0;
  bool _syncingChanges = false;
  Timer? _changeSyncTimer;
  int _promptGeneration = 0;
  int _runGeneration = 0;
  int _runTimelineGeneration = 0;
  int _runTimelineSequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tokenRefresh = ForgeOAuthTokenRefresh(
      baseUrl: ProductApiOrigin.baseUrl,
      httpClient: widget.oauthHttpClient,
      revocationTimeout: widget.oauthRevocationTimeout,
    );
    _api = ForgeConversationsApi(
      baseUrl: widget.apiOrigin,
      accessToken: widget.accessToken,
      accessTokenProvider: () =>
          Session.readForClient(ForgeConversationsOAuth.clientId),
      refreshAccessToken: _tokenRefresh.refreshAfterUnauthorized,
      httpClient: widget.httpClient,
    );
    _changeCursorStore = ForgeChangeCursorStore(
      accessToken: widget.accessToken,
      apiOrigin: widget.apiOrigin,
      clientId: ForgeConversationsOAuth.clientId,
      resource: ForgeConversationsOAuth.resource,
    );
    _cursorReady = _restoreChangeCursor();
    _refreshConversations();
    _startChangeSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopChangeSyncTimer();
    _api.close();
    _tokenRefresh.close();
    _titleController.dispose();
    _scopeIDController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChangeSyncTimer();
      unawaited(_refreshAndSync());
      return;
    }
    _stopChangeSyncTimer();
  }

  void _startChangeSyncTimer() {
    if (_changeSyncTimer != null) return;
    _changeSyncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_syncChanges()),
    );
  }

  void _stopChangeSyncTimer() {
    _changeSyncTimer?.cancel();
    _changeSyncTimer = null;
  }

  Future<bool> _refreshConversations({
    bool loadMore = false,
    String? selectID,
  }) async {
    if (_loadingConversations && !loadMore) return false;
    setState(() {
      _loadingConversations = true;
      _conversationError = null;
    });
    try {
      final page = await _api.listConversations(
        afterID: loadMore ? _nextAfterID : null,
      );
      if (!mounted) return false;
      final merged = _mergeConversations(
        incoming: page.conversations,
        existing: _conversations,
        append: loadMore,
      );
      final wantedID = selectID ?? _selected?.conversation.id;
      final selected =
          _findConversation(merged, wantedID) ??
          _selected ??
          (merged.isEmpty ? null : merged.first);
      setState(() {
        _conversations = merged;
        _nextAfterID = page.nextAfterID;
        _hasMoreConversations = page.hasMore && page.nextAfterID != null;
        _selected = selected;
        _loadingConversations = false;
      });
      if (!loadMore && selected != null) {
        await _loadPrompts(selected.conversation.id);
        return _loadRuns(selected.conversation.id);
      } else if (selected == null) {
        setState(() {
          _prompts = const [];
          _promptCursor = null;
          _hasMorePrompts = false;
          _runs = const [];
          _runCursor = null;
          _hasMoreRuns = false;
          _selectedRun = null;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _loadingRuns = false;
          _loadingRunTimeline = false;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      _clearSessionIfUnauthorized(error);
      setState(() {
        _conversationError = _friendlyError(
          error,
          'Could not load Forge sessions.',
        );
        _loadingConversations = false;
      });
      return false;
    }
  }

  Future<void> _refreshAndSync() async {
    await _syncChanges();
    if (mounted) await _refreshConversations();
  }

  Future<void> _syncChanges() async {
    if (_syncingChanges || !mounted) return;
    _syncingChanges = true;
    try {
      await _cursorReady;
      if (!mounted) return;
      final changes = <ForgeConversationChange>[];
      var nextCursor = _changeCursor;
      for (var pageNumber = 0; pageNumber < 4; pageNumber++) {
        final page = await _api.conversationChanges(
          afterCursor: nextCursor,
          limit: ForgeConversationsApi.maxPageSize,
        );
        if (!mounted) return;
        if (page.scannedThroughCursor < nextCursor) {
          throw const FormatException('Forge change cursor regressed.');
        }
        nextCursor = page.scannedThroughCursor;
        changes.addAll(page.changes);
        if (!page.hasMore) break;
      }
      if (_changeError != null) setState(() => _changeError = null);
      if (changes.isEmpty) {
        final selectedID = _selected?.conversation.id;
        if (_promptError != null && selectedID != null) {
          await _loadPrompts(selectedID);
        }
        await _syncRunObservation();
        return;
      }

      final latestByConversation = <String, ForgeConversationChange>{};
      var createdConversation = false;
      for (final change in changes) {
        final prior = latestByConversation[change.conversationID];
        if (prior == null || change.aggregateVersion > prior.aggregateVersion) {
          latestByConversation[change.conversationID] = change;
        }
        createdConversation |= change.kind == 'conversation_created';
      }
      final updated = _conversations
          .map((entry) {
            final change = latestByConversation[entry.conversation.id];
            if (change == null ||
                change.aggregateVersion <= entry.aggregateVersion) {
              return entry;
            }
            return _withConversationChange(entry, change);
          })
          .toList(growable: false);
      final selectedID = _selected?.conversation.id;
      final selectedChange = selectedID == null
          ? null
          : latestByConversation[selectedID];
      setState(() {
        _conversations = updated;
        if (selectedChange != null &&
            selectedChange.aggregateVersion >
                (_selected?.aggregateVersion ?? 0)) {
          _selected = _withConversationChange(_selected!, selectedChange);
          _conversations = _replaceConversation(_conversations, _selected!);
        }
      });
      if (createdConversation) {
        if (!await _refreshConversations()) {
          await _syncRunObservation();
          return;
        }
      } else if (selectedChange?.kind == 'prompt_appended') {
        if (!await _loadPrompts(selectedID!)) {
          await _syncRunObservation();
          return;
        }
      }
      if (!mounted) return;
      await _syncRunObservation();
      if (!mounted) return;
      _changeCursor = nextCursor;
      await _changeCursorStore.save(nextCursor);
    } catch (error) {
      _clearSessionIfUnauthorized(error);
      if (mounted) {
        setState(() {
          _changeError = _friendlyError(
            error,
            'Could not sync Forge sessions.',
          );
        });
      }
    } finally {
      _syncingChanges = false;
    }
  }

  Future<void> _syncRunObservation() async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _loadingRuns || _loadingRunTimeline) return;

    final runGeneration = _runGeneration;
    var timelineGeneration = _runTimelineGeneration;
    final selectedRunID = _selectedRun?.runID;
    bool isCurrent() =>
        mounted &&
        _selected?.conversation.id == conversationID &&
        _runGeneration == runGeneration &&
        _runTimelineGeneration == timelineGeneration;

    late final ForgeConversationRunPage runPage;
    try {
      runPage = await _api.listRuns(conversationID: conversationID);
    } catch (error) {
      if (!mounted ||
          _selected?.conversation.id != conversationID ||
          _runGeneration != runGeneration ||
          _runTimelineGeneration != timelineGeneration) {
        return;
      }
      _clearSessionIfUnauthorized(error);
      setState(() {
        _runError = _friendlyError(error, 'Could not load runs.');
      });
      return;
    }
    if (!isCurrent()) return;

    final mergedRuns = _uniqueRuns([..._runs, ...runPage.runs]);
    final selectedRun = selectedRunID == null
        ? (mergedRuns.isEmpty ? null : mergedRuns.first)
        : _findRun(mergedRuns, selectedRunID);
    final selectionChanged = selectedRun?.runID != selectedRunID;
    if (selectionChanged) {
      timelineGeneration = ++_runTimelineGeneration;
    }
    setState(() {
      _runs = mergedRuns;
      _selectedRun = selectedRun;
      _runCursor ??= runPage.nextCursor;
      _hasMoreRuns = _runCursor == null
          ? false
          : _hasMoreRuns || runPage.hasMore;
      _runError = null;
      if (selectionChanged) {
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
        _runTimelineError = null;
      }
    });
    if (selectedRun == null) return;

    final afterSequence = _runTimelineSequence;
    try {
      final timelinePage = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: selectedRun.runID,
        afterSequence: afterSequence,
      );
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) return;
      setState(() {
        _runEvents = _uniqueRunEvents([..._runEvents, ...timelinePage.events]);
        _runTimelineSequence = timelinePage.scannedThroughSequence;
        _hasMoreRunEvents = timelinePage.hasMore;
        _runTimelineError = null;
      });
    } catch (error) {
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) return;
      _clearSessionIfUnauthorized(error);
      setState(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
      });
    }
  }

  ForgeOwnedConversation _withConversationChange(
    ForgeOwnedConversation entry,
    ForgeConversationChange change,
  ) => ForgeOwnedConversation(
    conversation: ForgeConversation(
      id: entry.conversation.id,
      scope: entry.conversation.scope,
      title: entry.conversation.title,
      createdAtMS: entry.conversation.createdAtMS,
      updatedAtMS: change.createdAtMS > entry.conversation.updatedAtMS
          ? change.createdAtMS
          : entry.conversation.updatedAtMS,
    ),
    aggregateVersion: change.aggregateVersion,
  );

  Future<bool> _loadPrompts(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    final generation = ++_promptGeneration;
    setState(() {
      _loadingPrompts = true;
      _promptError = null;
    });
    try {
      final page = await _api.listPrompts(
        conversationID: conversationID,
        before: loadOlder ? _promptCursor : null,
      );
      if (!mounted ||
          generation != _promptGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      final prompts = loadOlder
          ? [...page.prompts, ..._prompts]
          : [...page.prompts];
      prompts.sort(_comparePrompts);
      setState(() {
        _prompts = _uniquePrompts(prompts);
        _promptCursor = page.nextCursor;
        _hasMorePrompts = page.hasMore && page.nextCursor != null;
        _loadingPrompts = false;
      });
      return true;
    } catch (error) {
      if (!mounted || generation != _promptGeneration) return false;
      _clearSessionIfUnauthorized(error);
      setState(() {
        _promptError = _friendlyError(error, 'Could not load prompt history.');
        _loadingPrompts = false;
      });
      return false;
    }
  }

  Future<void> _restoreChangeCursor() async {
    _changeCursor = await _changeCursorStore.load();
  }

  Future<void> _createConversation() async {
    if (_creating || _appending || _pendingPrompt != null) return;
    final pending = _pendingCreate ?? _readCreateRequest();
    if (pending == null) return;
    setState(() {
      _pendingCreate = pending;
      _creating = true;
      _createError = null;
    });
    try {
      final created = await _api.createConversation(
        scope: pending.scope,
        title: pending.title,
        idempotencyKey: pending.idempotencyKey,
      );
      if (!mounted) return;
      // A new conversation's creation event establishes aggregate version 1.
      final selected = ForgeOwnedConversation(
        conversation: created,
        aggregateVersion: 1,
      );
      setState(() {
        _runGeneration++;
        _runTimelineGeneration++;
        _loadingRuns = false;
        _loadingRunTimeline = false;
        _pendingCreate = null;
        _pendingPrompt = null;
        _creating = false;
        _appendError = null;
        _titleController.clear();
        _scopeIDController.clear();
        _selected = selected;
        _conversations = _mergeConversations(
          incoming: [selected, ..._conversations],
          existing: const [],
          append: false,
        );
        _prompts = const [];
        _promptCursor = null;
        _runs = const [];
        _runCursor = null;
        _hasMoreRuns = false;
        _selectedRun = null;
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      });
      await _loadPrompts(created.id);
      await _loadRuns(created.id);
    } catch (error) {
      if (!mounted) return;
      _clearSessionIfUnauthorized(error);
      final terminal = _isDefinitiveWriteFailure(error);
      setState(() {
        if (terminal) _pendingCreate = null;
        _createError = _friendlyError(
          error,
          'Forge did not confirm conversation creation.',
        );
        _creating = false;
      });
    }
  }

  _PendingCreate? _readCreateRequest() {
    final title = _titleController.text.trim();
    final scopeID = _scopeIDController.text.trim();
    if (title.isEmpty) {
      setState(() => _createError = 'Enter a conversation title.');
      return null;
    }
    if (_scopeKind != 'global' && scopeID.isEmpty) {
      setState(() => _createError = 'Enter a project or group ID.');
      return null;
    }
    return _PendingCreate(
      title: title,
      scope: ForgeConversationScope(
        kind: _scopeKind,
        id: _scopeKind == 'global' ? null : scopeID,
      ),
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  Future<void> _selectConversation(ForgeOwnedConversation value) async {
    if (_appending ||
        _pendingPrompt != null ||
        _selected?.conversation.id == value.conversation.id) {
      return;
    }
    setState(() {
      _runGeneration++;
      _runTimelineGeneration++;
      _loadingRuns = false;
      _loadingRunTimeline = false;
      _selected = value;
      _prompts = const [];
      _promptCursor = null;
      _hasMorePrompts = false;
      _promptError = null;
      _appendError = null;
      _pendingPrompt = null;
      _runs = const [];
      _runCursor = null;
      _hasMoreRuns = false;
      _selectedRun = null;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runError = null;
      _runTimelineError = null;
    });
    await _loadPrompts(value.conversation.id);
    await _loadRuns(value.conversation.id);
  }

  Future<bool> _loadRuns(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    if (_loadingRuns && loadOlder) return false;
    final generation = loadOlder ? _runGeneration : ++_runGeneration;
    setState(() {
      _loadingRuns = true;
      _runError = null;
    });
    try {
      final page = await _api.listRuns(
        conversationID: conversationID,
        before: loadOlder ? _runCursor : null,
      );
      if (!mounted ||
          generation != _runGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      final incoming = loadOlder ? [..._runs, ...page.runs] : page.runs;
      final merged = _uniqueRuns(incoming);
      final wantedRunID = _selectedRun?.runID;
      final selectedRun =
          _findRun(merged, wantedRunID) ??
          (merged.isEmpty ? null : merged.first);
      setState(() {
        _runs = merged;
        _runCursor = page.nextCursor;
        _hasMoreRuns = page.hasMore && page.nextCursor != null;
        _selectedRun = selectedRun;
        _loadingRuns = false;
      });
      if (!loadOlder && selectedRun != null) {
        return _loadRunTimeline(conversationID, selectedRun.runID);
      }
      if (selectedRun == null) {
        setState(() {
          _runTimelineGeneration++;
          _loadingRunTimeline = false;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _runTimelineError = null;
        });
      }
      return true;
    } catch (error) {
      if (!mounted || generation != _runGeneration) return false;
      _clearSessionIfUnauthorized(error);
      setState(() {
        _runError = _friendlyError(error, 'Could not load runs.');
        _loadingRuns = false;
      });
      return false;
    }
  }

  Future<bool> _loadRunTimeline(
    String conversationID,
    String runID, {
    bool loadMore = false,
  }) async {
    if (_loadingRunTimeline && loadMore) return false;
    final generation = loadMore
        ? _runTimelineGeneration
        : ++_runTimelineGeneration;
    final afterSequence = loadMore ? _runTimelineSequence : 0;
    setState(() {
      _loadingRunTimeline = true;
      _runTimelineError = null;
      if (!loadMore) {
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      }
    });
    try {
      final page = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: runID,
        afterSequence: afterSequence,
      );
      if (!mounted ||
          generation != _runTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return false;
      }
      setState(() {
        _runEvents = _uniqueRunEvents(
          loadMore ? [..._runEvents, ...page.events] : page.events,
        );
        _runTimelineSequence = page.scannedThroughSequence;
        _hasMoreRunEvents = page.hasMore;
        _loadingRunTimeline = false;
      });
      return true;
    } catch (error) {
      if (!mounted || generation != _runTimelineGeneration) return false;
      _clearSessionIfUnauthorized(error);
      setState(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
        _loadingRunTimeline = false;
      });
      return false;
    }
  }

  Future<void> _selectRun(ForgeConversationRun run) async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _selectedRun?.runID == run.runID) return;
    setState(() {
      _runTimelineGeneration++;
      _loadingRunTimeline = false;
      _selectedRun = run;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runTimelineError = null;
    });
    await _loadRunTimeline(conversationID, run.runID);
  }

  Future<void> _appendPrompt() async {
    final selected = _selected;
    if (selected == null || _appending) return;
    final pending = _pendingPrompt ?? _readPromptRequest(selected);
    if (pending == null) return;
    setState(() {
      _pendingPrompt = pending;
      _appending = true;
      _appendError = null;
    });
    try {
      final result = await _api.appendPrompt(
        conversationID: selected.conversation.id,
        content: pending.content,
        expectedVersion: pending.expectedVersion,
        idempotencyKey: pending.idempotencyKey,
      );
      if (!mounted || _selected?.conversation.id != selected.conversation.id) {
        return;
      }
      final updated = ForgeOwnedConversation(
        conversation: selected.conversation,
        aggregateVersion: result.aggregateVersion,
      );
      setState(() {
        _selected = updated;
        _conversations = _replaceConversation(_conversations, updated);
        _prompts = _uniquePrompts(
          [..._prompts, result.prompt]..sort(_comparePrompts),
        );
        _pendingPrompt = null;
        _promptController.clear();
        _appending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Prompt stored. It has not started a task.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _clearSessionIfUnauthorized(error);
      final status = error is ForgeConversationsApiException
          ? error.statusCode
          : 0;
      final terminal = _isDefinitiveWriteFailure(error);
      setState(() {
        if (terminal) _pendingPrompt = null;
        _appendError = _friendlyError(
          error,
          'Forge did not confirm the prompt write.',
        );
        _appending = false;
      });
      if (status == 409) {
        await _refreshConversations(selectID: selected.conversation.id);
      }
    }
  }

  _PendingPrompt? _readPromptRequest(ForgeOwnedConversation selected) {
    final content = _promptController.text.trim();
    if (content.isEmpty) {
      setState(() => _appendError = 'Enter a prompt to send.');
      return null;
    }
    return _PendingPrompt(
      content: content,
      expectedVersion: selected.aggregateVersion,
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  bool _isDefinitiveWriteFailure(Object error) {
    if (error is! ForgeConversationsApiException) return false;
    if (error.statusCode == 409) return true;
    if (error.statusCode == 408 ||
        error.statusCode == 425 ||
        error.statusCode == 429) {
      return false;
    }
    return error.statusCode >= 400 && error.statusCode < 500;
  }

  void _clearSessionIfUnauthorized(Object error) {
    if (error is ForgeConversationsApiException && error.isUnauthorized) {
      Session.clearForClient(ForgeConversationsOAuth.clientId);
    }
  }

  void _signOutThisDevice() {
    unawaited(_revokeAndReturnToForgeLogin());
  }

  Future<void> _revokeAndReturnToForgeLogin() async {
    try {
      await _tokenRefresh.revokeCurrentTokens();
    } catch (_) {
      // A failed revoke must not trap the user in the signed-in screen.
    } finally {
      Session.clearForClient(ForgeConversationsOAuth.clientId);
      BrowserNavigation.replaceLocation(
        ForgeConversationsOAuth.loginLocation(),
      );
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ForgeConversationsApiException) {
      if (error.isUnauthorized || error.isForbidden) {
        return _forgeAuthRequiredMessage;
      }
      if (error.statusCode == 0 || error.statusCode >= 500) {
        return error.message;
      }
      if (error.code == 'conflict') {
        return 'This conversation changed elsewhere. Refresh before sending again.';
      }
      return error.message;
    }
    if (error is FormatException) return 'Forge returned an invalid response.';
    return fallback;
  }

  void _signIn() => BrowserNavigation.replaceLocation(
    ForgeConversationsOAuth.loginLocation(retryAfterAuthorizationFailure: true),
  );

  void _setScopeKind(String? value) =>
      setState(() => _scopeKind = value ?? 'global');

  @override
  Widget build(BuildContext context) => _ForgeSessionsView(state: this);
}

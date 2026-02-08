import 'dart:async';
import 'ai_workforce_manager.dart';

/// Orchestrates complex multi-step AI tasks
/// Coordinates multiple AI workers to complete complex workflows
class AITaskOrchestrator {
  final AIWorkforceManager workforceManager;
  final Map<String, Workflow> _activeWorkflows = {};

  AITaskOrchestrator({required this.workforceManager});

  /// Execute a multi-step workflow
  Future<WorkflowResult> executeWorkflow(WorkflowDefinition definition) async {
    final workflow = Workflow(
      id: _generateWorkflowId(),
      definition: definition,
      status: WorkflowStatus.running,
      startedAt: DateTime.now(),
    );

    _activeWorkflows[workflow.id] = workflow;

    try {
      final results = <String, dynamic>{};

      for (final step in definition.steps) {
        // Replace variables in prompt
        final prompt = _replaceVariables(step.prompt, results);

        // Create AI task
        final task = AITask(
          id: '${workflow.id}_step_${step.id}',
          type: step.taskType,
          prompt: prompt,
          context: step.context,
          parameters: step.parameters,
        );

        // Execute task
        final result = await workforceManager.executeTaskAuto(
          task: task,
          preferredProvider: step.preferredProvider,
        );

        if (!result.success) {
          workflow.status = WorkflowStatus.failed;
          workflow.error = result.error;
          workflow.completedAt = DateTime.now();

          return WorkflowResult(
            workflowId: workflow.id,
            success: false,
            error: 'Step ${step.id} failed: ${result.error}',
            completedAt: DateTime.now(),
          );
        }

        // Store result for next steps
        results[step.id] = result.result;
        workflow.stepResults[step.id] = result.result ?? '';

        // Check if we should continue
        if (step.condition != null &&
            !_evaluateCondition(step.condition!, results)) {
          break;
        }
      }

      workflow.status = WorkflowStatus.completed;
      workflow.completedAt = DateTime.now();

      return WorkflowResult(
        workflowId: workflow.id,
        success: true,
        results: results,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      workflow.status = WorkflowStatus.failed;
      workflow.error = e.toString();
      workflow.completedAt = DateTime.now();

      return WorkflowResult(
        workflowId: workflow.id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  /// Execute predefined workflow patterns
  Future<WorkflowResult> executePattern(
      WorkflowPattern pattern, Map<String, dynamic> inputs) async {
    switch (pattern) {
      case WorkflowPattern.codeGeneration:
        return _executeCodeGenerationWorkflow(inputs);
      case WorkflowPattern.codeReview:
        return _executeCodeReviewWorkflow(inputs);
      case WorkflowPattern.research:
        return _executeResearchWorkflow(inputs);
      case WorkflowPattern.dataAnalysis:
        return _executeDataAnalysisWorkflow(inputs);
      case WorkflowPattern.documentation:
        return _executeDocumentationWorkflow(inputs);
    }
  }

  /// Code generation workflow
  Future<WorkflowResult> _executeCodeGenerationWorkflow(
      Map<String, dynamic> inputs) async {
    final definition = WorkflowDefinition(
      name: 'Code Generation',
      steps: [
        WorkflowStep(
          id: 'analyze_requirements',
          taskType: AITaskType.research,
          prompt: '''
Analyze the following requirements and create a detailed specification:
${inputs['requirements']}

Provide:
1. Core functionality needed
2. Data structures required
3. Edge cases to handle
4. Suggested architecture
          ''',
        ),
        WorkflowStep(
          id: 'generate_code',
          taskType: AITaskType.codeGeneration,
          prompt: '''
Based on this specification:
{{analyze_requirements}}

Generate production-ready code in ${inputs['language'] ?? 'Python'}.
Include:
- Well-structured, modular code
- Error handling
- Type hints/annotations
- Docstrings/comments
          ''',
        ),
        WorkflowStep(
          id: 'generate_tests',
          taskType: AITaskType.codeGeneration,
          prompt: '''
For this code:
{{generate_code}}

Generate comprehensive unit tests that cover:
- Normal cases
- Edge cases
- Error cases
- Integration scenarios
          ''',
        ),
        WorkflowStep(
          id: 'code_review',
          taskType: AITaskType.codeReview,
          prompt: '''
Review this code and tests:

CODE:
{{generate_code}}

TESTS:
{{generate_tests}}

Provide:
1. Code quality assessment
2. Potential issues or bugs
3. Performance considerations
4. Security concerns
5. Suggested improvements
          ''',
        ),
      ],
    );

    return executeWorkflow(definition);
  }

  /// Code review workflow
  Future<WorkflowResult> _executeCodeReviewWorkflow(
      Map<String, dynamic> inputs) async {
    final definition = WorkflowDefinition(
      name: 'Code Review',
      steps: [
        WorkflowStep(
          id: 'static_analysis',
          taskType: AITaskType.codeAnalysis,
          prompt: '''
Perform static analysis on this code:
${inputs['code']}

Check for:
- Code style violations
- Potential bugs
- Unused variables
- Dead code
          ''',
        ),
        WorkflowStep(
          id: 'security_review',
          taskType: AITaskType.codeAnalysis,
          prompt: '''
Review this code for security issues:
${inputs['code']}

Check for:
- SQL injection vulnerabilities
- XSS vulnerabilities
- Authentication/authorization issues
- Data exposure risks
- Dependency vulnerabilities
          ''',
        ),
        WorkflowStep(
          id: 'performance_review',
          taskType: AITaskType.codeAnalysis,
          prompt: '''
Analyze performance aspects of this code:
${inputs['code']}

Check for:
- Time complexity issues
- Memory leaks
- Inefficient algorithms
- Database query optimization
- Caching opportunities
          ''',
        ),
        WorkflowStep(
          id: 'generate_report',
          taskType: AITaskType.documentation,
          prompt: '''
Compile a comprehensive code review report:

Static Analysis:
{{static_analysis}}

Security Review:
{{security_review}}

Performance Review:
{{performance_review}}

Provide:
1. Executive summary
2. Critical issues (must fix)
3. Important issues (should fix)
4. Suggestions (nice to have)
5. Overall assessment
          ''',
        ),
      ],
    );

    return executeWorkflow(definition);
  }

  /// Research workflow
  Future<WorkflowResult> _executeResearchWorkflow(
      Map<String, dynamic> inputs) async {
    final definition = WorkflowDefinition(
      name: 'Research',
      steps: [
        WorkflowStep(
          id: 'define_scope',
          taskType: AITaskType.research,
          prompt: '''
Define the research scope for: ${inputs['topic']}

Provide:
1. Key questions to answer
2. Areas to investigate
3. Expected deliverables
          ''',
        ),
        WorkflowStep(
          id: 'gather_information',
          taskType: AITaskType.research,
          prompt: '''
Research these areas:
{{define_scope}}

Provide comprehensive information from reliable sources.
          ''',
        ),
        WorkflowStep(
          id: 'analyze_findings',
          taskType: AITaskType.dataAnalysis,
          prompt: '''
Analyze this research data:
{{gather_information}}

Provide:
1. Key insights
2. Patterns and trends
3. Implications
4. Recommendations
          ''',
        ),
        WorkflowStep(
          id: 'create_report',
          taskType: AITaskType.documentation,
          prompt: '''
Create a research report:

Scope:
{{define_scope}}

Findings:
{{gather_information}}

Analysis:
{{analyze_findings}}

Format as a professional report with sections, citations, and conclusions.
          ''',
        ),
      ],
    );

    return executeWorkflow(definition);
  }

  /// Data analysis workflow
  Future<WorkflowResult> _executeDataAnalysisWorkflow(
      Map<String, dynamic> inputs) async {
    final definition = WorkflowDefinition(
      name: 'Data Analysis',
      steps: [
        WorkflowStep(
          id: 'data_exploration',
          taskType: AITaskType.dataAnalysis,
          prompt: '''
Explore this dataset:
${inputs['data']}

Provide:
1. Data structure overview
2. Key statistics
3. Data quality issues
4. Interesting patterns
          ''',
        ),
        WorkflowStep(
          id: 'statistical_analysis',
          taskType: AITaskType.dataAnalysis,
          prompt: '''
Perform statistical analysis on:
{{data_exploration}}

Include:
- Descriptive statistics
- Correlation analysis
- Distribution analysis
- Outlier detection
          ''',
        ),
        WorkflowStep(
          id: 'generate_insights',
          taskType: AITaskType.dataAnalysis,
          prompt: '''
Generate business insights from:
{{statistical_analysis}}

Provide:
1. Key findings
2. Actionable insights
3. Recommendations
4. Visualizations suggestions
          ''',
        ),
      ],
    );

    return executeWorkflow(definition);
  }

  /// Documentation workflow
  Future<WorkflowResult> _executeDocumentationWorkflow(
      Map<String, dynamic> inputs) async {
    final definition = WorkflowDefinition(
      name: 'Documentation',
      steps: [
        WorkflowStep(
          id: 'analyze_code',
          taskType: AITaskType.codeAnalysis,
          prompt: '''
Analyze this code to understand its purpose and functionality:
${inputs['code']}

Identify:
1. Main purpose
2. Key components
3. Public API
4. Dependencies
          ''',
        ),
        WorkflowStep(
          id: 'generate_api_docs',
          taskType: AITaskType.documentation,
          prompt: '''
Based on this analysis:
{{analyze_code}}

Generate API documentation including:
- Function/method signatures
- Parameter descriptions
- Return value descriptions
- Usage examples
          ''',
        ),
        WorkflowStep(
          id: 'generate_user_guide',
          taskType: AITaskType.documentation,
          prompt: '''
Create a user guide for:
{{analyze_code}}

Include:
- Getting started
- Installation
- Configuration
- Common use cases
- Troubleshooting
          ''',
        ),
      ],
    );

    return executeWorkflow(definition);
  }

  /// Replace variables in prompt
  String _replaceVariables(String prompt, Map<String, dynamic> results) {
    var replaced = prompt;

    final regex = RegExp(r'\{\{(\w+)\}\}');
    final matches = regex.allMatches(prompt);

    for (final match in matches) {
      final varName = match.group(1)!;
      final value = results[varName];
      if (value != null) {
        replaced = replaced.replaceAll('{{$varName}}', value.toString());
      }
    }

    return replaced;
  }

  /// Evaluate condition
  bool _evaluateCondition(String condition, Map<String, dynamic> results) {
    // Simple condition evaluation (can be extended)
    return true;
  }

  /// Generate workflow ID
  String _generateWorkflowId() {
    return 'workflow_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get workflow status
  Workflow? getWorkflow(String workflowId) {
    return _activeWorkflows[workflowId];
  }

  /// Get all active workflows
  List<Workflow> getActiveWorkflows() {
    return _activeWorkflows.values
        .where((w) => w.status == WorkflowStatus.running)
        .toList();
  }
}

/// Workflow definition
class WorkflowDefinition {
  final String name;
  final List<WorkflowStep> steps;

  WorkflowDefinition({
    required this.name,
    required this.steps,
  });
}

/// Workflow step
class WorkflowStep {
  final String id;
  final AITaskType taskType;
  final String prompt;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? parameters;
  final String? condition;
  final String? preferredProvider;

  WorkflowStep({
    required this.id,
    required this.taskType,
    required this.prompt,
    this.context,
    this.parameters,
    this.condition,
    this.preferredProvider,
  });
}

/// Active workflow
class Workflow {
  final String id;
  final WorkflowDefinition definition;
  WorkflowStatus status;
  final DateTime startedAt;
  DateTime? completedAt;
  String? error;
  final Map<String, String> stepResults = {};

  Workflow({
    required this.id,
    required this.definition,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': definition.name,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (error != null) 'error': error,
      'step_results': stepResults,
    };
  }
}

enum WorkflowStatus { running, completed, failed }

/// Workflow result
class WorkflowResult {
  final String workflowId;
  final bool success;
  final Map<String, dynamic>? results;
  final String? error;
  final DateTime completedAt;

  WorkflowResult({
    required this.workflowId,
    required this.success,
    this.results,
    this.error,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'workflow_id': workflowId,
      'success': success,
      if (results != null) 'results': results,
      if (error != null) 'error': error,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

/// Predefined workflow patterns
enum WorkflowPattern {
  codeGeneration,
  codeReview,
  research,
  dataAnalysis,
  documentation,
}

//
//  TaskToolExampleAgent.swift
//  CashMonki
//
//  Created by Claude Code
//  Educational example showing how to use the Task tool effectively
//

import Foundation

/**
 * TaskToolExampleAgent
 *
 * This file demonstrates how to structure effective task prompts for the Task tool.
 * The Task tool is designed for complex, multi-step operations that require planning,
 * research, and systematic execution.
 *
 * WHEN TO USE THE TASK TOOL:
 * ✅ Complex analysis requiring multiple files
 * ✅ Research tasks spanning entire codebase
 * ✅ Multi-step refactoring operations
 * ✅ Architecture planning and implementation
 * ✅ Performance optimization investigations
 * ✅ Security audits and compliance checks
 *
 * WHEN NOT TO USE THE TASK TOOL:
 * ❌ Simple file edits or single-line changes
 * ❌ Straightforward questions with obvious answers
 * ❌ Basic file reading or searching
 * ❌ Quick bug fixes in known locations
 */

struct TaskToolExampleAgent {
    
    // MARK: - Example 1: Simple Code Analysis Task
    
    /**
     * EXAMPLE 1: Analyzing Transaction Display Components
     *
     * Task Prompt Structure:
     * - Clear objective
     * - Specific scope
     * - Expected deliverables
     */
    static let example1_SimpleAnalysis = """
    TASK: Analyze all transaction display components in the CashMonki app
    
    OBJECTIVE: 
    Understand how transactions are displayed across different screens and identify
    any inconsistencies in styling, data formatting, or user experience.
    
    SCOPE:
    - Search for all files containing transaction display logic
    - Examine UnifiedTransactionDisplay implementations
    - Check for legacy TransactionRow/TransactionTile usage
    - Review currency formatting consistency
    
    DELIVERABLES:
    1. List of all transaction display components found
    2. Consistency analysis report
    3. Recommendations for improvements
    4. Code examples showing current patterns
    
    SEARCH STRATEGY:
    - Look for "transaction" in file names and content
    - Find UnifiedTransactionDisplay usage
    - Check for currency formatting patterns
    - Examine sheet implementations that show transactions
    """
    
    // MARK: - Example 2: Complex Refactoring Task
    
    /**
     * EXAMPLE 2: API Key Management Security Audit
     *
     * Task Prompt Structure:
     * - Security-focused investigation
     * - Multiple validation steps
     * - Comprehensive reporting
     */
    static let example2_SecurityAudit = """
    TASK: Conduct comprehensive security audit of API key management in CashMonki
    
    OBJECTIVE:
    Ensure API keys are properly secured, never exposed in code, and following
    iOS security best practices throughout the application.
    
    INVESTIGATION AREAS:
    1. Config.swift hardcoded API key patterns
    2. KeychainManager implementation security
    3. Environment variable handling
    4. Info.plist exposure risks
    5. Build configuration security
    6. Firebase configuration security
    
    VALIDATION STEPS:
    - Search for any hardcoded API keys in source files
    - Verify keychain storage implementation
    - Check for API keys in configuration files
    - Examine build scripts for key exposure
    - Review Firebase integration security
    - Test key retrieval fallback mechanisms
    
    SECURITY CRITERIA:
    - No API keys in source code (except setup patterns)
    - Proper keychain access controls
    - Secure fallback mechanisms
    - No keys in version control
    - Proper error handling without key exposure
    
    DELIVERABLES:
    1. Security assessment report
    2. List of any vulnerabilities found
    3. Recommendations for improvements
    4. Code examples of secure patterns
    5. Migration plan if issues found
    """
    
    // MARK: - Example 3: Performance Investigation Task
    
    /**
     * EXAMPLE 3: Camera Performance Bottleneck Investigation
     *
     * Task Prompt Structure:
     * - Performance-focused analysis
     * - Systematic debugging approach
     * - Quantitative measurements
     */
    static let example3_PerformanceInvestigation = """
    TASK: Investigate and resolve camera to photo picker transition performance issues
    
    PROBLEM STATEMENT:
    Users experience 5-10 second delays when transitioning from camera capture
    to photo picker, causing poor user experience and app perception issues.
    
    INVESTIGATION METHODOLOGY:
    1. Locate all camera-related components and flows
    2. Identify image processing bottlenecks
    3. Find main thread blocking operations
    4. Examine memory usage patterns
    5. Trace camera session lifecycle
    6. Analyze state management during transitions
    
    SPECIFIC AREAS TO EXAMINE:
    - Camera session cleanup timing
    - UIImage processing operations
    - State cascade re-renders
    - Thread usage patterns
    - Memory pressure during image handling
    - Firebase upload timing conflicts
    
    PERFORMANCE TARGETS:
    - Camera to picker transition: <300ms
    - No main thread blocking >100ms
    - Background processing for heavy operations
    - Smooth UI transitions without stuttering
    
    DELIVERABLES:
    1. Root cause analysis report
    2. Performance measurement data
    3. Specific bottleneck identification
    4. Optimized code implementations
    5. Before/after performance comparison
    6. Testing strategy for validation
    """
    
    // MARK: - Example 4: Architecture Planning Task
    
    /**
     * EXAMPLE 4: Design System Consolidation Planning
     *
     * Task Prompt Structure:
     * - Architectural assessment
     * - Migration planning
     * - Systematic implementation
     */
    static let example4_ArchitecturePlanning = """
    TASK: Plan consolidation of UI components into unified CashMonkiDS design system
    
    STRATEGIC OBJECTIVE:
    Consolidate all UI components under the CashMonkiDS umbrella to ensure
    consistency, reduce code duplication, and improve maintainability.
    
    DISCOVERY PHASE:
    1. Catalog all existing UI components across the app
    2. Identify duplicate functionality and inconsistencies
    3. Map component usage patterns throughout codebase
    4. Assess current design system adoption
    5. Find legacy component usage that needs migration
    
    ANALYSIS REQUIREMENTS:
    - Component inventory with usage statistics
    - Duplication analysis and consolidation opportunities
    - Migration complexity assessment
    - Breaking change impact evaluation
    - Developer experience improvement potential
    
    PLANNING DELIVERABLES:
    1. Complete component inventory
    2. Consolidation strategy and timeline
    3. Migration plan with phases
    4. Risk assessment and mitigation strategies
    5. Updated component usage guidelines
    6. Implementation roadmap with priorities
    
    SUCCESS CRITERIA:
    - 90%+ components use CashMonkiDS
    - 50%+ reduction in duplicate code
    - Consistent styling across all screens
    - Improved developer productivity
    - Maintainable component architecture
    """
    
    // MARK: - Example 5: Data Migration Task
    
    /**
     * EXAMPLE 5: Transaction Data Structure Migration
     *
     * Task Prompt Structure:
     * - Data-focused investigation
     * - Migration planning
     * - Risk assessment
     */
    static let example5_DataMigration = """
    TASK: Plan migration from legacy transaction structure to account-based system
    
    MIGRATION OBJECTIVE:
    Safely migrate all existing transaction data to support the new account-based
    transaction management system while preserving data integrity.
    
    DISCOVERY REQUIREMENTS:
    1. Analyze current Txn model structure and relationships
    2. Examine Firebase collection schema and data patterns
    3. Identify data transformation requirements
    4. Assess migration complexity and risks
    5. Plan backward compatibility strategies
    
    DATA ANALYSIS AREAS:
    - Current transaction model fields and types
    - Firebase document structure and relationships
    - Account association patterns
    - Data validation and integrity checks
    - User impact during migration
    - Rollback strategies if needed
    
    MIGRATION PLANNING:
    - Phase 1: Schema preparation and validation
    - Phase 2: Data transformation scripts
    - Phase 3: Gradual migration with testing
    - Phase 4: Legacy cleanup and optimization
    
    DELIVERABLES:
    1. Current data structure analysis
    2. Migration strategy document
    3. Data transformation scripts
    4. Testing and validation plans
    5. Risk mitigation strategies
    6. Implementation timeline
    """
    
    // MARK: - Task Tool Best Practices
    
    /**
     * BEST PRACTICES FOR TASK TOOL USAGE
     *
     * 1. CLEAR OBJECTIVES
     *    - Define specific, measurable goals
     *    - Explain the business value or user impact
     *    - Set clear success criteria
     *
     * 2. STRUCTURED SCOPE
     *    - Break down complex problems into phases
     *    - Define investigation boundaries
     *    - Prioritize areas of focus
     *
     * 3. SPECIFIC DELIVERABLES
     *    - Request concrete outputs (reports, code, plans)
     *    - Ask for examples and code snippets
     *    - Define format for recommendations
     *
     * 4. SEARCH STRATEGY
     *    - Suggest specific search terms and patterns
     *    - Guide file and directory exploration
     *    - Recommend investigation techniques
     *
     * 5. VALIDATION CRITERIA
     *    - Define what "done" looks like
     *    - Set quality standards
     *    - Specify testing requirements
     */
    
    // MARK: - Common Task Patterns
    
    enum TaskPatterns {
        case codebaseAnalysis    // Understanding existing code structure
        case securityAudit       // Finding security vulnerabilities
        case performanceOptimization // Identifying and fixing bottlenecks
        case architecturePlanning    // Designing system improvements
        case dataMigration       // Planning data structure changes
        case componentConsolidation  // Reducing code duplication
        case complianceCheck     // Ensuring standards adherence
        case documentationGeneration // Creating comprehensive docs
    }
    
    /**
     * TASK PROMPT TEMPLATE
     *
     * Use this template as a starting point for your task prompts:
     *
     * TASK: [One-line description of what needs to be done]
     *
     * OBJECTIVE:
     * [Detailed explanation of goals and expected outcomes]
     *
     * SCOPE:
     * [Define boundaries and areas to investigate]
     *
     * METHODOLOGY:
     * [Suggest investigation approach and techniques]
     *
     * DELIVERABLES:
     * 1. [Specific output 1]
     * 2. [Specific output 2]
     * 3. [Specific output 3]
     *
     * SUCCESS CRITERIA:
     * [How to measure if the task was completed successfully]
     */
}

// MARK: - Usage Examples in Practice

/**
 * HOW TO USE THESE EXAMPLES:
 *
 * 1. Choose the example closest to your needs
 * 2. Customize the prompt for your specific situation
 * 3. Add any project-specific context or constraints
 * 4. Submit to the Task tool and review results
 * 5. Iterate based on findings
 *
 * EXAMPLE USAGE:
 *
 * // For code analysis:
 * let analysisPrompt = TaskToolExampleAgent.example1_SimpleAnalysis
 * // Customize scope and submit to Task tool
 *
 * // For security audit:
 * let securityPrompt = TaskToolExampleAgent.example2_SecurityAudit
 * // Add specific security concerns and submit
 *
 * // For performance investigation:
 * let performancePrompt = TaskToolExampleAgent.example3_PerformanceInvestigation
 * // Customize performance targets and submit
 */
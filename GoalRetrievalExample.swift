// EXAMPLE: How to access saved user goals anywhere in the app

import SwiftUI

struct GoalRetrievalExample: View {
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("User Goals Example")
                .font(.title)
            
            if let userGoals = userManager.currentUser.goals {
                Text("Saved Goals: \(userGoals)")
                    .foregroundColor(.green)
                
                // Parse goals back into array
                let goalArray = userGoals.split(separator: ",").map { String($0) }
                
                ForEach(goalArray, id: \.self) { goal in
                    Text("• \(goal)")
                }
            } else {
                Text("No goals saved yet")
                    .foregroundColor(.gray)
            }
            
            // Example usage in different scenarios:
            Button("Example: Use Goals for Analytics") {
                if let goals = userManager.currentUser.goals {
                    print("📊 Analytics: User has goals: \(goals)")
                    // Use for personalized analytics
                }
            }
            
            Button("Example: Show Personalized Tips") {
                if let goals = userManager.currentUser.goals {
                    let goalArray = goals.split(separator: ",").map { String($0) }
                    
                    if goalArray.contains("stick_budget") {
                        print("💡 Show budgeting tips to user")
                    }
                    if goalArray.contains("track_spending") {
                        print("💡 Show spending analysis features")
                    }
                    if goalArray.contains("save_money") {
                        print("💡 Show savings recommendations")
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Quick Access Methods

extension UserManager {
    /// Get user's selected goals as an array
    var userGoalsList: [String] {
        guard let goals = currentUser.goals else { return [] }
        return goals.split(separator: ",").map { String($0) }
    }
    
    /// Check if user has a specific goal
    func hasGoal(_ goalId: String) -> Bool {
        return userGoalsList.contains(goalId)
    }
    
    /// Get user's primary goal (first one selected)
    var primaryGoal: String? {
        return userGoalsList.first
    }
}

// MARK: - Usage Examples

/*
// Access goals anywhere in your app:

// 1. Get raw goals string
let goalsString = UserManager.shared.currentUser.goals
print("Goals: \(goalsString ?? "none")")

// 2. Get goals as array
let goalsList = UserManager.shared.userGoalsList
print("Goals array: \(goalsList)")

// 3. Check for specific goal
if UserManager.shared.hasGoal("stick_budget") {
    // Show budget-related features
}

// 4. Get primary goal
if let primaryGoal = UserManager.shared.primaryGoal {
    print("User's main goal: \(primaryGoal)")
}

// 5. Use in analytics or personalization
let goals = UserManager.shared.userGoalsList
// Send to analytics: ["stick_budget", "save_money"]
*/
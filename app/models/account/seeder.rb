class Account::Seeder
  attr_reader :account, :creator

  def initialize(account, creator)
    @account = account
    @creator = creator

    puts creator.inspect
  end

  def seed
    Current.set session: session do
      populate
    end
  end

  def seed!
    raise "You can't run in production environments" unless Rails.env.local?

    delete_everything
    seed
  end

  private
    def session
      creator.identity.sessions.last
    end

    def populate
      # ---------------
      # Bugs Collection
      # ---------------
      bug_tracker = Collection.create! name: "Bugs", creator: creator, all_access: true

      # Columns
      triage_column = bug_tracker.columns.create! name: "Triage", color: "#ef4444"
      in_progress_column = bug_tracker.columns.create! name: "In Progress", color: "#f97316"
      resolved_column = bug_tracker.columns.create! name: "Resolved", color: "#22c55e"

      # Cards
      bug_tracker.cards.create! creator: creator, column: triage_column, title: "Login button not responding on mobile", status: "published", description: <<~HTML
        <p>Users are reporting that the login button is not responding on mobile devices.</p>

        <p>Steps to reproduce:</p>
        <ul>
          <li>Open the app on mobile browser</li>
          <li>Navigate to login page</li>
          <li>Tap the login button</li>
          <li>Nothing happens</li>
        </ul>

        <p>This appears to be affecting iOS devices primarily.</p>

        <action-text-attachment url="https://app.box-car.com/app-icon.png" caption="App icon" content-type="image/*"</action-text-attachment>
      HTML
      bug_tracker.cards.create! creator: creator, column: triage_column, title: "Search results showing duplicates", status: "published"
      profile_crash_card = bug_tracker.cards.create! creator: creator, column: in_progress_column, title: "Profile page crashes when uploading large images", status: "published"
      bug_tracker.cards.create! creator: creator, column: in_progress_column, title: "Email notifications not being sent", status: "published"
      bug_tracker.cards.create! creator: creator, column: resolved_column, title: "Fix broken links in footer", status: "published"

      # Comments
      profile_crash_card.comments.create! creator: creator, body: "I can reproduce this with images over 5MB"
      profile_crash_card.comments.create! creator: creator, body: "Looking into adding client-side image compression before upload"

      # ----------------------------
      # Feature Requests Collection
      # ----------------------------
      feature_requests = Collection.create! name: "Feature Requests", creator: creator, all_access: true

      # Columns
      backlog_column = feature_requests.columns.create! name: "Backlog", color: "#6366f1"
      planning_column = feature_requests.columns.create! name: "Planning", color: "#8b5cf6"

      # Cards
      feature_requests.cards.create! creator: creator, column: backlog_column, title: "Add dark mode support", status: "published", description: <<~HTML
        <p>Many users have requested a dark mode option for better usability in low-light environments.</p>

        <p>Proposed features:</p>
        <ul>
          <li>Toggle in user settings</li>
          <li>Respect system preferences automatically</li>
          <li>Smooth transition between themes</li>
          <li>Persistent theme selection across sessions</li>
        </ul>

        <p>This would improve accessibility and reduce eye strain for our users.</p>

        <action-text-attachment url="https://app.box-car.com/app-icon.png" alt="App icon" caption="" content-type="image/*" filename="" presentation="gallery"></action-text-attachment>
      HTML
      feature_requests.cards.create! creator: creator, column: backlog_column, title: "Export data to CSV", status: "published"
      feature_requests.cards.create! creator: creator, column: backlog_column, title: "Add keyboard shortcuts for navigation", status: "published"
      two_factor_card = feature_requests.cards.create! creator: creator, column: planning_column, title: "Implement two-factor authentication", status: "published"
      feature_requests.cards.create! creator: creator, column: planning_column, title: "Add bulk actions for managing items", status: "published"

      # Comments
      two_factor_card.comments.create! creator: creator, body: "Should we support SMS and authenticator apps?"
      two_factor_card.comments.create! creator: creator, body: "Let's start with authenticator apps only to keep it simple"
    end

    def delete_everything
      Current.set session: session do
        Collection.destroy_all
      end
    end
end

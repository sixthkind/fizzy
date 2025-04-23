module Mentions
  extend ActiveSupport::Concern

  included do
    has_many :mentions, as: :container, dependent: :destroy
    before_save :save_mentionable_content_before_save
    after_save_commit :create_mentions_later, if: :mentionable_content_changed?
  end

  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  def mentionable_content
    markdown_associations.collect do |association|
      send(association.name)&.to_plain_text
    end.compact.join(" ")
  end

  private
    def markdown_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::Markdown }
    end

    def save_mentionable_content_before_save
      @mentionable_content_before_safe = self.class.find(id).mentionable_content unless new_record?
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end

    def mentionable_content_changed?
      @mentionable_content_before_safe != mentionable_content
    end

    def scan_mentionees
      scan_mentioned_handles.filter_map do |mention|
        mentionable_users.find { |user| user.mentionable_handles.include?(mention) }
      end
    end

    def mentionable_users
      collection.users
    end

    def scan_mentioned_handles
      mentionable_content.scan(/(?<!\w)@(\w+)/).flatten.uniq(&:downcase)
    end
end

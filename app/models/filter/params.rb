module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [ :indexed_by, :assignments, bucket_ids: [], assignee_ids: [], assigner_ids: [], tag_ids: [], terms: [] ]

  included do
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  def as_params
    @as_params ||= {
      terms: terms,
      tag_ids: tags.ids,
      indexed_by: indexed_by,
      bucket_ids: buckets.ids,
      assignments: assignments,
      assignee_ids: assignees.ids,
      assigner_ids: assigners.ids
    }.reject { |k, v| default_fields[k] == v }.compact_blank
  end

  def to_params
    ActionController::Parameters.new(as_params).permit(*PERMITTED_PARAMS).tap do |params|
      params[:filter_id] = id if persisted?
    end
  end

  def params_without(key, value)
    to_params.tap do |params|
      params[key].delete(value) if params[key].is_a?(Array)
      params.delete(key) if params[key] == value
    end
  end
end

module Card::Golden
  extend ActiveSupport::Concern

  included do
    scope :golden, -> { joins(:goldness) }
    scope :non_golden, -> { where.missing(:goldness) }

    has_one :goldness, dependent: :destroy, class_name: "Card::Goldness"
  end

  def golden?
    goldness.present?
  end

  def promote_to_golden
    create_goldness! unless golden?
  end

  def demote_from_golden
    goldness&.destroy
  end
end

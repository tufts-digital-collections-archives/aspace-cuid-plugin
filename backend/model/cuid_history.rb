class CuidHistory < Sequel::Model(:cuid_history)
  include ASModel
  set_model_scope :global
  corresponds_to JSONModel(:cuid_history)
  def validate
    super
    validates_unique :component_id, message: 'has already been used'
  end
end

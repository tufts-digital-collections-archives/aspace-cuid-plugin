class CuidHistory < Sequel::Model(:cuid_history)
  include ASModel
  set_model_scope :global
  corresponds_to JSONModel(:cuid_history)
  many_to_one :archival_object

  def validate
    super
    validates_unique :component_id, message: 'has already been used'
  end
end

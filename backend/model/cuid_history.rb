class CuidHistory < Sequel::Model(:cuid_history)
  include ASModel
  set_model_scope :global
  def validate
    super
    validates_unique :cuid, message: 'has already been used'
  end
end

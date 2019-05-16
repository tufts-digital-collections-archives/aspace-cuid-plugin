require 'jsonmodel'
module Cuids
  include AutoGenerator
  extend JSONModel

  def self.included(base)

    require_relative '../cuid_history'
    base.one_to_many :cuid_history
    base.extend(ClassMethods)

    @generator = if AppConfig.has_key?(:cuid_generator)
                  AppConfig[:cuid_generator]
                 else
                  proc do |json|
                    resolved = URIResolver.resolve_references(json, ['resource'])
                    identifier = %w[id_0 id_1 id_2 id_3]
                    .map { |id| resolved['resource']['_resolved'][id] }
                    .compact
                    .join('-')

                    sequence = Sequence.get("#{identifier}_components")
                    CuidHistory.create(component_id: "#{identifier}.#{sequence}")
                    "#{identifier}.#{sequence}"
                  end
                 end

    base.auto_generate(only_if: ->(json) { (json['component_id'] || '').empty? },
                       property: :component_id,
                       generator: @generator)
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    unless cuid_history.any? { |hs| hs.component_id == json['component_id'] }
      CuidHistory.create(component_id: json['component_id'], archival_object_id: id)
    end
    super
  end

  def validate
    super
    validates_unique :component_id
  end

  module ClassMethods
    def create_from_json(json, opts = {})
      obj = super
      obj.add_cuid_history(CuidHistory.where(component_id: obj.component_id, archival_object_id: nil).first)
      obj
    end
  end

end

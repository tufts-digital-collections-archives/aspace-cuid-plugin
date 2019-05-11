require 'jsonmodel'
module Cuids
  include AutoGenerator
  extend JSONModel

  def self.included(base)

    require_relative '../cuid_history'
    base.one_to_many :cuid_history

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
                    CuidHistory.create(cuid: "#{identifier}-#{sequence}", archival_object_id: json[:id])
                    "#{identifier}-#{sequence}"
                  end
                 end

    base.auto_generate(only_if: proc do |json|
                                          cuid = json['cuid'] || ''
                                          cuid.empty?
                                      end,
                       property: :cuid,
                       generator: @generator)
  end
    
  def update_from_json(json, opts = {}, apply_nested_records = true)
    unless cuid_history.any? { |hs| hs.cuid == json['cuid'] }
        CuidHistory.create(cuid: json['cuid'], archival_object_id: id)
    end
    super
  end

  def validate
    super
    validates_unique :cuid
  end

end

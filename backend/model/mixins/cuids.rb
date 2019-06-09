require 'jsonmodel'
module Cuids
  include AutoGenerator
  extend JSONModel

  def self.included(base)

    require_relative '../cuid_history'
    base.one_to_many :cuid_history
    base.extend(ClassMethods)

    # Unsure if this is needed. Aspace doesn't seem to use Sequel model
    # hooks/callbacks. Usually #delete is called, so this is most likely
    # bi-passed in most situations. Leaving it here just in case there's
    # instances where #destroy is called.
    base.plugin :association_dependencies
    base.add_association_dependencies cuid_history: :nullify
    

    @generator = if AppConfig.has_key?(:cuid_generator)
                  AppConfig[:cuid_generator]
                 else
                   proc do |json|
                     resolved = URIResolver.resolve_references(json, ['resource'])
                     identifier = %w[id_0 id_1 id_2 id_3]
                                  .map { |id| resolved['resource']['_resolved'][id] }
                                  .compact
                                  .join('-')

                     sequence = format('%06d', Sequence.get("#{identifier}_components"))
                     CuidHistory.create(component_id: "#{identifier}.#{sequence}")
                     "#{identifier}.#{sequence}"
                   end
                 end

    base.auto_generate(only_if: ->(json) { (json['component_id'] || '').empty? },
                       property: :component_id,
                       generator: @generator)
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    component_id = json['component_id'] || ''
    # check if we have a new value incoming and add it to history.
    # if the new value is empty, let the autogen handle it.
    unless !component_id.empty? || cuid_history.any? { |hs| hs.component_id == component_id }
      CuidHistory.create(component_id: json['component_id'], archival_object_id: id)
    end
    obj = super
    # if the incoming cuid is empty, be sure to add autogen'ed val to its cuid_history.
    if component_id.empty?
      obj.add_cuid_history(CuidHistory.where(component_id: obj.component_id, archival_object_id: nil).first)
    end
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

    # this should replicate our nullify callback.
    def handle_delete(ids_to_delete)
      CuidHistory.where(archival_object_id: ids_to_delete).update(archival_object_id: nil)
      super
    end
  end

end

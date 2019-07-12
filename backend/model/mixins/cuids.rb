# frozen_string_literal: true

require 'jsonmodel'

# This adds functionality for using CUIDs. Is mixed into the ArchivalObject
# class
module Cuids
  include AutoGenerator
  extend JSONModel

  def self.included(base)
    base.extend(ClassMethods)
    base.auto_generate(only_if:
                       ->(json) { (json['component_id'] || '').empty? },
                       property: :component_id,
                       generator: base.cuid_generator)
  end

  def validate
    super
    validates_unique :component_id
  end

  # class methods
  module ClassMethods
    # We use the existing sequence functionality in ASPACE. Keeping track of
    # the counting off the number of components in a collection
    # ( also we don't want 0 so always +1 to sequence )
    def increment_component_sequence(identifier)
      format('%06d', Sequence.get("#{identifier}_components") + 1)
    end

    def cuid_generator
      if AppConfig.has_key?(:cuid_generator)
        AppConfig[:cuid_generator]
      else
        proc do |json|
          resolved = URIResolver.resolve_references(json, ['resource'])
          identifier = %w[id_0 id_1 id_2 id_3]
                       .map { |id| resolved['resource']['_resolved'][id] }
                       .compact
                       .join('-')

          # we are using sequences, but it's also possible for someone to
          # manually edit the CUID and use something that the sequence
          # hasn't hit yet. So, when making a new sequence, lets try 100 times.
          sequence = increment_component_sequence(identifier)
          100.times do
            break if where(component_id: "#{identifier}.#{sequence}").empty?

            sequence = increment_component_sequence(identifier)
          end

          "#{identifier}.#{sequence}"
        end
      end
    end
  end
end

require 'db/migrations/utils'
require 'json'
require 'securerandom'

Sequel.migration do

  up do

    puts "=" * 100
    puts "aspace-cuid-plugin: Adding the CUID column to the archival_objects table."
    puts "We will put in a default unique ID here to ensure the database intergrity."
    puts "This will follow a basic formula of 'collection id' + '.' + 'sequence number'"
    puts "Please read the documentation on how to apply your own formula and update the archival object records."
    puts "This might take a few minutes..."
    puts "=" * 100

    # first,we need to ensure that CUIDs are unique. Let's go over what's
    # currently in the DB and see:
    self[:archival_object].select(:id, :component_id)
      .where(component_id:
             self[:archival_object]
             .select_group(:component_id).having { count.function.* > 1 })
             .to_hash_groups(:component_id)
             .each do |_id, rows|

              rows.each_with_index do |row, i|
                component_id = "#{row[:component_id]}.#{ format('%06d', i + 1)}"
                puts "Renaming #{row[:component_id]} to #{component_id} to ensure uniquness."
                self[:archival_object].where(id: row[:id]).update(component_id: component_id)
              end
            end

    # Ugly. But since the collection identifier is stored as json in the DB,
    # we need to go thru and parse it out
    collections = self[:archival_object].distinct(:archival_object__root_record_id)
                                        .join(:resource, id: :root_record_id)
                                        .select(:resource__identifier,
                                                :resource__id,
                                                :resource__create_time,
                                                :resource__system_mtime,
                                                :resource__user_mtime,
                                                :resource__created_by
                                               )
                                        .map do |row|
                                          identifier = JSON.parse(row[:identifier]).compact.join('-')
                                          row[:identifier] = identifier
                                          # Count of all components associated to this collection
                                          row[:count] = self[:archival_object].select(:id).where( root_record_id: row[:id] ).count

                                          row
                                        end

    # more ugly, but works. We need to start the index after the count of AOs
    # that already have CUIDs, since it can be assumed there was some previous
    # system that was attempting to manually do sequences. 
    # we'll store these so we can do
    # this in a transaction...
    updates = []
    sequences = []
    collections.each do |collection|
      identifier = collection[:identifier]
      done = self[:archival_object].select(:id)
        .where(root_record_id: collection[:id]).exclude(component_id: nil).count
      # were we start the index
      sequences << {sequence_name: "#{identifier}_components",
                    value: collection[:count]}
      to_do = collection[:count] - done


      unless to_do < 1
        self[:archival_object].select(:id)
            .where( root_record_id: collection[:id], component_id: nil )
            .each_with_index do |ao,i|
              ao[:component_id] = "#{identifier}.#{ format('%06d', ( done + i ))}"
              updates << ao
            end
      end
    end
    
    self.transaction do
      self[:sequence].multi_insert(sequences)
    end

    # now lets add some CUIDS as a transaction.
    updates.each_slice(100) do |batch|
      self.transaction do
        batch.each do |row|
          self[:archival_object].where(id: row[:id]).update(component_id: row[:component_id])
        end
      end
    end
    
    # finally, we're all done so let's add our unique constraint.
    alter_table(:archival_object) do
      add_unique_constraint([:component_id], name: 'cuid_uniq')
    end
  end

end

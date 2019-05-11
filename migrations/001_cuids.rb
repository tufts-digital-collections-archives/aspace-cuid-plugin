require 'db/migrations/utils'
require 'json'

Sequel.migration do

  up do
    
    create_table(:cuid_history) do
      primary_key :id
      String :cuid, unique: true, null: false
      Integer :archival_object_id
      apply_mtime_columns
    end

    alter_table(:cuid_history) do
      add_foreign_key([:archival_object_id], :archival_object, key: :id)
    end
    
    alter_table(:archival_object) do
      add_column :cuid, String, null: false  
    end

    puts "=" * 100
    puts "aspace-cuid-plugin: Adding the CUID column to the archival_objects table."
    puts "We will put in a default unique ID here to ensure the database intergrity."
    puts "This will follow a basic formula of 'collection id' + '-' + 'sequence number'"
    puts "Please read the documentation on how to apply your own formula and update the archival object records."
    puts "This might take a few minutes..."
    puts "=" * 100

    # Ugly. But since the collection identifier is stored as json in the DB,
    # we need to go thru and parse it out
    row_map = self[:archival_object].join(:resource, id: :root_record_id)
                        .select(:archival_object__id, :resource__identifier)
                        .inject({}) do |memo, row|
                          identifier = JSON.parse(row[:identifier]).compact.join('-')
                          memo[identifier] ||= []
                          memo[identifier] << row[:id]
                          memo
                        end

    row_map.each do |resource, aos|
      # make sure we have our sequence counter added...
      self[:sequence].insert(sequence_name: "#{resource}_components",
                             value: aos.length - 1)

      # now insert our cuids into the table
      mapped = aos.each_with_index.map do |ao,i|
        { cuid: "#{resource}-#{i}", archival_object_id: ao,
          create_time: Time.now, system_mtime: Time.now,
          user_mtime: Time.now, created_by: 'PluginMigration' }
      end
      
      mapped.each_slice(100) do |batch|
        self.transaction do
          self[:cuid_history].multi_insert(batch)
        end
        self.transaction do
          batch.each do |row|
            self[:archival_object].where(id: row[:archival_object_id]).update(cuid: row[:cuid])
          end
        end
      end
    end

    alter_table(:archival_object) do
      add_unique_constraint([:cuid], name: 'cuid_uniq')
    end

  end
end

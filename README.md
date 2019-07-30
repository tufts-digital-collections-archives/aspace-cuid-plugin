ASPACE Component Unique Identifier Plugin
=========================================

An ArchivesSpace plugin to generate a unique component identifier for Archival
Objects ( a.k.a collection components).

## Install

First, **make a backup of your database and put it somewhere safe**.
This plugin makes changes to the database schema and updates your data!

To install, just activate the plugin in your config/config.rb file by
including an entry such as:

     # If you have other plugins loaded, just add 'aspace-cuid-plugin' to
     # the list
     AppConfig[:plugins] = ['local', 'other_plugins', 'aspace-cuid-plugin']
     # ...or do this...
     AppConfig[:plugins] << "aspace-cuid-plugin"


And then clone the `aspace-cuid-plugin` repository into your
ArchivesSpace plugins directory.  For example:

     cd /path/to/your/archivesspace/plugins
     git clone https://github.com/tufts-digital-collections-archives/aspace-cuid-plugin aspace-cuid-plugin

Then run the database setup script to update your tables:

      cd /path/to/archivesspace
      scripts/setup-database.sh

The migration puts a uniqueness constraint on the
archival_object.component_id field. Since this constraint did not previously
exist, the process looks for duplicate component_ids and modifies them by
appending a sequence number. **If you don't want this to happen** you must check
your data to ensure there are no duplicate component_id values in the
archival_object table prior to installing the plugin.
Here's a SQL query that might help you find duplicates:

```
mysql> select component_id, count(*) as count from archival_object group by component_id having ( count(*) > 1 );
```


The `component_id` field is also made to be mandatory and not allow empty
values. The setup-database.sh script will add some pre-configured data to the
component_id fields that are empty. The default is to add the four-part Resource/Collection identifier with
a sequence number that is counted off for the number of Archival
Objects/Components that are associated to the Resource/Collection (i.e.
ABC-XYZ-999-888.0000001, ABC-XYZ-999-888.0000002, ... ). If you are planning on configuring
the CUID formula, you should either modify the migration script (located in
[migrations/001_cuids.rb](https://github.com/tufts-digital-collections-archives/aspace-cuid-plugin/blob/master/migrations/001_cuids.rb#L31-L64) )
to your desired values or update the database with your values after running the
setup-database.sh migration.

## Configure

If you would like to build the sequence in a slightly different way, you can
modify the AppConfig[:cuid_generator] setting in the config.rb file.  
This just needs to be a proc that returns a proc that accepts the json for the
archival_object and returns a string.

```
  AppConfig[:cuid_generator] = proc do
    ->(json) { "#{json[:title]}-#{SecureRandom.hex}" }
  end
```

If you want to use a sequential number, you can use the ArchivesSpace
sequence functionality:

```
AppConfig[:cuid_generator] = proc do
  proc do |json|
    resolved = URIResolver.resolve_references(json, ['resource'])
    identifier = %w[id_0 id_1 id_2 id_3]
                 .map { |id| resolved['resource']['_resolved'][id] }
                 .compact
                 .join('-')

    # we are using sequences, but it's also possible for someone to
    # manually edit the CUID and use something that the sequence
    # hasn't hit yet. So, when making a new sequence, let's try up-to
    # 100 times.
    sequence = increment_component_sequence(identifier)
    100.times do
      break if where(component_id: "#{identifier}.#{sequence}").empty?

      sequence = increment_component_sequence(identifier)
    end

    "#{identifier}.#{sequence}"
  end
end
```

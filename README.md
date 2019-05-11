ASPACE Collection Unique Identifier Plugin
=========================================

An ArchivesSpace plugin to generate unique collection identifier for Archival
Object ( a.k.a collection components ).

## Install

First, **make a backup of your database and put it somewhere safe**. This
plugin makes changes to the database.

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

What this setup-database script does is adds an additional table to the schema
called `cuid_history` and adds a `cuid` field to the archival_object table. The
cuid_history table ensures that any cuid's that are created are persisted
beyond the life of the associated archival_object record.

The script also adds cuids to the all the archival_object rows. This default
cuid is constructed using the Resource identifier + a sequence number. 

## Configure

If you would like to build the sequence in a slightly different way, you can
modify the AppConfig[:cuid_generator] setting in the config.rb file.  
This just to be a proc that returns a proc that accecpts the json for the
archival_object.

```
  AppConfig[:cuid_generator] = proc do
    ->(json) { "#{json[:title]}-#{SecureRandom.hex}" }
  end
```

If you want to use a sequence number, you can use the ArchivesSpace sequence
functionality:

```
AppConfig[:cuid_generator] = proc do
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
```

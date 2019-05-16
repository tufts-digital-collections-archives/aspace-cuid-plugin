# -*- coding: utf-8 -*-
{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {
			"component_id" => {"type" => "string", "maxLength" => 8192, "ifmissing" => "error"},	
    },
  },
}

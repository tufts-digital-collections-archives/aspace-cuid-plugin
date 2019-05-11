# -*- coding: utf-8 -*-
{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {
			"cuid_value" => {"type" => "string", "maxLength" => 8192, "ifmissing" => "error"},	
    },
  },
}

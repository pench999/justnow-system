# -*- coding: utf-8 -*-

module Yabitz
  VERSION = begin
    version_path = File.expand_path('../../VERSION', __dir__)
    File.read(version_path).strip
  rescue
    'unknown'
  end
end

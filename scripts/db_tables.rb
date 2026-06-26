#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require_relative './db_schema'

conn = Yabitz::Schema.conn
begin
  exists = conn.query("SHOW TABLES LIKE 'oids'").count > 0
ensure
  conn.close
end

if exists
  warn "Yabitz tables already exist; skipping schema creation."
else
  Yabitz::Schema.create_tables
end

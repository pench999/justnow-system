# -*- coding: utf-8 -*-

require 'stratum'

module Yabitz
  module Model
    class HostImage < Stratum::Model
      table :host_images

      field :host, :ref, :model => 'Yabitz::Model::Host', :serialize => :oid
      field :filename, :string, :length => 255
      field :original_filename, :string, :length => 255
      field :content_type, :string, :length => 64
      field :caption, :string, :length => 255, :empty => :ok

      def image_url
        "/ybz/host/#{host_by_id}/image/#{oid}"
      end
    end
  end
end

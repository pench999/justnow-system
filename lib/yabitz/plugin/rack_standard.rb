# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module StandardRack42U
    def self.plugin_type
      :racktype
    end
    def self.plugin_priority
      1
    end
    # This plugin module is for example, and NOT TESTED.

    def self.name
      'STANDARD42U'
    end

    def self.datacenter
      'SOMEWHARE'
    end

    def self.rack_label_pattern
      /\A[a-zA-Z][0-9]{2}\Z/ # rack number: alphabet + [num]x2
    end

    def self.rackunit_label_pattern
      /\A[a-zA-Z][0-9]{2}-(0[1-9]|[1-3][0-9]|4[012])[fr]?\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 3]
    end

    def self.dividing(rackunit_label)
      require_relative '../misc/racktype'
      case
      when rackunit_label =~ /\df\Z/
        Yabitz::RackTypes::DIVIDING_HALF_FRONT
      when rackunit_label =~ /\dr\Z/
        Yabitz::RackTypes::DIVIDING_HALF_REAR
      else
        Yabitz::RackTypes::DIVIDING_FULL
      end
    end

    def self.rack_label_example
      'A01'
    end

    def self.rackunit_label_example
      'A01-42(f/r)'
    end

    def self.upper_rackunit_labels(from, num)
      from =~ /\A([a-zA-Z][0-9]{2}-)(0[1-9]|[1-3][0-9]|4[012])([fr]?)\Z/
      rack_label = $1
      position = $2.to_i
      form = ($3 || '')
      list = []
      (1..num).each do |up|
        list.push(rack_label + ('%02d' % (position + up)) + form)
      end
      list
    end

    def self.rackunit_space_list(rack_label)
      list = []
      unit = 42
      while unit > 0
        full = rack_label + ("-%02d" % unit)
        list.push([full, full + 'f', full + 'r'])
        unit = unit - 1
      end
      list
    end

    def self.rack_display_template
      <<EOT
- style_blank = 'text-align: center; background-color: #f3f6f8; border: 1px solid #d4dde5; color: #7b8792; padding: 5px 6px;'
- style_empty = 'text-align: center; background-color: #fff9df; border: 1px dashed #d6a11d; color: #8a6400; padding: 5px 6px; font-weight: 700;'
- style_unit = 'text-align: center; background-color: #eef3f6; border: 1px solid #c8d4dd; color: #40505c; padding: 5px 6px; font-family: Consolas, Menlo, monospace; font-weight: 600; white-space: nowrap;'
- style_filled = 'padding: 7px 9px; background-color: #e8f3f8; border: 1px solid #91bdcf; border-left: 4px solid #176b87; color: #17212b; vertical-align: top;'
- style_disp = 'font-weight: 700; color: #075f7a; margin-right: 6px;'
- style_info = 'font-size: 82%; color: #52616d;'
- disp = lambda {|host| host.display_name.to_s + (host.parent || host.hwid.to_s.empty? ? '' : ' / ' + host.hwid.to_s) }
- info = lambda {|host| service_name = host.service ? host.service.name.to_s : 'サービス未設定'; ipaddr = (host.localips && host.localips.size > 0) ? host.localips.first.address.to_s : ''; '(' + ([service_name, ipaddr].reject{|v| v.empty?}.join(', ')) + ')' }
- detail = lambda {|host| ['状態: ' + host.status.to_s, '種別: ' + host.type.to_s, '位置: ' + host.rackunit.to_s, (host.hwinfo ? '機器: ' + host.hwinfo.name.to_s : nil), (host.cpu.to_s.empty? ? nil : 'CPU: ' + host.cpu.to_s), (host.memory.to_s.empty? ? nil : 'メモリ: ' + host.memory.to_s)].compact.join(' / ') }
- unit_height = lambda {|host| host.hwinfo ? [host.hwinfo.unit_height.to_i, 1].max : 1 }
- racktype = Yabitz::RackTypes.search(@rack.label)
%table.rack_display{:width => '100%', :style => 'width: 100%; border-collapse: collapse; table-layout: fixed; font-size: 13px;'}
  %tr
    %td{:width => '10%', :style => style_blank} unit
    %td{:width => '45%', :align => 'center', :style => style_blank} FRONT
    %td{:width => '45%', :align => 'center', :style => style_blank} REAR
  - racktype.rackunit_space_list(@rack.label).each do |full, front, rear|
    %tr
      %td{:style => style_unit}&= full
      - if @units[full]
        - host = @units[full]
        - if @units[racktype.upper_rackunit_labels(full, 1).first] != host
          %td{:colspan => 2, :rowspan => unit_height.call(host), :style => style_filled}
            %div
              %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
              %span.rack_host_info{:style => style_info}&= info.call(host)
              %div.rack_host_detail&= detail.call(host)
            - if host.children and host.children.size > 0
              %ul.rack_host_children
                - host.children.each do |c|
                  %li
                    %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                    %span.rack_host_info{:style => style_info}&= info.call(c)
                    %div.rack_host_detail&= detail.call(c)
      - elsif @units[front] or @units[rear]
        - if @units[front]
          - host = @units[front]
          - if @units[racktype.upper_rackunit_labels(front, 1).first] != host
            %td{:rowspan => unit_height.call(host), :style => style_filled}
              %div
                %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
                %span.rack_host_info{:style => style_info}&= info.call(host)
                %div.rack_host_detail&= detail.call(host)
              - if host.children and host.children.size > 0
                %ul.rack_host_children
                  - host.children.each do |c|
                    %li
                      %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                      %span.rack_host_info{:style => style_info}&= info.call(c)
                      %div.rack_host_detail&= detail.call(c)
        - else
          %td.rack_empty_unit{:style => style_empty, :title => '空きU'}
            %div 空き
        - if @units[rear]
          - host = @units[rear]
          - if @units[racktype.upper_rackunit_labels(rear, 1).first] != host
            %td{:rowspan => unit_height.call(host), :style => style_filled}
              %div
                %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
                %span.rack_host_info{:style => style_info}&= info.call(host)
                %div.rack_host_detail&= detail.call(host)
              - if host.children and host.children.size > 0
                %ul.rack_host_children
                  - host.children.each do |c|
                    %li
                      %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                      %span.rack_host_info{:style => style_info}&= info.call(c)
                      %div.rack_host_detail&= detail.call(c)
        - else
          %td.rack_empty_unit{:style => style_empty, :title => '空きU'}
            %div 空き
      - else
        %td.rack_empty_unit{:colspan => 2, :style => style_empty, :title => '空きU'}
          %div 空き
EOT
    end
  end
end

# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module FairwayRackDisplay
    def rack_display_template
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
- safe_class = lambda {|value| value.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\\A_|_\\Z/, '') }
- host_type_group = lambda {|host| t = host.type.to_s.downcase; t.include?('guest') ? 'guest' : (t.include?('host') ? 'host' : (t.include?('switch') ? 'switch' : (t.empty? ? 'unknown' : safe_class.call(t)))) }
- highlighted = lambda {|host| @highlight_host_oids && @highlight_host_oids.include?(host.oid.to_i) }
- host_or_child_highlighted = lambda {|host| highlighted.call(host) || (host.children && host.children.any?{|c| highlighted.call(c)}) }
- host_cell_class = lambda {|host| ['rack_host_unit', 'rack_host_status_' + safe_class.call(host.status), 'rack_host_type_' + host_type_group.call(host), (host_or_child_highlighted.call(host) ? 'rack_host_highlight' : nil)].compact.join(' ') }
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
          %td{:colspan => 2, :rowspan => unit_height.call(host), :style => style_filled, :class => host_cell_class.call(host)}
            %div
              %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
              %span.rack_host_info{:style => style_info}&= info.call(host)
              %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
              %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
              %div.rack_host_detail&= detail.call(host)
            - if host.children and host.children.size > 0
              %ul.rack_host_children
                - host.children.each do |c|
                  %li{:class => (highlighted.call(c) ? 'rack_child_highlight' : nil)}
                    %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                    %span.rack_host_info{:style => style_info}&= info.call(c)
                    %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(c.status)
                    %span.rack_host_badge.rack_host_type_badge&= c.type.to_s
                    %div.rack_host_detail&= detail.call(c)
      - elsif @units[front] or @units[rear]
        - if @units[front]
          - host = @units[front]
          - if @units[racktype.upper_rackunit_labels(front, 1).first] != host
            %td{:rowspan => unit_height.call(host), :style => style_filled, :class => host_cell_class.call(host)}
              %div
                %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
                %span.rack_host_info{:style => style_info}&= info.call(host)
                %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
                %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
                %div.rack_host_detail&= detail.call(host)
              - if host.children and host.children.size > 0
                %ul.rack_host_children
                  - host.children.each do |c|
                    %li{:class => (highlighted.call(c) ? 'rack_child_highlight' : nil)}
                      %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                      %span.rack_host_info{:style => style_info}&= info.call(c)
                      %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(c.status)
                      %span.rack_host_badge.rack_host_type_badge&= c.type.to_s
                      %div.rack_host_detail&= detail.call(c)
        - else
          %td.rack_empty_unit{:style => style_empty, :title => '空きU'}
            %div 空き
        - if @units[rear]
          - host = @units[rear]
          - if @units[racktype.upper_rackunit_labels(rear, 1).first] != host
            %td{:rowspan => unit_height.call(host), :style => style_filled, :class => host_cell_class.call(host)}
              %div
                %a.rack_host_name{:href => "/ybz/host/" + host.oid.to_s, :style => style_disp}&= disp.call(host)
                %span.rack_host_info{:style => style_info}&= info.call(host)
                %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
                %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
                %div.rack_host_detail&= detail.call(host)
              - if host.children and host.children.size > 0
                %ul.rack_host_children
                  - host.children.each do |c|
                    %li{:class => (highlighted.call(c) ? 'rack_child_highlight' : nil)}
                      %a.rack_host_name{:href => "/ybz/host/" + c.oid.to_s, :style => style_disp}&= disp.call(c)
                      %span.rack_host_info{:style => style_info}&= info.call(c)
                      %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(c.status)
                      %span.rack_host_badge.rack_host_type_badge&= c.type.to_s
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

  module FairwayRackCommon
    def plugin_type
      :racktype
    end

    def dividing(rackunit_label)
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

    def rackunit_space_list(rack_label)
      list = []
      unit = rack_unit_count
      while unit > 0
        full = rack_label + ("-%02d" % unit)
        list.push([full, full + 'f', full + 'r'])
        unit = unit - 1
      end
      list
    end

    def rackunit_status_list(rack_label, rackunits)
      used = {}
      rackunits.each do |rackunit|
        label = rackunit.rackunit
        used[label] = true
        used[label.sub(/[fr]\Z/, '')] = true
      end

      blank_full = 0
      used_or_partial = 0
      rackunit_space_list(rack_label).each do |full, front, rear|
        if used[full] or used[front] or used[rear]
          used_or_partial += 1
        else
          blank_full += 1
        end
      end
      [blank_full, used_or_partial]
    end

    def upper_rackunit_labels(from, num)
      return [] unless from =~ rackunit_label_capture_pattern
      rack_label = $1
      position = $2.to_i
      form = ($3 || '')
      list = []
      (1..num).each do |up|
        list.push(rack_label + ('%02d' % (position + up)) + form)
      end
      list
    end
  end

  module StandardRack36U
    extend FairwayRackCommon
    extend FairwayRackDisplay

    def self.plugin_priority
      1
    end

    def self.name
      'STANDARD36U'
    end

    def self.datacenter
      'ROPPONGI'
    end

    def self.rack_label_pattern
      /\A[a-zA-Z]{2}[0-9]{2}\Z/
    end

    def self.rackunit_label_pattern
      /\A[a-zA-Z]{2}[0-9]{2}-(0[1-9]|[1-2][0-9]|3[0-6])[fr]?\Z/
    end

    def self.rackunit_label_capture_pattern
      /\A([a-zA-Z]{2}[0-9]{2}-)(0[1-9]|[1-2][0-9]|3[0-6])([fr]?)\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 4]
    end

    def self.rack_label_example
      'AA01'
    end

    def self.rackunit_label_example
      'AA01-36(f/r)'
    end

    def self.rack_unit_count
      36
    end
  end

  module StandardRack47UAlphabetic
    extend FairwayRackCommon
    extend FairwayRackDisplay

    def self.plugin_priority
      1
    end

    def self.name
      'STANDARD47U'
    end

    def self.datacenter
      'FUKUOKA'
    end

    def self.rack_label_pattern
      /\A[a-zA-Z]{3}[0-9]{2}\Z/
    end

    def self.rackunit_label_pattern
      /\A[a-zA-Z]{3}[0-9]{2}-(0[1-9]|[1-3][0-9]|4[0-7])[fr]?\Z/
    end

    def self.rackunit_label_capture_pattern
      /\A([a-zA-Z]{3}[0-9]{2}-)(0[1-9]|[1-3][0-9]|4[0-7])([fr]?)\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 5]
    end

    def self.rack_label_example
      'AAA01'
    end

    def self.rackunit_label_example
      'AAA01-47(f/r)'
    end

    def self.rack_unit_count
      47
    end
  end

  module FukuokaRack47U
    extend FairwayRackCommon
    extend FairwayRackDisplay

    def self.plugin_priority
      2
    end

    def self.name
      'STANDARD47U'
    end

    def self.datacenter
      'FUKUOKA'
    end

    def self.rack_label_pattern
      /\AQ[0-9]{2}\Z/
    end

    def self.rackunit_label_pattern
      /\AQ[0-9]{2}-(0[1-9]|[1-3][0-9]|4[0-7])[fr]?\Z/
    end

    def self.rackunit_label_capture_pattern
      /\A(Q[0-9]{2}-)(0[1-9]|[1-3][0-9]|4[0-7])([fr]?)\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 3]
    end

    def self.rack_label_example
      'Q01'
    end

    def self.rackunit_label_example
      'Q01-47(f/r)'
    end

    def self.rack_unit_count
      47
    end
  end

  module KoshigayaRack46U
    extend FairwayRackCommon
    extend FairwayRackDisplay

    def self.plugin_priority
      3
    end

    def self.name
      'STANDARD46U'
    end

    def self.datacenter
      'KOSHIGAYA'
    end

    def self.rack_label_pattern
      /\AK[0-9]{2}\Z/
    end

    def self.rackunit_label_pattern
      /\AK[0-9]{2}-(0[1-9]|[1-3][0-9]|4[0-6])[fr]?\Z/
    end

    def self.rackunit_label_capture_pattern
      /\A(K[0-9]{2}-)(0[1-9]|[1-3][0-9]|4[0-6])([fr]?)\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 3]
    end

    def self.rack_label_example
      'K01'
    end

    def self.rackunit_label_example
      'K01-46(f/r)'
    end

    def self.rack_unit_count
      46
    end
  end
end

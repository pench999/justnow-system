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
      /\A[a-zA-Z][0-9]{2}-(0[1-9]|[1-3][0-9]|4[012])(?:[fr][12]?)?\Z/
    end

    def self.rack_label(rackunit_label)
      rackunit_label[0, 3]
    end

    def self.dividing(rackunit_label)
      require_relative '../misc/racktype'
      case
      when rackunit_label =~ /\df1\Z/
        Yabitz::RackTypes::DIVIDING_QUARTER_FRONT_1
      when rackunit_label =~ /\df2\Z/
        Yabitz::RackTypes::DIVIDING_QUARTER_FRONT_2
      when rackunit_label =~ /\dr1\Z/
        Yabitz::RackTypes::DIVIDING_QUARTER_REAR_1
      when rackunit_label =~ /\dr2\Z/
        Yabitz::RackTypes::DIVIDING_QUARTER_REAR_2
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
      from =~ /\A([a-zA-Z][0-9]{2}-)(0[1-9]|[1-3][0-9]|4[012])((?:[fr][12]?)?)\Z/
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
        list.push([full, full + 'f', full + 'r', full + 'f1', full + 'f2', full + 'r1', full + 'r2'])
        unit = unit - 1
      end
      list
    end

    def self.rackunit_status_list(rack_label, rackunits)
      used = {}
      rackunits.each do |rackunit|
        label = rackunit.rackunit
        used[label] = true
        used[label.sub(/[fr][12]?\Z/, '')] = true
      end

      blank_full = 0
      used_or_partial = 0
      rackunit_space_list(rack_label).each do |full, front, rear, front1, front2, rear1, rear2|
        if used[full] or used[front] or used[rear] or used[front1] or used[front2] or used[rear1] or used[rear2]
          used_or_partial += 1
        else
          blank_full += 1
        end
      end
      [blank_full, used_or_partial]
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
- info = lambda {|host| service_name = host.service ? host.service.name.to_s : 'no service'; ipaddr = (host.localips && host.localips.size > 0) ? host.localips.first.address.to_s : ''; '(' + ([service_name, ipaddr].reject{|v| v.empty?}.join(', ')) + ')' }
- detail = lambda {|host| ips = (host.globalips.map{|ip| '(g)' + ip.address.to_s} + host.virtualips.map{|ip| '(v)' + ip.address.to_s}); [(host.hwinfo ? 'hardware: ' + host.hwinfo.name.to_s : nil), (host.hwid.to_s.empty? ? nil : 'HWID: ' + host.hwid.to_s), (host.os.to_s.empty? ? nil : 'OS: ' + host.os.to_s), (host.cpu.to_s.empty? ? nil : 'CPU: ' + host.cpu.to_s), (host.memory.to_s.empty? ? nil : 'memory: ' + host.memory.to_s), (host.disk.to_s.empty? ? nil : 'disk: ' + host.disk.to_s), (ips.empty? ? nil : 'extra IP: ' + ips.join(', ')), (host.notes.to_s.empty? ? nil : 'has notes')].compact.join(' / ') }
- unit_height = lambda {|host| host.hwinfo ? [host.hwinfo.unit_height.to_i, 1].max : 1 }
- safe_class = lambda {|value| value.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\\A_|_\\Z/, '') }
- host_type_group = lambda {|host| t = host.type.to_s.downcase; t.include?('guest') ? 'guest' : (t.include?('host') ? 'host' : (t.include?('switch') ? 'switch' : (t.empty? ? 'unknown' : safe_class.call(t)))) }
- highlighted = lambda {|host| @highlight_host_oids && @highlight_host_oids.include?(host.oid.to_i) }
- host_or_child_highlighted = lambda {|host| highlighted.call(host) || (host.children && host.children.any?{|c| highlighted.call(c)}) }
- host_cell_class = lambda {|host| ['rack_host_unit', 'rack_host_status_' + safe_class.call(host.status), 'rack_host_type_' + host_type_group.call(host), (host_or_child_highlighted.call(host) ? 'rack_host_highlight' : nil)].compact.join(' ') }
- host_link = lambda {|host| @mobile_view ? "/mobile/#host/" + host.oid.to_s : "/ybz/host/" + host.oid.to_s }
- racktype = Yabitz::RackTypes.search(@rack.label)
%table.rack_display{:width => '100%', :style => 'width: 100%; border-collapse: collapse; table-layout: fixed; font-size: 13px;'}
  %tr
    %td{:width => '10%', :style => style_blank} unit
    %td{:width => '22.5%', :align => 'center', :style => style_blank} FRONT 1
    %td{:width => '22.5%', :align => 'center', :style => style_blank} FRONT 2
    %td{:width => '22.5%', :align => 'center', :style => style_blank} REAR 1
    %td{:width => '22.5%', :align => 'center', :style => style_blank} REAR 2
  - full_rowspan_remaining = 0
  - front_rowspan_remaining = 0
  - rear_rowspan_remaining = 0
  - quarter_rowspan_remaining = {}
  - racktype.rackunit_space_list(@rack.label).each do |full, front, rear, front1, front2, rear1, rear2|
    %tr
      %td{:style => style_unit}&= full
      - if full_rowspan_remaining > 0
        - full_rowspan_remaining -= 1
      - elsif @units[full]
        - host = @units[full]
        - host_height = unit_height.call(host)
        - full_rowspan_remaining = host_height - 1
        %td{:colspan => 4, :rowspan => host_height, :style => style_filled, :class => host_cell_class.call(host)}
          %div
            %a.rack_host_name{:href => host_link.call(host), :style => style_disp}&= disp.call(host)
            %span.rack_host_info{:style => style_info}&= info.call(host)
            %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
            %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
            %div.rack_host_detail&= detail.call(host)
      - else
        - if front_rowspan_remaining > 0
          - front_rowspan_remaining -= 1
        - elsif @units[front]
          - host = @units[front]
          - host_height = unit_height.call(host)
          - front_rowspan_remaining = host_height - 1
          %td{:colspan => 2, :rowspan => host_height, :style => style_filled, :class => host_cell_class.call(host)}
            %div
              %a.rack_host_name{:href => host_link.call(host), :style => style_disp}&= disp.call(host)
              %span.rack_host_info{:style => style_info}&= info.call(host)
              %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
              %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
              %div.rack_host_detail&= detail.call(host)
        - else
          - [front1, front2].each do |quarter|
            - if quarter_rowspan_remaining[quarter].to_i > 0
              - quarter_rowspan_remaining[quarter] -= 1
            - elsif @units[quarter]
              - host = @units[quarter]
              - host_height = unit_height.call(host)
              - quarter_rowspan_remaining[quarter] = host_height - 1
              %td{:rowspan => host_height, :style => style_filled, :class => host_cell_class.call(host)}
                %div
                  %a.rack_host_name{:href => host_link.call(host), :style => style_disp}&= disp.call(host)
                  %span.rack_host_info{:style => style_info}&= info.call(host)
                  %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
                  %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
                  %div.rack_host_detail&= detail.call(host)
            - else
              %td.rack_empty_unit{:style => style_empty, :title => '空きU'}
                %div 空き
        - if rear_rowspan_remaining > 0
          - rear_rowspan_remaining -= 1
        - elsif @units[rear]
          - host = @units[rear]
          - host_height = unit_height.call(host)
          - rear_rowspan_remaining = host_height - 1
          %td{:colspan => 2, :rowspan => host_height, :style => style_filled, :class => host_cell_class.call(host)}
            %div
              %a.rack_host_name{:href => host_link.call(host), :style => style_disp}&= disp.call(host)
              %span.rack_host_info{:style => style_info}&= info.call(host)
              %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
              %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
              %div.rack_host_detail&= detail.call(host)
        - else
          - [rear1, rear2].each do |quarter|
            - if quarter_rowspan_remaining[quarter].to_i > 0
              - quarter_rowspan_remaining[quarter] -= 1
            - elsif @units[quarter]
              - host = @units[quarter]
              - host_height = unit_height.call(host)
              - quarter_rowspan_remaining[quarter] = host_height - 1
              %td{:rowspan => host_height, :style => style_filled, :class => host_cell_class.call(host)}
                %div
                  %a.rack_host_name{:href => host_link.call(host), :style => style_disp}&= disp.call(host)
                  %span.rack_host_info{:style => style_info}&= info.call(host)
                  %span.rack_host_badge.rack_host_status_badge&= Yabitz::Model::Host.status_title(host.status)
                  %span.rack_host_badge.rack_host_type_badge&= host.type.to_s
                  %div.rack_host_detail&= detail.call(host)
            - else
              %td.rack_empty_unit{:style => style_empty, :title => '空きU'}
                %div 空き
EOT
    end
  end
end

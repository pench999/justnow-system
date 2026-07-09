# -*- coding: utf-8 -*-

require 'sinatra/base'

require 'haml'
require_relative '../misc/htpasswd_file'

class Yabitz::Application < Sinatra::Base
  def basic_auth_file
    Yabitz::HtpasswdFile.new(ENV['YABITZ_HTPASSWD_PATH'] || '/app/config/basic_auth.htpasswd')
  end

  ### ユーザ情報 (すべて認証要求、post/putはadmin)
  get '/ybz/auth_info/list' do
    protected!
    all_users = Yabitz::Model::AuthInfo.all.sort
    valids = []
    invalids = []
    all_users.each do |u|
      if u.valid? and not u.root?
        valids.push(u)
      elsif not u.root?
        invalids.push(u)
      end
    end
    @users = valids + invalids
    @page_title = "ユーザ認証情報一覧"
    haml :auth_info_list
  end

  get %r!/ybz/auth_info/(\d+)(\.ajax|\.tr\.ajax)?! do |oid, ctype|
    protected!
    @auth_info = Yabitz::Model::AuthInfo.get(oid.to_i)
    pass unless @auth_info # object not found -> HTTP 404

    case ctype
    when '.ajax' then haml :auth_info_parts, :layout => false
    when '.tr.ajax' then haml :auth_info, :layout => false, :locals => {:auth_info => @auth_info}
    else
      raise NotImplementedError
    end
  end
  
  post %r!/ybz/auth_info/(\d+)! do |oid|
    admin_protected!
    user = Yabitz::Model::AuthInfo.get(oid.to_i)
    pass unless user

    case request.params['operation']
    when 'toggle'
      case request.params['field']
      when 'priv'
        if user.admin?
          user.priv = nil
        else
          user.set_admin
        end
      when 'valid'
        user.valid = (not user.valid?)
      end
    end
    user.save
    "ok"
  end
  # post '/ybz/auth_info/invalidate' #TODO

  get '/ybz/auth_info/basic_auth' do
    admin_protected!
    @basic_auth_file = basic_auth_file
    @basic_auth_users = @basic_auth_file.users
    @page_title = "Basic認証ユーザー管理"
    @hide_detailview = true
    haml :basic_auth_list
  end

  post '/ybz/auth_info/basic_auth' do
    admin_protected!
    username = params[:username].to_s.strip
    password = params[:password].to_s
    password_confirm = params[:password_confirm].to_s

    if password != password_confirm
      return redirect '/ybz/auth_info/basic_auth?error=password_mismatch'
    end

    begin
      basic_auth_file.save_user(username, password)
      return redirect '/ybz/auth_info/basic_auth?saved=1'
    rescue ArgumentError => e
      return redirect "/ybz/auth_info/basic_auth?error=#{u(e.message)}"
    end
  end

  post '/ybz/auth_info/basic_auth/delete' do
    admin_protected!
    username = params[:username].to_s.strip

    if @user and @user.name == username
      return redirect '/ybz/auth_info/basic_auth?error=self_delete'
    end

    begin
      basic_auth_file.delete_user(username)
      return redirect '/ybz/auth_info/basic_auth?deleted=1'
    rescue ArgumentError => e
      return redirect "/ybz/auth_info/basic_auth?error=#{u(e.message)}"
    end
  end

end

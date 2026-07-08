# -*- coding: utf-8 -*-

require 'base64'
require 'digest/sha1'
require 'fileutils'
require 'securerandom'

module Yabitz
  class HtpasswdFile
    USERNAME_PATTERN = /\A[-.a-zA-Z0-9_@]+\z/.freeze

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def users
      entries.keys.sort
    end

    def exists?
      File.file?(path)
    end

    def writable?
      exists? ? File.writable?(path) : File.writable?(File.dirname(path))
    end

    def save_user(username, password)
      validate_username!(username)
      validate_password!(password)

      current = entries
      current[username] = ssha_password(password)
      write_entries(current)
    end

    def delete_user(username)
      validate_username!(username)

      current = entries
      current.delete(username)
      write_entries(current)
    end

    private

    def entries
      return {} unless exists?

      File.readlines(path).each_with_object({}) do |line, result|
        line = line.chomp
        next if line.empty? or line.start_with?('#')
        username, password_hash = line.split(':', 2)
        next if username.to_s.empty? or password_hash.to_s.empty?
        result[username] = password_hash
      end
    end

    def validate_username!(username)
      unless username.to_s.match?(USERNAME_PATTERN)
        raise ArgumentError, 'ユーザー名は英数字、記号 . _ - @ のみ使用できます'
      end
    end

    def validate_password!(password)
      if password.to_s.empty?
        raise ArgumentError, 'パスワードを入力してください'
      end
    end

    def ssha_password(password)
      salt = SecureRandom.random_bytes(16)
      digest = Digest::SHA1.digest(password + salt)
      '{SSHA}' + Base64.strict_encode64(digest + salt)
    end

    def write_entries(current)
      FileUtils.mkdir_p(File.dirname(path))
      tempfile = "#{path}.tmp.#{$$}"
      File.open(tempfile, File::WRONLY | File::CREAT | File::TRUNC, 0644) do |file|
        current.sort.each do |username, password_hash|
          file.puts("#{username}:#{password_hash}")
        end
      end
      File.rename(tempfile, path)
      File.chmod(0644, path)
    ensure
      File.delete(tempfile) if tempfile and File.exist?(tempfile)
    end
  end
end

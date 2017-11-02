require_relative '../../lib/smbclient/version'
require_relative '../test_helper'

STDOUT.sync = true

class SMBClientTest < Minitest::Test
  def test_version_number
    refute_nil SMBClient::VERSION
  end

  def test_connection
    @smb =
      SMBClient::SMB.new host: ENV['SMB_HOST'],
                         share: ENV['SMB_SHARE'],
                         user: ENV['SMB_USERNAME'],
                         domain: ENV['SMB_DOMAIN'],
                         password: ENV['SMB_PASSWORD'],
                         version: 2
    @smb.ls '201710/'
    @smb.close
  end
end

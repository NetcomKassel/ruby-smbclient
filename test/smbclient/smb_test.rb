require_relative '../../lib/smbclient/version'
require_relative '../test_helper'

class SMBClientTest < Minitest::Test
  def test_version_number
    refute_nil SMBClient::VERSION
  end
end

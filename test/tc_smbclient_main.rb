require 'rubygems'
require 'globalog'
require 'test/unit'
require 'fileutils'
require File.join( File.dirname( File.expand_path(__FILE__)), '..', 'lib', 'smbclient')

TESTFILE = 'smbclient_test'
LOCAL_DIR = File.join( File.dirname( File.expand_path(__FILE__)), 'smbclient_test_dir')
REMOTE_DIR = 'smbclient_test_dir'
WELCOME = <<TITLE


  .|'''.|                     '||              '||          
  ||..  '   ....   .. .. ..    || ...   ....    ||   ....   
   ''|||.  '' .||   || || ||   ||'  || '' .||   ||  '' .||  
 .     '|| .|' ||   || || ||   ||    | .|' ||   ||  .|' ||  
 |'....|'  '|..'|' .|| || ||.  '|...'  '|..'|' .||. '|..'|' 


/////////////////////////////////////////////////////////////
TITLE

class TestSMBClientMain < Test::Unit::TestCase
  
  def setup
		@log_test = GlobaLog.logger(STDERR,:info,true)
    check_smbclient_presence
    get_samba_param_from_input
    init_smbclient
		put_marker
		Dir.mkdir(LOCAL_DIR)
  end
  
  def test_main
		@log_test.info("Testing sample SMB operations...")
    ls_one = check_ls
		check_mkdir(REMOTE_DIR)
		check_exist(REMOTE_DIR)
		check_cd(REMOTE_DIR)
		check_recurse
		
		ls_two = check_ls
		assert(ls_one != ls_two)
		
		check_lcd_put_get
		check_queue
		
		check_big_chunk

		check_cd('..')
		check_rmdir(REMOTE_DIR)
  end
  
  def teardown
		back_to_marker
		@log_test.info("All Test Done!!! Tearing Down!!!")
		@samba.rmdir(REMOTE_DIR).to_s if @samba.exist?(REMOTE_DIR)
		@log_test.debug("remote directory clean")
    close = @samba.close
    assert(close)
		@log_test.debug("samba client closed")
		FileUtils.remove_dir(LOCAL_DIR) if File.exist?(LOCAL_DIR)
		@log_test.debug("local directory clean")
		@log_test.close
		puts "\nBEWARE, if test fails you may have to clean up your server and the test directory,\na folder named #{REMOTE_DIR} may be left after exiting... Sorry!"
  end
  
  private

	def put_marker
		result = @samba.put(:from => 'test/' + File.basename(__FILE__), :to => File.basename(__FILE__))
		assert_equal(true, result[0], "Putting initial path marker failed: #{result[1]}")
	end
	
	def back_to_marker
		@samba.cd('..') unless @samba.exist?(File.basename(__FILE__))
		@samba.del(File.basename(__FILE__))
	end
  
  def check_smbclient_presence
    answer = `smbclient --help`
    assert(answer.include?('Usage'), "No 'smbclient' tool was found on this computer,\nPlease install 'smbclient' and try again.")
  end
  
  def get_samba_param_from_input
		puts WELCOME
		puts "ATTENTION!!! You need 1gb free space on your local machine and 10gb on your server for this test to run!!!"
    puts "I will need you to input some working Samba connection settings..."
    print "\n"; sleep 1
    print "host name or IP: "
    @host = $stdin.gets.chomp
    print "share name: "
    @share = $stdin.gets.chomp
    print "domain: "
    @domain = $stdin.gets.chomp
    print "user: "
    @user = $stdin.gets.chomp
    print "password: "
    @password = $stdin.gets.chomp
    puts "I will now try to connect to #{@share.to_s} for the purpose of testing smbclient..."
    print "\n"
  end
  
  def init_smbclient
    @samba = Smbclient.new(:domain => @domain,
													 :host => @host,
													 :share => @share,
													 :user => @user,
													 :password => @password)
    puts "Connection successfull,\nnow proceding with test:"
  end
  
  def check_ls
    result = @samba.ls
    assert_not_nil(result)
		result_alias = @samba.dir
    assert_not_nil(result_alias)
		return result
  end

	def check_cd(path)
		cd = @samba.cd(path)
		assert_equal(true,cd)
	end
  
	def check_exist(path)
		exist = @samba.exist?(path)
		assert_equal(true,exist)
	end
	
	def check_mkdir(path)
		re = @samba.mkdir(path)
		assert_equal(true,re)
	end
	
	def check_recurse
		initial_state = @samba.recurse?
		assert( initial_state == true || initial_state == false )
		toggle_state = @samba.recurse
		assert( toggle_state == true || toggle_state == false )
		assert_not_equal(initial_state, toggle_state)
		final_state = @samba.recurse!(initial_state)
		assert_equal(initial_state,final_state)
		assert_equal(final_state,@samba.recurse?)
	end
	
	def check_rmdir(path)
		re = @samba.rmdir(path)
		assert_equal(true,re)
	end
	
	def check_lcd_put_get
		@log_test.debug("cd in testdir")
		re = @samba.lcd(LOCAL_DIR)
		assert_equal(true,re)
		
		@log_test.debug("making local test file")
		f = File.new(File.join(LOCAL_DIR,TESTFILE),'w')
		f.puts "test file"
		f.close
		assert(File.exist?(File.join(LOCAL_DIR,TESTFILE)))
		
		@log_test.debug("putting file")
		re = @samba.put(:from => TESTFILE, :to => TESTFILE)
		assert_kind_of(Array,re)
		assert_equal(true,re[0])
		
		@log_test.debug("deleting local test file")
		File.delete(File.join(LOCAL_DIR,TESTFILE))
		assert(!File.exist?(File.join(LOCAL_DIR,TESTFILE)))
		
		check_exist(TESTFILE)
		
		@log_test.debug("getting test file")
		re = @samba.get(:from => TESTFILE, :to => TESTFILE)
		assert_kind_of(Array,re)
		assert_equal(true,re[0])
		
		@log_test.debug("delete remote test file")
		re = @samba.del(TESTFILE)
		assert_equal(true,re)
		
		@log_test.debug("check local test file")
		assert(File.exist?(File.join(LOCAL_DIR,TESTFILE)))
		File.delete(File.join(LOCAL_DIR,TESTFILE))
		assert(!File.exist?(File.join(LOCAL_DIR,TESTFILE)))
		
		re = @samba.lcd('..')
		assert_equal(true,re)
		
	end
	
	def check_queue
		jobs = 23
		@log_test.info("Testing queue... (be patient, this will take a couple minutes)")
		assert_equal(true, @samba.queue_empty?)
		assert_equal(true, @samba.queue_done?)
		assert_equal(0,@samba.queue_waiting)
		
		local_file = File.join(LOCAL_DIR,'dummy')
		system("mkfile 1k #{local_file}")
		
		re = @samba.lcd(LOCAL_DIR)
		assert_equal(true,re)
		
		files = Array.new(jobs) { |id| "file_" + id.to_s }
		files.each do |file|
			@samba.put(:from => local_file, :to => file, :queue => true)
		end
		
		assert_equal(false, @samba.queue_empty?)
		assert_equal(false, @samba.queue_done?)
		assert(@samba.queue_waiting > 0)
		
		result = @samba.queue_processing
		@log_test.debug("queue processing result is: #{result.inspect}")
		assert_kind_of(Array,result)
		301.times do |n|
			break unless result[0].nil?
			sleep 1
			result = @samba.queue_processing
			flunk("Could not get any queue done...") if n == 300
		end
		assert_kind_of(Array,result[0])
		assert_equal(2,result[0].size)
		assert_kind_of(Integer,result[0][0])
		assert_kind_of(String,result[0][1])
		
		result = @samba.queue_completed
		@log_test.debug("queue completed results is: #{result.inspect}")
		assert_kind_of(Array,result)
		301.times do |n|
			break unless result[0].nil?
			sleep 1
			result = @samba.queue_completed
			flunk("Could not get any queue done...") if n == 300
		end
		assert_kind_of(Array,result[0])
		assert_equal(4,result[0].size)
		assert_kind_of(Integer,result[0][0])
		assert(result[0][1] == true || result[0][1] == false)
		assert_kind_of(String,result[0][2])
		assert_kind_of(String,result[0][3])
		
		more_result = @samba.queue_results
		@log_test.debug("more result: #{more_result.inspect}")
		assert_kind_of(Array,more_result)
		assert_kind_of(Array,more_result[0])
		assert_equal(4,more_result[0].size)
		assert_kind_of(Integer,more_result[0][0])
		assert(more_result[0][1] == true || more_result[0][1] == false)
		assert_kind_of(String,more_result[0][2])
		assert_kind_of(String,more_result[0][3])
		
		total_result = result + more_result
		assert_equal(jobs,total_result.size)
		
		assert_equal(true, @samba.queue_empty?)
		assert_equal(true, @samba.queue_done?)
		assert_equal(0,@samba.queue_waiting)
		
		File.delete(local_file)
		files.each do |file|
			del = @samba.del(file)
			@log_test.debug("remote delete: #{del.inspect}")
		end
		
		re = @samba.lcd('..')
		assert_equal(true,re)
	end
	
	def check_big_chunk
		jobs = 2
		@log_test.info("Testing a big copy... (be patient, this can also take a couple minutes)")
		local_file = File.join(LOCAL_DIR,'dummy')
		system("mkfile 10m #{local_file}")
		
		before = @samba.ls
		files = Array.new(jobs) { |id| "file_" + id.to_s }
		files.each do |file|
			@samba.put(:from => local_file, :to => file, :queue => true)
		end
		
		result = @samba.queue_results
		assert_equal(1, result.map { |item| item[1] }.uniq.size, "results were: #{result.inspect}")
		
		File.delete(local_file)
		files.each do |file|
			del = @samba.del(file)
			@log_test.debug("remote delete: #{del.inspect}")
		end
	end
  
end
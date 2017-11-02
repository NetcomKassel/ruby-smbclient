module SMBClient
  class SmbInitError < StandardError
  end
  # The Smbclient::Gardener module bings Abundance into Smbclient.
  # A bunch of mixins used inside Smbclient to access Abundance Non-Blocking Threading.
  # These methods are a higher level abstraction of Abundance methods,
  # serving as reusable general purpose agents inside Smbclient, mainly
  # for those repetitive execution commands.
  #
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  #
  # :title:Smbclient::Gardener
  module Gardener
    require 'timeout'

    # The +clean_path+ method cleans the slashes, as backslashes, for the Windows servers.
    # === Parameters
    # * _path_ = the path to be cleaned
    # === Example
    # 	cleaned = clean_path('/My/Path/')		# => '\My\Path'
    def clean_path(path)
      if @posix_support
        path
      else
        path.gsub(/\//, '\\')
      end
    end

    # The +execute+ method splits the execution according to the operation mode: queue or interactive.
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # * _queue_ = the command operation mode
    # === Example
    #   result = execute('cd','dir/otherDir*',false)  # =>  true
    def execute(command, data, queue = false)
      queue ? exec_queue(command, data) : exec_interactive(command, data)
    end

    # The +exec_interactive+ method follows +execute+ when queue=false.
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # === Example
    #   result = exec_interactive('put','aFile.txt')    # =>  [false, "aFile.txt does not exist\r\n"]
    def exec_interactive(command, data)
      id = @gardener.seed("#{command} #{data}")
      result = @gardener.harvest(:one, id)
      $log_smbclient.debug('exec_interactive result') { result.inspect.to_s }
      [result[:success], result[:message]]
    end

    # The +exec_queue+ method follows +execute+ when queue=true
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # === Example
    #   result = exec_queue('get','aFile.txt')  # => [true,1]
    def exec_queue(command, data)
      result = @gardener.seed("#{command} #{data}")
      $log_smbclient.debug('exec_queue result') { result.inspect.to_s }
      result.integer? ? [true, result] : [false, result]
    end

    # The +parse_results+ method map the gardener's return hash values to an array
    def parse_results(results)
      results.map { |result| [result[:id], result[:success], result[:seed], result[:message]] }
    end

    # The +gardener_ok+ method does the +init_gardener+ invocation, degrading the options parameters until
    # it initializes, or raise SmbInitError exception after 4 try.
    def gardener_ok
      init = []
      catch :gardener do
        4.times do |num|
          init_gardener; sleep 1
          begin
            Timeout.timeout(2) { @init_status = @gardener.init_status }
            init = Array.new(@init_status)
            init.map! { |result| result[:success] }
            throw :gardener if (init.uniq.size == 1) && init[0]
          rescue Timeout::Error
            $log_smbclient.error("Having problem setting the smb client... TRY #{num}")
          end
          kill_gardener_and_incr
        end
        $log_smbclient.fatal('All Attemps Failed, Gardener could not be initiated')
        raise SmbInitError.exception("Couldn't set smbclient properly (#{$ERROR_INFO})")
      end
      @posix_support = posix?(@init_status[0][:message])
    end

    # The +init_gardener+ method initialize a gardener class object
    def init_gardener
      @gardener = Abundance.gardener(rows: 1, init_timeout: @options[:init_timeout]) do
        PTY.spawn("smbclient //#{@options[:host]}/#{@options[:share]} #{@options[:password]} -W #{@options[:domain]} -U #{@options[:user]} -m SMB#{@options[:version]}") do |r, w, _pid|
          w.sync = true
          $expect_verbose = false
          catch :init do
            loop do
              r.expect(/.*\xD?\xAsmb\x3A\s[\x5C]*\x3E.*/) do |text|
                unless text.nil?
                  text[0] =~ /.*Server=.*/i ? Abundance.init_status(true, text.inspect.to_s) : Abundance.init_status(false, text.inspect.to_s)
                  throw :init
                end
              end
            end
          end
          Abundance.grow do |seed|
            prompt = false
            until prompt
              w.print "\r"
              r.expect(/.*\xD?\xAsmb\x3A\s[\x5C]*\w*[\x5C]+\x3E.*/) do |text|
                prompt = true unless text.nil?
              end
            end
            w.print "#{seed.sprout}\r"
            $log_smbclient.debug('smbclient') { "sprout: -- #{seed.sprout} --" }
            catch :result do
              iter = 1
              loop do
                r.expect(/.*\xD?\xAsmb\x3A\s[\x5C]*\w*[\x5C]+\x3E.*/) do |text|
                  $log_smbclient.debug('smbclient') { "expect: -- #{text.inspect} --" }
                  if !text.nil?
                    msg = text[0]

                    msg.gsub!(/smb\x3A\s\w*\x5C\x3E\s*$/, '')
                    msg.gsub!(/^\s*#{seed.sprout}/, '')
                    msg.lstrip!
                    $log_smbclient.debug('smbclient') { "msg: -- #{msg.inspect} --" }

                    success = case seed.sprout
                                when /^put/
                                  msg['putting'].nil? ? false : true
                                else
                                  if msg['NT_STATUS']
                                    false
                                  elsif msg['timed out'] || msg['Server stopped']
                                    false
                                  else
                                    true
                                  end
                              end

                    seed.crop(success, msg)
                    throw :result
                  elsif iter > 9_999_999
                    $log_smbclient.warn("Failed to #{seed.sprout}")
                    seed.crop(false, "Failed to #{seed.sprout}")
                    throw :result
                  else
                    $log_smbclient.debug('smbclient') { "jumped iter: #{iter}" }
                    iter += 1
                  end
                end
              end
            end
          end
        end
      end
    end

    private

    def kill_gardener_and_incr
      begin
        Timeout.timeout(2) { @gardener.close }
      rescue Timeout::Error
        pids = @gardener.rows_pids
        pids << @gardener.garden_pid
        pids.each { |pid| Process.kill('HUP', pid) }
      end
      @gardener = nil
      @options[:init_timeout] += 1
    end

    def posix?(init_message)
      if init_message =~ /windows/i
        false
      else
        true
      end
    end
  end
end

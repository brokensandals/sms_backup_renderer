require 'digest'
require 'erb'
require 'pathname'

module SmsBackupRenderer
  class BasePage
    # Returns the String path to where this file will be written.
    attr_reader :output_file_path

    def initialize(output_file_path)
      @output_file_path = output_file_path
    end

    def render
      ERB.new(File.read(File.join(File.dirname(__FILE__), 'templates', template_name))).result(binding)
    end

    def write
      File.write(output_file_path, render)
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(File.dirname(output_file_path))).to_s
    end

    def template_name
      raise 'not implemented'
    end
  end

  class IndexPage < BasePage
    # Returns an Array ConversationPage instances which this page should link to.
    attr_reader :conversation_pages

    def initialize(output_file_path, conversation_pages)
      super(output_file_path)
      @conversation_pages = conversation_pages.sort_by(&:title)
    end

    def template_name
      'index.html.erb'
    end
  end

  class ConversationPage < BasePage
    # Returns an Array of Message instances to be shown on this page.
    attr_reader :messages

    def initialize(output_file_path, messages)
      super(output_file_path)
      @messages = messages.sort_by(&:date_time)
    end

    def template_name
      'conversation.html.erb'
    end

    def title
      "Conversation with #{messages.first.participants.map(&:name).compact.join(', ')}"
    end

    # Returns a filename for a conversation page for the given participants, such as '123456789.html'.
    # Should always return the same name for the same list of participants. The normalized addresses
    # are used when they are numeric, but non-numeric addresses (such as email addresses) will be hex-encoded
    # to avoid any problems with file name restrictions.
    #
    # participants - an Array of Participant instances
    #
    # Returns a String filename.
    def self.build_filename(participants)
      participants.map do |participant|
        if participant.normalized_address =~ /\A\d+\z/
          participant.normalized_address
        else
          '0x' + Digest.hexencode(participant.address)
        end
      end.sort.join('_') + '.html'
    end
  end
end
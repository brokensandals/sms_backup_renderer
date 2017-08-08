require 'erb'
require 'pathname'

module SmsBackupRenderer
  class IndexPage
    # Returns the String directory to which all file paths in the generated HTML should be relative.
    attr_reader :base_path

    # Returns an Array of Arrays of Message instances.
    attr_reader :message_groups

    def initialize(base_path, message_groups)
      @base_path = base_path
      @message_groups = message_groups
    end

    def render
      ERB.new(File.read(File.join(File.dirname(__FILE__), 'templates', 'index.html.erb'))).result(binding)
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(base_path)).to_s
    end
  end
end
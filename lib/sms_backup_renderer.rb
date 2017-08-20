require 'sms_backup_renderer/models'
require 'sms_backup_renderer/parser'
require 'sms_backup_renderer/renderer'
require 'sms_backup_renderer/version'

require 'fileutils'
require 'tempfile'

module SmsBackupRenderer
  def self.generate_html_from_archive(input_file_path, output_dir_path)
    input_tempfile = Tempfile.new('sms_backup_renderer')
    input_text = File.read(input_file_path)
    SmsBackupRenderer.fix_surrogate_pairs(input_text)
    File.write(input_tempfile.path, input_text)

    data_dir_path = File.join(output_dir_path, 'data')
    FileUtils.mkdir_p(data_dir_path)

    input_file = File.open(input_tempfile.path)
    messages = SmsBackupRenderer.parse(input_file, data_dir_path)
    input_file.close
    input_tempfile.close

    message_groups = messages.group_by {|m| m.participants.reject(&:owner).map(&:normalized_address).sort}.values

    conversations_dir_path = File.join(output_dir_path, 'conversations')
    FileUtils.mkdir_p(conversations_dir_path)

    conversation_pages = message_groups.map do |group_messages|
      filename = ConversationPage.build_filename(group_messages.first.participants.reject(&:owner))
      path = File.join(conversations_dir_path, filename)
      SmsBackupRenderer::ConversationPage.new(path, group_messages)
    end

    conversation_pages.each(&:write)

    SmsBackupRenderer::IndexPage.new(File.join(output_dir_path, 'index.html'), conversation_pages).write
  end
end

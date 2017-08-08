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

    message_groups = messages.group_by(&:normalized_addresses).values
    index_html = SmsBackupRenderer::IndexPage.new(output_dir_path, message_groups).render
    File.write(File.join(output_dir_path, 'index.html'), index_html)
  end
end

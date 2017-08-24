require 'sms_backup_renderer'

# Just a basic integration test.
RSpec.describe SmsBackupRenderer do
  describe '.generate_html_from_archive' do
    output_dir_path = File.join(__dir__, '..', 'tmp', 'test-output')
    assets_dir_path = File.join(output_dir_path, 'assets')
    conversations_dir_path = File.join(output_dir_path, 'conversations')
    data_dir_path = File.join(output_dir_path, 'data')
    index_page_path = File.join(output_dir_path, 'index.html')
    conversation_page_path = File.join(conversations_dir_path, '2345678910.html')
    photo_file_name = '8013ecfc92a6081fb7b884adc514497a.jpeg'
    photo_path = File.join(data_dir_path, photo_file_name)

    before :all do
      FileUtils.rm_r(output_dir_path) if File.exist?(output_dir_path)
      SmsBackupRenderer.generate_html_from_archive(File.join(__dir__, 'test_archive.xml'), output_dir_path)
    end

    [output_dir_path,
     assets_dir_path,
     conversations_dir_path,
     data_dir_path,
     index_page_path,
     conversation_page_path,
     photo_path].each do |path|
      it "creates #{path}" do
        expect(File.exist?(path)).to be true
      end
    end

    describe 'index.html' do
      contents = nil

      before :all do
        contents = File.read(index_page_path)
      end

      it 'contains link to conversation page' do
        expect(contents).to include 'conversations/2345678910.html'
      end
    end

    describe '2345678910.html' do
      contents = nil

      before :all do
        contents = File.read(conversation_page_path)
      end

      it 'contains first message date' do
        # FIXME should mock the timezone before generating the file, then assert a literal value here
        expect(contents).to include Time.parse('2017-04-01T16:05:13.000Z').getlocal
          .strftime('%A, %b %-d, %Y at %-I:%M%P %Z')
      end

      it 'contains first message text' do
        expect(contents).to include 'unfamiliar with the concept of cats'
      end

      it 'contains photo' do
        expect(contents).to include "<img class=\"message-part-image\" src=\"../data/#{photo_file_name}\""
      end
    end

    after :all do
      FileUtils.rm_r(output_dir_path) unless ENV['KEEP_TEST_OUTPUT']
    end
  end
end
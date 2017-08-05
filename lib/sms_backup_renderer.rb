require 'base64'
require 'sms_backup_renderer/version'
require 'date'
require 'nokogiri'
require 'securerandom'

module SmsBackupRenderer
  class Message
    # Returns the String address the message was sent to or received from, such as '1 (234) 567-890'.
    attr_reader :address

    # Returns a String displayable name for the sender or receiver of the message, such as 'Jacob Williams'.
    #   May be nil.
    attr_reader :contact_name

    # Returns the DateTime the message was sent or received.
    attr_reader :date_time

    # Returns true if the message was sent to address, false if received from address.
    attr_reader :outgoing

    # Returns an Array of MessagePart instances representing the contents of the message.
    attr_reader :parts

    # Returns the String subject/title of the message, likely nil.
    attr_reader :subject

    def initialize(args)
      @address = args[:address]
      @contact_name = args[:contact_name]
      @date_time = args[:date_time]
      @outgoing = args[:outgoing]
      @parts = args[:parts] || []
      @subject = args[:subject]
    end
  end

  class MessagePart
  end

  class UnsupportedPart < MessagePart
    # Returns a String containing the XML data of the message part.
    attr_reader :xml

    def initialize(xml)
      @xml = xml
    end
  end

  class TextPart < MessagePart
    # Returns the String content of the message part such as "Hey Jacob, don't you have something better to do?".
    attr_reader :text

    def initialize(text)
      @text = text
    end
  end

  class MediaPart < MessagePart
    # Returns the String content type for the message part such as 'image/jpeg'.
    attr_reader :content_type

    # Returns the String file path at which the content has been stored.
    attr_reader :path

    def initialize(content_type, path)
      @content_type = content_type
      @path = path
    end
  end

  class ImagePart < MediaPart; end
  class VideoPart < MediaPart; end

  HIGH_SURROGATES = 0xD800..0xDFFF

  # Although the files claim to be UTF-8, SMS Backup & Restore produces files that incorrectly represent
  # characters such as emoji using surrogate pairs, such that a single character is represented by two
  # adjacent, separately-escaped characters which are supposed to be interpreted as a single
  # Unicode surrogate pair. Nokogiri crashes when it encounters these, since it tries to interpret
  # each part of the pair as a separate character. This method is a hacky workaround that simply searches
  # the whole file for strings that look like escaped surrogate pairs and replaces them with the literal
  # character they represent.
  def self.fix_surrogate_pairs(string)
    string.gsub!(/\&\#(\d{5})\;\&\#(\d{5})\;/) do |match|
      high = Regexp.last_match[1].to_i
      if HIGH_SURROGATES.include?(high)
        low = Regexp.last_match[2].to_i
        code_point = ((high - 0xD800) << 10) + (low - 0xDC00) + 0x010000
        [code_point].pack('U*')
      else
        match[0]
      end
    end
  end

  def self.parse(input, data_dir_path)
    data_file_seq = 1

    messages = []
    Nokogiri::XML::Reader(input).each do |node|
      next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
      case node.name
      when 'sms'
        sms = Nokogiri::XML(node.outer_xml).at('/sms')
        messages << Message.new(
          address: sms.attr('address'),
          contact_name: sms.attr('contact_name'),
          date_time: DateTime.strptime(sms.attr('date'), '%Q'),
          parts: sms.attr('body') ? [TextPart.new(sms.attr('body'))] : [],
          outgoing: sms_outgoing_type?(sms.attr('type')),
          subject: sms.attr('subject'))
      when 'mms'
        mms = Nokogiri::XML(node.outer_xml).at('/mms')
        unless mms.attr('ct_t') == 'application/vnd.wap.multipart.related'
          raise "Unrecognized MMS ct_t #{mms.attr('ct_t')}"
        end
        parts = mms.xpath('parts/part').map do |part|
          case part.attr('ct')
          when 'application/smil'
            # should probably use this, but I think I can get by without it
            nil
          when 'text/plain'
            TextPart.new(part.attr('text'))
          when /\Aimage\/(.+)\z/
            path = File.join(data_dir_path, "#{data_file_seq}.#{$1}")
            File.write(path, Base64.decode64(part.attr('data')))
            data_file_seq += 1
            ImagePart.new(part.attr('ct'), path)
          when /\Avideo\/(.+)\z/
            path = File.join(data_dir_path, "#{data_file_seq}.#{$1}")
            File.write(path, Base64.decode64(part.attr('data')))
            data_file_seq += 1
            VideoPart.new(part.attr('ct'), path)
          else
            UnsupportedPart.new(part.to_xml)
          end
        end.compact
        messages << Message.new(
          address: mms.attr('address'),
          contact_name: mms.attr('contact_name'),
          date_time: DateTime.strptime(mms.attr('date'), '%Q'),
          outgoing: mms_outgoing_type?(mms.attr('m_type')),
          parts: parts)
      end
    end
    messages
  end

  def self.sms_outgoing_type?(type)
    case type
    when '1'
      false
    when '2'
      true
    else
      raise "Unrecognized SMS type #{type}"
    end
  end

  def self.mms_outgoing_type?(type)
    case type
    when '132'
      false
    when '128'
      true
    else
      raise "Unrecognized MMS m_type #{type}"
    end
  end
end

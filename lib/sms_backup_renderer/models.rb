module SmsBackupRenderer
  # Represents an SMS or MMS message.
  class Message
    # Returns a String displayable name for the sender or receiver of the message, such as 'Jacob Williams'.
    #   May be nil.
    attr_reader :contact_name

    # Returns the DateTime the message was sent or received.
    attr_reader :date_time

    # Returns true if the message was sent to address, false if received from address.
    attr_reader :outgoing

    # Returns an Array of MessagePart instances representing the contents of the message.
    attr_reader :parts

    # Returns an Array of String addresses that received the message. For MMS messages there can be multiple.
    #   For SMS messages received by the originator of the archive, will be empty array.
    attr_reader :receiver_addresses

    # Returns the String address the message was received from, such as '1 (234) 567-890'. Will be
    #   nil for SMS messages sent by originator of the archive.
    attr_reader :sender_address

    # Returns the String subject/title of the message, likely nil.
    attr_reader :subject

    def initialize(args)
      @contact_name = args[:contact_name]
      @date_time = args[:date_time]
      @outgoing = args[:outgoing]
      @parts = args[:parts] || []
      @receiver_addresses = args[:receiver_addresses]
      @sender_address = args[:sender_address]
      @subject = args[:subject]
    end

    # Returns an Array of String addresses the message was sent to or received from, normalized in a
    #   very hacky/incomplete/embarrassingly-US-centric way to help facilitate grouping conversations.
    def normalized_addresses
      (receiver_addresses + [sender_address].compact).map do |addr|
        addr.gsub(/[\s\(\)\+\-]/, '')
          .gsub(/\A1(\d{10})\z/, '\\1')
      end.sort
    end
  end

  # Represents a piece of content in a message, such as text or an image. See subclasses.
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
end

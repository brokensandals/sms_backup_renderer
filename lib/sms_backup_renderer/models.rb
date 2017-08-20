module SmsBackupRenderer
  # Represents a single sender or recipient of an SMS or MMS message.
  class Participant
    # Returns the String address of the participant, such as '1 (234) 567-890'.
    attr_reader :address

    # Returns the String contact name for the participant, or nil if unknown.
    attr_reader :name

    # Returns true if this participant is the owner of the archive, otherwise false.
    attr_reader :owner

    # Returns true if this participant is a sender of the message, false if they are a recipient.
    attr_reader :sender

    def initialize(args)
      @address = args[:address]
      @name = args[:name]
      @owner = args[:owner]
      @sender = args[:sender]
    end

    def normalized_address
      @normalized_address ||= Participant.normalize_address(address)
    end

    # Normalizes a given address, for example '1 (234) 567-890' to '1234567890'.
    #
    # TODO: This is currently done in a very hacky, incomplete, embarrassingly-US-centric way.
    #
    # address - String address to normalize
    #
    # Returns the String normalized address.
    def self.normalize_address(address)
      address.gsub(/[\s\(\)\+\-]/, '')
          .gsub(/\A1(\d{10})\z/, '\\1')
    end
  end

  # Represents an SMS or MMS message.
  class Message
    # Returns the DateTime the message was sent or received.
    attr_reader :date_time

    # Returns true if the message was sent to address, false if received from address.
    attr_reader :outgoing

    # Returns an Array of Participant instances representing the senders and recipients of the message.
    #   For MMS messages there may be multiple recipients. For SMS messages, the originator of the archive
    #   is never represented, so there will only be a sender (for incoming messages) or a recipient
    #   (for outgoing messages).
    attr_reader :participants

    # Returns an Array of MessagePart instances representing the contents of the message.
    attr_reader :parts

    # Returns the String subject/title of the message, likely nil.
    attr_reader :subject

    def initialize(args)
      @contact_name = args[:contact_name]
      @date_time = args[:date_time]
      @outgoing = args[:outgoing]
      @participants = args[:participants]
      @parts = args[:parts] || []
      @subject = args[:subject]
    end

    # Returns the Participant instance for the message sender, or nil.
    def sender
      @sender ||= participants.detect(&:sender)
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

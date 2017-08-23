require 'base64'
require 'digest'
require 'nokogiri'
require 'time'

module SmsBackupRenderer
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
    messages = []
    Nokogiri::XML::Reader(input).each do |node|
      next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
      case node.name
      when 'sms'
        sms = Nokogiri::XML(node.outer_xml).at('/sms')
        outgoing = sms_outgoing_type?(sms.attr('type'))
        messages << Message.new(
          date_time: Time.strptime(sms.attr('date'), '%Q'),
          parts: sms.attr('body') ? [TextPart.new(sms.attr('body'))] : [],
          outgoing: outgoing,
          participants: [Participant.new(
            address: sms.attr('address'),
            name: sms.attr('contact_name'),
            owner: false,
            sender: !outgoing)],
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
            data = Base64.decode64(part.attr('data'))
            digest = Digest::MD5.hexdigest(data)
            path = File.join(data_dir_path, "#{digest}.#{$1}")
            File.write(path, data)
            ImagePart.new(part.attr('ct'), path)
          when /\Avideo\/(.+)\z/
            data = Base64.decode64(part.attr('data'))
            digest = Digest::MD5.hexdigest(data)
            path = File.join(data_dir_path, "#{digest}.#{$1}")
            File.write(path, data)
            VideoPart.new(part.attr('ct'), path)
          else
            UnsupportedPart.new(part.to_xml)
          end
        end.compact

        non_owner_addresses = parse_mms_combined_address(mms.attr('address'))
        address_contact_names = mms_address_contact_names(mms)
        participants = mms.xpath('addrs/addr').map do |addr|
          Participant.new(
            address: addr.attr('address'),
            name: address_contact_names[Participant.normalize_address(addr.attr('address'))],
            owner: !non_owner_addresses.include?(Participant.normalize_address(addr.attr('address'))),
            sender: mms_sender_addr_type?(addr.attr('type')))
        end

        messages << Message.new(
          date_time: Time.strptime(mms.attr('date'), '%Q'),
          outgoing: mms_outgoing_type?(mms.attr('m_type')),
          participants: participants,
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

  def self.mms_sender_addr_type?(type)
    case type
    when '137'
      true
    else
      false
    end
  end

  # Build a hash of normalized addresses to contact names using information in an MMS XML record.
  # The data in the archive does not provide any explicit mapping of addresses to contact names, but
  # at least for me it seems like the tilde-separated address attribute and the comma-separated
  # contact_name attribute are provided in the same order, so we can try to use those to build
  # a mapping. Obviously, this is error-prone, but seems better than nothing.
  #
  # mms - nokogiri object representing the MMS element
  #
  # Returns a Hash of String normalized addresses to String contact names.
  def self.mms_address_contact_names(mms)
    addresses = parse_mms_combined_address(mms.attr('address'))
    contact_names = mms.attr('contact_name').split(',').map(&:strip)

    # There may be more addresses than contact names. It seems like the addresses for unknown contacts
    # are placed at the end of the list. We'll omit them from the hash.
    addresses = addresses.take(contact_names.count)

    addresses.zip(contact_names).to_h
  end

  # The XML for MMSes contains an 'address' attribute containing a list of addresses separated by
  # tildes. Although there are also separate 'addr' elements for each address, the combined attribute
  # can be useful because it appears to exclude the owner of the archive's address, and because the
  # order can be correlated with the contact_name attribute.
  #
  # address_attribute - the value of the 'address' attribute from the XML element for the MMS message
  #
  # Returns an Array of String normalized addresses.
  def self.parse_mms_combined_address(address_attribute)
    address_attribute.split('~').map {|a| Participant.normalize_address(a)}
  end
end
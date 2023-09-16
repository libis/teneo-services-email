require 'mapi/msg'
require 'rfc_2047'
require 'pdfkit'

require 'fileutils'
require 'cgi'

class MsgConverter
  attr_accessor :msg_file, :warnings

  def initialize(msg_file)
    raise ArgumentError, "File #{msg_file} not found" unless File.exist?(msg_file) && File.readable?(msg_file)
    @msg_file = msg_file
    @warnings = []
  end

  def to_eml(filename)
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, File::CREAT | File::TRUNC | File::WRONLY | File::SYNC | File::BINARY, 0640) do |f|
      f.write(mime.to_s)
    end
  end

  def to_html(filename)
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, File::CREAT | File::TRUNC | File::WRONLY | File::SYNC | File::BINARY, 0640) do |f|
      f.write(body)
    end
  end

  def to_pdf(filename, options = {})
    pdf_options = {
      page_size: 'A4',
      margin_top: '10mm',
      margin_bottom: '10mm',
      margin_left: '10mm',
      margin_right: '10mm',
      dpi: 300,
    }.merge options
    FileUtils.mkdir_p(File.dirname(filename))
    subject = headers[:subject]
    kit = PDFKit.new(body, title: (subject || 'message'), **pdf_options)
    File.open(filename, File::CREAT | File::TRUNC | File::WRONLY | File::SYNC | File::BINARY, 0640) do |f|
      f.write(kit.to_pdf)
    end
  end  

  HTML_WRAPPER_TEMPLATE = '<!DOCTYPE html><html><head><style>body {font-size: 0.5cm;}</style><title>title</title></head><body>%s</body></html>'

  def body
    @msg_body ||= begin
      # Get the body of the message in HTML
      body = message.properties.body_html
      # Embed plain body in HTML as a fallback
      body ||= HTML_WRAPPER_TEMPLATE % message.properties.body
      # Check and fix the character encoding
      begin
        # Try to encode into UTF-8
        body.encode!('UTF-8', universal_newline: true)
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        begin
        # If it fails, the text may be in Windows' Latin1 (ISO-8859-1)
        body.force_encoding('ISO-8859-1').encode!('UTF-8', universal_newline: true)
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
          # If that fails too, log a warning and replace the invalid/unknown with a ? character.
          @warnings << e.message
          body.encode!('UTF-8', universal_newline: true, invalid: :replace, undef: :replace)
        end
      end
      # Add headers to the body
      add_headers(body)
      # Embed images
      embed_images(body)
      body
    end
  end

  HEADER_FIELDS = %w"From To Cc Subject Date"

  def headers
    @msg_headers ||= begin
      headers = {}
      HEADER_FIELDS.each do |key|
        value = find_hdr(message.headers, key)
        if value
          headers[key.downcase.to_sym] = value
        end
      end
      headers
    end
  end

  def attachments(dirname, recursive: false)
    
  end

  private

  def message
    @msg ||= Mapi::Msg.open(msg_file)
  end

  def mime
    @msg_mime ||= message.to_mime
  end

  def find_hdr(list, key)
    keys = list.keys
    if k = keys.find {|x| x.to_s =~ /^#{key}$/i}
      v = list[k]
      v = v.first if v.is_a? Array
      v = Rfc2047.decode(v).strip if v.is_a? String
      return v
    end
    nil
  end

  HEADER_STYLE = '<style>.header-table {margin: 0 0 20 0;padding: 0;font-family: Arial, Helvetica, sans-serif;}.header-name {padding-right: 5px;color: #9E9E9E;text-align: right;vertical-align: top;font-size: 12px;}.header-value {font-size: 12px;}#header_fields {background: white;margin: 0;border: 1px solid #DDD;border-radius: 3px;padding: 8px;width: 100%%;box-sizing: border-box;}</style><script type="text/javascript">function timer() {try {parent.postMessage(Math.max(document.body.offsetHeight, document.body.scrollHeight), \'*\');} catch (r) {}setTimeout(timer, 10);};timer();</script>'
  HEADER_TABLE_TEMPLATE = '<div class="header-table"><table id="header_fields"><tbody>%s</tbody></table></div>'
  
  def add_headers(body)
    hdr_html = ''
    HEADER_FIELDS.each do |key|
      value = headers[key.downcase.to_sym]
      hdr_html += hdr_html(key, value)
    end
    # Add header section to the HTML body
    unless hdr_html.empty?
      # Insert header block styles
      if body =~ /<\/head>/
        # if head exists, append the style block
        body.gsub!(/<\/head>/, HEADER_STYLE + '</head>')
      else
        # otherwise insert a head section before the body tag
        body.gsub!(/<body/, '<head>' + HEADER_STYLE + '</head><body')
      end
      # Add the headers html table as first element in the body section
      body.gsub!(/<body[^>]*>/) {|m| "#{m}#{HEADER_TABLE_TEMPLATE % hdr_html}"}
    end
    body
  end
  
  HEADER_FIELD_TEMPLATE = '<tr><td class="header-name">%s</td><td class="header-value">%s</td></tr>'

  def hdr_html(key, value)
    return HEADER_FIELD_TEMPLATE % [key, CGI::escapeHTML(value)] if key.is_a?(String) && value.is_a?(String) && !value.empty?
    ''
  end

  IMG_CID_PLAIN_REGEX = %r/\[cid:(.*?)\]/m
  IMG_CID_HTML_REGEX = %r/cid:([^"]*)/m

  def embed_images(body)
    # First process plaintext cid entries (in case the plain text body was embedded in HTML)
    body.gsub!(IMG_CID_PLAIN_REGEX) do |match|
      data = getAttachmentData(attachments, $1)
      if data
        "<img src=\"data:#{data[:mime_type]};base64,#{data[:base64]}\"/>"
      else
        '<img src=""/>'
      end
    end
    # Then process HTML img tags with CID entries
    body.gsub!(IMG_CID_HTML_REGEX) do |match|
      data = getAttachmentData(attachments, $1)
      if data
        "data:#{data[:mime_type]};base64,#{data[:base64]}"
      else
        ''
      end
    end
  end

  def getAttachmentData(cid)
    attachments.each do |attachment|
      if attachment.properties.attach_content_id == cid
        attachment.data.rewind
        return {
          mime_type: attachment.properties.attach_mime_tag,
          base64: Base64.encode64(attachment.data.read).gsub(/[\r\n]/, '')
        }
      end
    end
    return nil
  end

end

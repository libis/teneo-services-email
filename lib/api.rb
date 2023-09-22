# frozen-string-literal: true
require 'msg_converter'

class API < Roda
  plugin :json
  plugin :json_parser
  plugin :typecast_params
  plugin :symbolized_params

  route do |r|
    r.on 'msg' do

      # Get filename
      filename = typecast_params.nonempty_str!('filename')
      r.params[:filename]
      filename ||= 'data/RossettaStorageIntegrityJob.msg'
      converter = MsgConverter.new(filename)

      r.get 'headers' do
        converter.headers
      end

      r.get 'attachments' do
        converter.attachment_names
      end

      r.on 'convert' do

        r.get 'to_eml' do
          # Get output dir
          target = "#{filename}.eml"
          # Convert file
          converter.convert(target, format: :EML, **r.params)
        end

        r.get 'to_html' do
          # Get output dir
          target = "#{filename}.html"
          # Convert file
          converter.convert(target, format: :HTML, **r.params)
        end

        r.get 'to_pdf' do
          # Get output dir
          target = "#{filename}.pdf"
          # Convert file
          converter.convert(target, format: :PDF, **r.params)
        end

      end

    end
  end
end
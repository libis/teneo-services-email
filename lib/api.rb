# frozen-string-literal: true
require 'msg_converter'

class API < Roda
  plugin :json
  plugin :json_parser
  plugin :typecast_params
  
  route do |r|
    r.on 'msg' do

      # Get filename
      filename = typecast_params.nonempty_str!('filename')
      filename ||= 'data/RossettaStorageIntegrityJob.msg'
      converter = MsgConverter.new(filename)

      r.get 'metadata' do
        converter.metadata
      end

      r.on 'convert' do
        
        # Get attachments parameter
        extract_attachments = typecast_params.bool('extract_attachments')

        # Get recursion parameter
        recursive = typecast_params.bool('recursive')

        # Get target format
        target_format = typecast_params.nonempty_str!('format').upcase.to_sym

        # Get output file
        target = "#{filename}.#{target_format.to_s.downcase}"

        options = {}
        if target_format == :PDF
          options = typecast_params.convert!(symbolize: true) do |tp|
            tp.nonempty_str('page_size')
            tp.nonempty_str('margin_top')
            tp.nonempty_str('margin_bottom')
            tp.nonempty_str('margin_left')
            tp.nonempty_str('margin_right')
            tp.pos_int('dpi')
          end.compact
        end

        # Convert file
        result = converter.convert(target, format: target_format, extract_attachments: extract_attachments, recursive: recursive, **options)

        if result[:error]
          response.status = 400
        end

        result

      end

    end
  end
end
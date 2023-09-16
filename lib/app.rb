require 'roda'

class App < Roda
  route do |r|
  
    r.get 'hello' do
      "Hello"
    end

    r.on 'msg' do
      # /convert branch
      r.on 'convert' do
  
        # /convert request
        r.is do
  
          # Post /convert request
          r.post do
            
          end
        end
      end
    end
  end
end
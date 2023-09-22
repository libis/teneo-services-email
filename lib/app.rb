# frozen-string-literal: true
require 'roda'
require 'api'

class App < Roda
  route do |r|
  
    r.get 'hello' do
      "Hello"
    end

    r.on 'api' do
      r.run API
    end
  end
end
require 'socket'
require 'json'

PORT = 4000

$stdout.sync = true

server = UDPSocket.new
server.bind('0.0.0.0', PORT)

puts "UDP server is listening on port #{PORT}..."

loop do
  message, _addr = server.recvfrom(1024)
  begin
    data = JSON.parse(message, symbolize_names: true)
    puts " #{data[:client_id]}: #{data}"
  rescue JSON::ParserError
    puts "Invalid JSON received: #{message}"
  end
end
